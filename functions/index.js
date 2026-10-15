'use strict';

const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');

initializeApp();
const db = getFirestore();

const PAYPAL_CLIENT_ID = defineSecret('PAYPAL_CLIENT_ID');
const PAYPAL_CLIENT_SECRET = defineSecret('PAYPAL_CLIENT_SECRET');
const PAYPAL_WEBHOOK_ID = defineSecret('PAYPAL_WEBHOOK_ID');

const REGION = 'us-central1';
const PRODUCT_ID = process.env.PAYPAL_PRODUCT_ID || '';
const MONTHLY_PLAN_ID = process.env.PAYPAL_MONTHLY_PLAN_ID || '';
const API_BASE = (process.env.PAYPAL_API_BASE || 'https://api-m.sandbox.paypal.com').replace(/\/$/, '');
const RETURN_URL = process.env.PAYPAL_RETURN_URL ||
  'https://nexauren1.github.io/Animations-2D-/payment-return.html';
const CANCEL_URL = process.env.PAYPAL_CANCEL_URL ||
  'https://nexauren1.github.io/Animations-2D-/payment-return.html?cancelled=1';

function requireHttps(value, name) {
  if (typeof value !== 'string' || !value.startsWith('https://')) {
    throw new HttpsError('failed-precondition', name + ' não está configurado com HTTPS.');
  }
}

async function accessToken() {
  const id = PAYPAL_CLIENT_ID.value();
  const secret = PAYPAL_CLIENT_SECRET.value();
  if (!id || !secret) {
    throw new HttpsError('failed-precondition', 'Credenciais PayPal não configuradas no backend.');
  }
  const response = await fetch(API_BASE + '/v1/oauth2/token', {
    method: 'POST',
    headers: {
      Authorization: 'Basic ' + Buffer.from(id + ':' + secret).toString('base64'),
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: 'grant_type=client_credentials',
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok || !payload.access_token) {
    console.error('PayPal OAuth failed with HTTP status', response.status);
    throw new HttpsError('unavailable', 'Não foi possível ligar ao PayPal.');
  }
  return payload.access_token;
}

async function paypalRequest(token, method, path, body, requestId) {
  const headers = {
    Authorization: 'Bearer ' + token,
    Accept: 'application/json',
    'Content-Type': 'application/json',
  };
  if (requestId) headers['PayPal-Request-Id'] = requestId;
  const response = await fetch(API_BASE + path, {
    method,
    headers,
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    console.error('PayPal API error', method, path, response.status, payload.name || 'unknown');
    throw new HttpsError('unavailable', 'O PayPal não conseguiu processar o pedido. Tenta novamente.');
  }
  return payload;
}

function approvalUrl(payload) {
  const link = (payload.links || []).find((item) =>
    item.rel === 'approve' || item.rel === 'payer-action');
  if (!link || typeof link.href !== 'string' || !link.href.startsWith('https://')) {
    throw new HttpsError('unavailable', 'O PayPal não devolveu o link de aprovação.');
  }
  return link.href;
}

exports.startPayPalCheckout = onCall({
  region: REGION,
  secrets: [PAYPAL_CLIENT_ID, PAYPAL_CLIENT_SECRET],
  timeoutSeconds: 60,
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Inicia sessão antes de comprar o AnimPro Pro.');
  }
  const plan = request.data && request.data.plan;
  if (plan !== 'monthly' && plan !== 'lifetime') {
    throw new HttpsError('invalid-argument', 'Plano inválido.');
  }
  requireHttps(RETURN_URL, 'PAYPAL_RETURN_URL');
  requireHttps(CANCEL_URL, 'PAYPAL_CANCEL_URL');

  if (plan === 'monthly' && !MONTHLY_PLAN_ID) {
    throw new HttpsError(
      'failed-precondition',
      'O plano mensal PayPal ainda não foi criado. Executa o workflow de configuração PayPal.',
    );
  }

  const uid = request.auth.uid;
  const token = await accessToken();
  if (plan === 'monthly') {
    const subscription = await paypalRequest(token, 'POST', '/v1/billing/subscriptions', {
      plan_id: MONTHLY_PLAN_ID,
      custom_id: uid,
      application_context: {
        brand_name: 'AnimPro',
        locale: 'pt-PT',
        user_action: 'SUBSCRIBE_NOW',
        shipping_preference: 'NO_SHIPPING',
        return_url: RETURN_URL + '?plan=monthly',
        cancel_url: CANCEL_URL,
      },
    }, 'animpro-sub-' + uid + '-' + Date.now());

    const ref = db.collection('paypalSubscriptions').doc(subscription.id);
    await ref.set({
      uid,
      plan: 'monthly',
      planId: MONTHLY_PLAN_ID,
      status: 'pending',
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    return { plan, subscriptionId: subscription.id, approvalUrl: approvalUrl(subscription) };
  }

  const order = await paypalRequest(token, 'POST', '/v2/checkout/orders', {
    intent: 'CAPTURE',
    purchase_units: [{
      reference_id: 'animpro-pro-lifetime',
      custom_id: uid,
      description: 'AnimPro Pro Permanente',
      amount: { currency_code: 'USD', value: '50.00' },
    }],
    application_context: {
      brand_name: 'AnimPro',
      user_action: 'PAY_NOW',
      shipping_preference: 'NO_SHIPPING',
      return_url: RETURN_URL + '?plan=lifetime',
      cancel_url: CANCEL_URL,
    },
  }, 'animpro-life-' + uid + '-' + Date.now());

  await db.collection('paypalOrders').doc(order.id).set({
    uid,
    plan: 'lifetime',
    status: 'pending',
    amount: '50.00',
    currency: 'USD',
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  return { plan, orderId: order.id, approvalUrl: approvalUrl(order) };
});

function timestampOrGracePeriod(value) {
  if (typeof value === 'string') {
    const date = new Date(value);
    if (!Number.isNaN(date.getTime())) return Timestamp.fromDate(date);
  }
  // The next billing date is normally included by PayPal. Use a finite grace
  // period if it is missing; never interpret a monthly subscription as lifetime.
  return Timestamp.fromDate(new Date(Date.now() + 35 * 24 * 60 * 60 * 1000));
}

async function grantLifetime(uid, orderId, captureId) {
  await db.collection('proEntitlements').doc(uid).set({
    active: true,
    type: 'lifetime',
    expiresAt: null,
    source: 'paypal',
    orderId,
    captureId,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
}

async function handleOrderApproved(event, token) {
  const orderId = event.resource && event.resource.id;
  if (!orderId) throw new Error('PayPal order approval event has no order ID.');
  const orderRef = db.collection('paypalOrders').doc(orderId);
  const orderDoc = await orderRef.get();
  if (!orderDoc.exists) {
    console.warn('Ignoring unknown PayPal order', orderId);
    return;
  }
  const orderData = orderDoc.data();
  if (orderData.plan !== 'lifetime' || !orderData.uid) return;
  if (orderData.status === 'completed') return;

  const details = await paypalRequest(token, 'GET', '/v2/checkout/orders/' + encodeURIComponent(orderId));
  const purchaseUnit = (details.purchase_units || [])[0];
  if (!purchaseUnit || purchaseUnit.custom_id !== orderData.uid ||
      !purchaseUnit.amount || purchaseUnit.amount.currency_code !== 'USD' ||
      purchaseUnit.amount.value !== '50.00') {
    throw new Error('PayPal order does not match the expected AnimPro amount or user.');
  }

  let capture = null;
  if (details.status === 'COMPLETED') {
    // Recover safely if PayPal captured the order but a previous webhook delivery
    // failed before Firestore could record the entitlement.
    capture = ((purchaseUnit.payments && purchaseUnit.payments.captures) || [])
      .find((item) => item.status === 'COMPLETED') || null;
  } else if (details.status === 'APPROVED') {
    const captured = await paypalRequest(
      token, 'POST',
      '/v2/checkout/orders/' + encodeURIComponent(orderId) + '/capture',
      {},
      'animpro-capture-' + orderId,
    );
    const captureUnit = (captured.purchase_units || [])[0];
    capture = captureUnit && captureUnit.payments &&
      (captureUnit.payments.captures || [])[0];
    if (captured.status !== 'COMPLETED') capture = null;
  }

  if (!capture || capture.status !== 'COMPLETED' ||
      !capture.amount || capture.amount.currency_code !== 'USD' ||
      capture.amount.value !== '50.00') {
    throw new Error('PayPal did not confirm a completed USD 50.00 capture.');
  }

  await grantLifetime(orderData.uid, orderId, capture.id);
  await orderRef.set({
    status: 'completed',
    captureId: capture.id,
    completedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
}

async function handleSubscriptionEvent(event) {
  const resource = event.resource || {};
  const subscriptionId = event.event_type.startsWith('PAYMENT.SALE.')
    ? (resource.billing_agreement_id ? String(resource.billing_agreement_id) : '')
    : (resource.id || (resource.billing_agreement_id ? String(resource.billing_agreement_id) : ''));
  let uid = resource.custom_id || '';
  let subscriptionData = null;

  if (subscriptionId) {
    const ref = db.collection('paypalSubscriptions').doc(subscriptionId);
    const snapshot = await ref.get();
    subscriptionData = snapshot.exists ? snapshot.data() : null;
    if (!uid && subscriptionData) uid = subscriptionData.uid;
  }
  if (!uid) {
    console.warn('Ignoring PayPal subscription event without mapped Firebase UID', event.event_type);
    return;
  }

  const type = event.event_type;
  if (type === 'BILLING.SUBSCRIPTION.ACTIVATED' ||
      type === 'PAYMENT.SALE.COMPLETED' ||
      (type === 'BILLING.SUBSCRIPTION.UPDATED' &&
       (!resource.status || resource.status === 'ACTIVE'))) {
    const currentEntitlement = await db.collection('proEntitlements').doc(uid).get();
    if (currentEntitlement.exists &&
        currentEntitlement.data().active === true &&
        currentEntitlement.data().type === 'lifetime') {
      return; // A recurring webhook must never downgrade a lifetime licence.
    }
    const expiresAt = timestampOrGracePeriod(
      resource.billing_info && resource.billing_info.next_billing_time,
    );
    await db.collection('proEntitlements').doc(uid).set({
      active: true,
      type: 'monthly',
      expiresAt,
      source: 'paypal',
      subscriptionId: subscriptionId || (subscriptionData && subscriptionData.subscriptionId) || null,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    if (subscriptionId) {
      await db.collection('paypalSubscriptions').doc(subscriptionId).set({
        uid,
        plan: 'monthly',
        status: type === 'PAYMENT.SALE.COMPLETED' ? 'active' : (resource.status || 'active'),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    }
  } else if ([
    'BILLING.SUBSCRIPTION.CANCELLED',
    'BILLING.SUBSCRIPTION.SUSPENDED',
    'BILLING.SUBSCRIPTION.EXPIRED',
    'BILLING.SUBSCRIPTION.PAYMENT.FAILED',
    'BILLING.SUBSCRIPTION.UPDATED',
    'PAYMENT.SALE.REFUNDED',
    'PAYMENT.SALE.REVERSED',
  ].includes(type)) {
    const entitlementRef = db.collection('proEntitlements').doc(uid);
    const entitlement = await entitlementRef.get();
    if (entitlement.exists && entitlement.data().type === 'monthly') {
      await entitlementRef.set({
        active: false,
        revokedReason: type,
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    }
    if (subscriptionId) {
      await db.collection('paypalSubscriptions').doc(subscriptionId).set({
        uid,
        plan: 'monthly',
        status: type,
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    }
  }
}

exports.paypalWebhook = onRequest({
  region: REGION,
  secrets: [PAYPAL_CLIENT_ID, PAYPAL_CLIENT_SECRET, PAYPAL_WEBHOOK_ID],
  timeoutSeconds: 120,
  memory: '256MiB',
}, async (req, res) => {
  if (req.method !== 'POST') {
    res.set('Allow', 'POST').status(405).send('Method not allowed');
    return;
  }

  try {
    const event = req.body;
    if (!event || typeof event.id !== 'string' || typeof event.event_type !== 'string') {
      res.status(400).send('Invalid event payload');
      return;
    }

    const token = await accessToken();
    const verification = await paypalRequest(
      token,
      'POST',
      '/v1/notifications/verify-webhook-signature',
      {
        auth_algo: req.get('paypal-auth-algo'),
        cert_url: req.get('paypal-cert-url'),
        transmission_id: req.get('paypal-transmission-id'),
        transmission_sig: req.get('paypal-transmission-sig'),
        transmission_time: req.get('paypal-transmission-time'),
        webhook_id: PAYPAL_WEBHOOK_ID.value(),
        webhook_event: event,
      },
    );
    if (verification.verification_status !== 'SUCCESS') {
      console.warn('Rejected unverified PayPal webhook event', event.id);
      res.status(401).send('Webhook signature verification failed');
      return;
    }

    const eventRef = db.collection('paypalWebhookEvents').doc(event.id);
    const alreadyProcessed = await eventRef.get();
    if (alreadyProcessed.exists && alreadyProcessed.data().processed === true) {
      res.status(200).send('Already processed');
      return;
    }

    if (event.event_type === 'CHECKOUT.ORDER.APPROVED') {
      await handleOrderApproved(event, token);
    } else if (event.event_type.startsWith('BILLING.SUBSCRIPTION.') ||
               event.event_type.startsWith('PAYMENT.SALE.')) {
      await handleSubscriptionEvent(event);
    }

    await eventRef.set({
      eventType: event.event_type,
      processed: true,
      processedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    res.status(200).send('OK');
  } catch (error) {
    console.error('PayPal webhook processing failed:', error.message || 'unknown error');
    // A 5xx asks PayPal to retry after transient or server errors.
    res.status(500).send('Webhook processing failed');
  }
});
