'use strict';

import fs from 'node:fs';
import crypto from 'node:crypto';

const base = (process.env.PAYPAL_API_BASE || 'https://api-m.sandbox.paypal.com').replace(/\/$/, '');
const clientId = process.env.PAYPAL_CLIENT_ID || '';
const clientSecret = process.env.PAYPAL_CLIENT_SECRET || '';
if (!clientId || !clientSecret) {
  throw new Error('Configure os secrets PAYPAL_CLIENT_ID e PAYPAL_CLIENT_SECRET em GitHub Actions.');
}

async function jsonRequest(token, method, path, body, requestId) {
  const headers = {
    Authorization: 'Bearer ' + token,
    Accept: 'application/json',
    'Content-Type': 'application/json',
  };
  if (requestId) headers['PayPal-Request-Id'] = requestId;
  const response = await fetch(base + path, {
    method,
    headers,
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error('PayPal API ' + method + ' ' + path + ' devolveu HTTP ' +
      response.status + ' (' + (payload.name || 'erro desconhecido') + ').');
  }
  return payload;
}

async function getToken() {
  const response = await fetch(base + '/v1/oauth2/token', {
    method: 'POST',
    headers: {
      Authorization: 'Basic ' + Buffer.from(clientId + ':' + clientSecret).toString('base64'),
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: 'grant_type=client_credentials',
  });
  const result = await response.json().catch(() => ({}));
  if (!response.ok || !result.access_token) {
    throw new Error('Falha de autenticação PayPal. Confirma se os secrets correspondem ao ambiente selecionado.');
  }
  return result.access_token;
}

function output(name, value) {
  if (process.env.GITHUB_OUTPUT) {
    fs.appendFileSync(process.env.GITHUB_OUTPUT, name + '=' + value + '\n');
  }
}

// Retries reuse the catalog by name if a prior deployment stopped before runtime config was saved.
async function findProductIdByName(token, name) {
  for (let page = 1; page <= 10; page += 1) {
    const result = await jsonRequest(token, 'GET',
      '/v1/catalogs/products?page_size=20&page=' + page + '&total_required=true');
    const product = (result.products || []).find((item) => item.name === name);
    if (product && product.id) return product.id;
    if (!(result.links || []).some((item) => item.rel === 'next')) break;
  }
  return '';
}

async function findMonthlyPlanId(token, productId, name) {
  for (let page = 1; page <= 10; page += 1) {
    const result = await jsonRequest(token, 'GET',
      '/v1/billing/plans?product_id=' + encodeURIComponent(productId) +
      '&page_size=20&page=' + page + '&total_required=true');
    const plan = (result.plans || []).find((item) =>
      item.name === name && item.status === 'ACTIVE');
    if (plan && plan.id) return plan.id;
    if (!(result.links || []).some((item) => item.rel === 'next')) break;
  }
  return '';
}

async function createCatalog(token) {
  let productId = process.env.PAYPAL_PRODUCT_ID || '';
  let monthlyPlanId = process.env.PAYPAL_MONTHLY_PLAN_ID || '';

  if (!productId) {
    productId = await findProductIdByName(token, 'AnimPro Pro');
  }
  if (!productId) {
    const product = await jsonRequest(token, 'POST', '/v1/catalogs/products', {
      name: 'AnimPro Pro',
      description: 'Recursos avançados do editor de animação 2D AnimPro.',
      type: 'SERVICE',
      category: 'SOFTWARE',
      home_url: 'https://nexauren1.github.io/Animations-2D-/',
    }, 'animpro-product-' + crypto.randomUUID());
    productId = product.id;
    if (!productId) throw new Error('PayPal não devolveu o ID do produto.');
    console.log('Produto AnimPro Pro criado.');
  } else {
    console.log('A reutilizar o produto PayPal existente.');
  }

  if (!monthlyPlanId) {
    monthlyPlanId = await findMonthlyPlanId(token, productId, 'AnimPro Pro Mensal');
  }
  if (!monthlyPlanId) {
    const plan = await jsonRequest(token, 'POST', '/v1/billing/plans', {
      product_id: productId,
      name: 'AnimPro Pro Mensal',
      description: 'Subscrição mensal para as ferramentas Pro do AnimPro.',
      status: 'ACTIVE',
      billing_cycles: [{
        frequency: { interval_unit: 'MONTH', interval_count: 1 },
        tenure_type: 'REGULAR',
        sequence: 1,
        total_cycles: 0,
        pricing_scheme: {
          fixed_price: { value: '5.00', currency_code: 'USD' },
        },
      }],
      payment_preferences: {
        auto_bill_outstanding: true,
        setup_fee_failure_action: 'CONTINUE',
        payment_failure_threshold: 3,
      },
    }, 'animpro-monthly-' + crypto.randomUUID());
    monthlyPlanId = plan.id;
    if (!monthlyPlanId) throw new Error('PayPal não devolveu o ID do plano mensal.');
    console.log('Plano mensal de USD 5 criado.');
  } else {
    console.log('A reutilizar o plano mensal PayPal existente.');
  }

  output('product_id', productId);
  output('monthly_plan_id', monthlyPlanId);
}

async function registerWebhook(token) {
  const url = process.env.PAYPAL_WEBHOOK_URL || '';
  if (!url.startsWith('https://')) {
    throw new Error('A URL HTTPS de paypalWebhook não foi fornecida.');
  }
  const previousId = process.env.PAYPAL_WEBHOOK_ID || '';
  let existingId = '';
  if (previousId) {
    try {
      const previous = await jsonRequest(token, 'GET',
        '/v1/notifications/webhooks/' + encodeURIComponent(previousId));
      if (previous.url === url) existingId = previousId;
    } catch (_) {
      console.log('O webhook guardado não foi encontrado; será pesquisada a URL esperada.');
    }
  }
  if (!existingId) {
    try {
      const list = await jsonRequest(token, 'GET',
        '/v1/notifications/webhooks?page_size=20&page=1');
      const match = (list.webhooks || []).find((item) => item.url === url);
      if (match && match.id) existingId = match.id;
    } catch (_) {
      // If listing is not available, creation below still gives a clear API error.
    }
  }
  if (existingId) {
    output('webhook_id', existingId);
    console.log('Webhook PayPal já registado com a URL esperada.');
    return;
  }

  const created = await jsonRequest(token, 'POST', '/v1/notifications/webhooks', {
    url,
    event_types: [
      { name: 'CHECKOUT.ORDER.APPROVED' },
      { name: 'BILLING.SUBSCRIPTION.ACTIVATED' },
      { name: 'BILLING.SUBSCRIPTION.UPDATED' },
      { name: 'BILLING.SUBSCRIPTION.CANCELLED' },
      { name: 'BILLING.SUBSCRIPTION.SUSPENDED' },
      { name: 'BILLING.SUBSCRIPTION.EXPIRED' },
      { name: 'BILLING.SUBSCRIPTION.PAYMENT.FAILED' },
      { name: 'PAYMENT.SALE.COMPLETED' },
      { name: 'PAYMENT.SALE.REFUNDED' },
      { name: 'PAYMENT.SALE.REVERSED' },
      { name: 'PAYMENT.CAPTURE.REFUNDED' },
      { name: 'PAYMENT.CAPTURE.REVERSED' },
    ],
  }, 'animpro-webhook-' + crypto.randomUUID());
  if (!created.id) throw new Error('PayPal não devolveu o ID do webhook.');

  // Delete the old endpoint only after the new registration has succeeded.
  if (previousId && previousId !== created.id) {
    try {
      await jsonRequest(token, 'DELETE',
        '/v1/notifications/webhooks/' + encodeURIComponent(previousId));
    } catch (_) {
      console.log('Aviso: o webhook antigo não foi removido automaticamente.');
    }
  }
  output('webhook_id', created.id);
  console.log('Webhook seguro do AnimPro registado.');
}

(async () => {
  const token = await getToken();
  const mode = process.argv[2];
  if (mode === 'catalog') await createCatalog(token);
  else if (mode === 'webhook') await registerWebhook(token);
  else throw new Error('Modo inválido. Usa catalog ou webhook.');
})().catch((error) => {
  console.error(error.message || 'Falha de configuração PayPal.');
  process.exit(1);
});
