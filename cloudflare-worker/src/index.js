const JSON_HEADERS = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store",
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "GET,POST,OPTIONS",
  "access-control-allow-headers": "authorization,content-type",
};

let cachedGoogleToken = "";
let cachedGoogleTokenExpiresAt = 0;

class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

function json(data, status) {
  return new Response(JSON.stringify(data), {
    status: status || 200,
    headers: JSON_HEADERS,
  });
}

function fail(status, message) {
  return json({ error: message }, status);
}

function base64Url(value) {
  const bytes = typeof value === "string" ? new TextEncoder().encode(value) : value;
  let binary = "";
  for (let i = 0; i < bytes.length; i += 1) binary += String.fromCharCode(bytes[i]);
  return btoa(binary).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

function pemToBytes(pem) {
  const normalized = String(pem || "").replace(/\\n/g, "\n");
  const body = normalized
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s/g, "");
  if (!body) throw new HttpError(503, "A credencial de servidor Firebase não está configurada.");
  const raw = atob(body);
  const bytes = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i += 1) bytes[i] = raw.charCodeAt(i);
  return bytes;
}

function encodeFirestoreValue(value) {
  if (value === null) return { nullValue: "NULL_VALUE" };
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (typeof value === "boolean") return { booleanValue: value };
  if (typeof value === "number" && Number.isInteger(value)) {
    return { integerValue: String(value) };
  }
  if (typeof value === "number") return { doubleValue: value };
  if (typeof value === "string") return { stringValue: value };
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(encodeFirestoreValue) } };
  }
  if (typeof value === "object") {
    const fields = {};
    for (const key of Object.keys(value)) fields[key] = encodeFirestoreValue(value[key]);
    return { mapValue: { fields: fields } };
  }
  throw new Error("Tipo de valor Firestore não suportado.");
}

function decodeFirestoreValue(value) {
  if (!value || typeof value !== "object") return null;
  if ("nullValue" in value) return null;
  if ("stringValue" in value) return value.stringValue;
  if ("booleanValue" in value) return value.booleanValue;
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return value.doubleValue;
  if ("timestampValue" in value) return new Date(value.timestampValue);
  if ("arrayValue" in value) {
    return (value.arrayValue.values || []).map(decodeFirestoreValue);
  }
  if ("mapValue" in value) return decodeFirestoreFields(value.mapValue.fields || {});
  return null;
}

function decodeFirestoreFields(fields) {
  const result = {};
  for (const key of Object.keys(fields || {})) {
    result[key] = decodeFirestoreValue(fields[key]);
  }
  return result;
}

async function firebaseUserId(request, env) {
  if (!env.FIREBASE_API_KEY || !env.FIREBASE_PROJECT_ID) {
    throw new HttpError(503, "Falta configurar FIREBASE_API_KEY e FIREBASE_PROJECT_ID no Worker Cloudflare.");
  }
  const authorization = request.headers.get("authorization") || "";
  const match = authorization.match(/^Bearer\s+(.+)$/i);
  if (!match) throw new HttpError(401, "Inicia sessão no AnimPro antes de comprar.");

  // Identity Toolkit validates the Firebase ID token; never trust a UID sent by the app.
  const response = await fetch(
    "https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=" +
      encodeURIComponent(env.FIREBASE_API_KEY),
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ idToken: match[1] }),
    },
  );
  const payload = await response.json().catch(() => ({}));
  const user = payload.users && payload.users[0];
  if (!response.ok || !user || !user.localId) {
    throw new HttpError(401, "A sessão Firebase expirou ou não é válida. Entra novamente.");
  }
  return user.localId;
}

async function googleAccessToken(env) {
  if (cachedGoogleToken && cachedGoogleTokenExpiresAt > Date.now() + 60000) {
    return cachedGoogleToken;
  }
  if (!env.FIREBASE_SERVICE_ACCOUNT_JSON || !env.FIREBASE_PROJECT_ID) {
    throw new HttpError(
      503,
      "Falta configurar FIREBASE_SERVICE_ACCOUNT_JSON e FIREBASE_PROJECT_ID no Worker Cloudflare.",
    );
  }

  let account;
  try {
    account = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT_JSON);
  } catch (_) {
    throw new HttpError(503, "FIREBASE_SERVICE_ACCOUNT_JSON não contém JSON válido.");
  }
  if (
    account.type !== "service_account" ||
    !account.client_email ||
    !account.private_key ||
    account.project_id !== env.FIREBASE_PROJECT_ID
  ) {
    throw new HttpError(503, "A conta de serviço Firebase não corresponde ao projeto configurado.");
  }

  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64Url(JSON.stringify({
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/datastore",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = header + "." + claims;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToBytes(account.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const assertion = unsigned + "." + base64Url(new Uint8Array(signature));

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: assertion,
    }).toString(),
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok || !payload.access_token) {
    console.error("Google OAuth token request failed with HTTP " + response.status);
    throw new HttpError(503, "Não foi possível autenticar o servidor no Firestore.");
  }
  cachedGoogleToken = payload.access_token;
  cachedGoogleTokenExpiresAt = Date.now() + Math.max(60, Number(payload.expires_in || 3600)) * 1000;
  return cachedGoogleToken;
}

function firestoreRoot(env) {
  return "https://firestore.googleapis.com/v1/projects/" +
    encodeURIComponent(env.FIREBASE_PROJECT_ID) +
    "/databases/(default)/documents";
}

async function firestoreRequest(env, path, method, body, ignore404) {
  const token = await googleAccessToken(env);
  const requestUrl = firestoreRoot(env) + (path.startsWith(":") ? path : "/" + path);
  const response = await fetch(requestUrl, {
    method: method || "GET",
    headers: {
      authorization: "Bearer " + token,
      "content-type": "application/json",
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  if (response.status === 404 && ignore404) return null;
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    console.error("Firestore REST request failed with HTTP " + response.status);
    throw new HttpError(503, "O servidor não conseguiu atualizar a licença no Firestore.");
  }
  return payload;
}

async function getDoc(env, collection, id) {
  const result = await firestoreRequest(
    env,
    collection + "/" + encodeURIComponent(id),
    "GET",
    undefined,
    true,
  );
  return result ? decodeFirestoreFields(result.fields || {}) : null;
}

async function setDoc(env, collection, id, fields) {
  const query = new URLSearchParams();
  for (const key of Object.keys(fields)) query.append("updateMask.fieldPaths", key);
  const path = collection + "/" + encodeURIComponent(id) + "?" + query.toString();
  const encoded = {};
  for (const key of Object.keys(fields)) encoded[key] = encodeFirestoreValue(fields[key]);
  return firestoreRequest(env, path, "PATCH", { fields: encoded }, false);
}

async function queryDocByField(env, collection, fieldName, value) {
  const result = await firestoreRequest(
    env,
    ":runQuery",
    "POST",
    {
      structuredQuery: {
        from: [{ collectionId: collection }],
        where: {
          fieldFilter: {
            field: { fieldPath: fieldName },
            op: "EQUAL",
            value: encodeFirestoreValue(value),
          },
        },
        limit: 1,
      },
    },
    false,
  );
  const row = (result || []).find((item) => item.document);
  if (!row) return null;
  const document = row.document;
  const pieces = document.name.split("/");
  return {
    id: pieces[pieces.length - 1],
    data: decodeFirestoreFields(document.fields || {}),
  };
}

function paypalApiBase(env) {
  return (env.PAYPAL_API_BASE || "https://api-m.sandbox.paypal.com").replace(/\/$/, "");
}

async function paypalAccessToken(env) {
  if (!env.PAYPAL_CLIENT_ID || !env.PAYPAL_CLIENT_SECRET) {
    throw new HttpError(503, "Configura PAYPAL_CLIENT_ID e PAYPAL_CLIENT_SECRET nos segredos do Worker.");
  }
  const response = await fetch(paypalApiBase(env) + "/v1/oauth2/token", {
    method: "POST",
    headers: {
      authorization: "Basic " + btoa(env.PAYPAL_CLIENT_ID + ":" + env.PAYPAL_CLIENT_SECRET),
      "content-type": "application/x-www-form-urlencoded",
    },
    body: "grant_type=client_credentials",
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok || !payload.access_token) {
    console.error("PayPal OAuth failed with HTTP " + response.status);
    throw new HttpError(503, "Não foi possível autenticar no PayPal Sandbox.");
  }
  return payload.access_token;
}

async function paypalRequest(env, token, method, path, body, requestId) {
  const headers = {
    authorization: "Bearer " + token,
    accept: "application/json",
    "content-type": "application/json",
  };
  if (requestId) headers["PayPal-Request-Id"] = requestId;
  const response = await fetch(paypalApiBase(env) + path, {
    method: method,
    headers: headers,
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    console.error("PayPal API failed: " + method + " " + path + " HTTP " + response.status);
    throw new HttpError(502, "O PayPal não conseguiu processar o pedido. Tenta novamente.");
  }
  return payload;
}

function approvalUrl(payload) {
  const link = (payload.links || []).find((item) =>
    item.rel === "approve" || item.rel === "payer-action");
  if (!link || typeof link.href !== "string") {
    throw new HttpError(502, "O PayPal não devolveu um link de aprovação.");
  }
  const url = new URL(link.href);
  const allowed = url.hostname === "paypal.com" ||
    url.hostname.endsWith(".paypal.com") ||
    url.hostname === "sandbox.paypal.com" ||
    url.hostname.endsWith(".sandbox.paypal.com");
  if (url.protocol !== "https:" || !allowed) {
    throw new HttpError(502, "O PayPal devolveu um endereço de aprovação inválido.");
  }
  return url.toString();
}

async function startCheckout(request, env) {
  const uid = await firebaseUserId(request, env);
  const body = await request.json().catch(() => null);
  const plan = body && body.plan;
  if (plan !== "monthly" && plan !== "lifetime") {
    throw new HttpError(400, "Plano inválido.");
  }
  const token = await paypalAccessToken(env);
  const returnUrl = env.PAYPAL_RETURN_URL ||
    "https://nexauren1.github.io/Animations-2D-/payment-return.html";
  const cancelUrl = env.PAYPAL_CANCEL_URL ||
    "https://nexauren1.github.io/Animations-2D-/payment-return.html?cancelled=1";

  if (plan === "monthly") {
    const monthlyPlanId = env.PAYPAL_MONTHLY_PLAN_ID;
    if (!monthlyPlanId) {
      throw new HttpError(503, "Falta configurar PAYPAL_MONTHLY_PLAN_ID no Worker.");
    }
    const subscription = await paypalRequest(
      env,
      token,
      "POST",
      "/v1/billing/subscriptions",
      {
        plan_id: monthlyPlanId,
        custom_id: uid,
        application_context: {
          brand_name: "AnimPro",
          locale: "pt-PT",
          user_action: "SUBSCRIBE_NOW",
          shipping_preference: "NO_SHIPPING",
          return_url: returnUrl + "?plan=monthly",
          cancel_url: cancelUrl,
        },
      },
      "animpro-sub-" + uid + "-" + Date.now(),
    );
    if (!subscription.id) throw new HttpError(502, "O PayPal não devolveu o ID da subscrição.");
    await setDoc(env, "paypalSubscriptions", subscription.id, {
      uid: uid,
      plan: "monthly",
      planId: monthlyPlanId,
      status: "pending",
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    return json({
      plan: "monthly",
      subscriptionId: subscription.id,
      approvalUrl: approvalUrl(subscription),
    });
  }

  const order = await paypalRequest(
    env,
    token,
    "POST",
    "/v2/checkout/orders",
    {
      intent: "CAPTURE",
      purchase_units: [{
        reference_id: "animpro-pro-lifetime",
        custom_id: uid,
        description: "AnimPro Pro Permanente",
        amount: { currency_code: "USD", value: "50.00" },
      }],
      application_context: {
        brand_name: "AnimPro",
        user_action: "PAY_NOW",
        shipping_preference: "NO_SHIPPING",
        return_url: returnUrl + "?plan=lifetime",
        cancel_url: cancelUrl,
      },
    },
    "animpro-life-" + uid + "-" + Date.now(),
  );
  if (!order.id) throw new HttpError(502, "O PayPal não devolveu o ID da ordem.");
  await setDoc(env, "paypalOrders", order.id, {
    uid: uid,
    plan: "lifetime",
    status: "pending",
    amount: "50.00",
    currency: "USD",
    createdAt: new Date(),
    updatedAt: new Date(),
  });
  return json({ plan: "lifetime", orderId: order.id, approvalUrl: approvalUrl(order) });
}

async function grantLifetime(env, uid, orderId, captureId) {
  await setDoc(env, "proEntitlements", uid, {
    active: true,
    type: "lifetime",
    expiresAt: null,
    source: "paypal",
    orderId: orderId,
    captureId: captureId,
    updatedAt: new Date(),
  });
}

async function handleOrderApproved(env, event, token) {
  const orderId = event.resource && event.resource.id;
  if (!orderId) throw new Error("PayPal approval event has no order ID.");
  const order = await getDoc(env, "paypalOrders", orderId);
  if (!order || order.plan !== "lifetime" || !order.uid) return;
  if (order.status === "completed") return;

  const details = await paypalRequest(
    env,
    token,
    "GET",
    "/v2/checkout/orders/" + encodeURIComponent(orderId),
  );
  const purchaseUnit = (details.purchase_units || [])[0];
  if (
    !purchaseUnit ||
    purchaseUnit.custom_id !== order.uid ||
    !purchaseUnit.amount ||
    purchaseUnit.amount.currency_code !== "USD" ||
    purchaseUnit.amount.value !== "50.00"
  ) {
    throw new Error("PayPal order does not match the expected AnimPro amount or user.");
  }

  let capture = null;
  if (details.status === "COMPLETED") {
    capture = ((purchaseUnit.payments && purchaseUnit.payments.captures) || [])
      .find((item) => item.status === "COMPLETED") || null;
  } else if (details.status === "APPROVED") {
    const captured = await paypalRequest(
      env,
      token,
      "POST",
      "/v2/checkout/orders/" + encodeURIComponent(orderId) + "/capture",
      {},
      "animpro-capture-" + orderId,
    );
    const captureUnit = (captured.purchase_units || [])[0];
    capture = captureUnit && captureUnit.payments &&
      (captureUnit.payments.captures || [])[0];
    if (captured.status !== "COMPLETED") capture = null;
  }
  if (
    !capture ||
    capture.status !== "COMPLETED" ||
    !capture.amount ||
    capture.amount.currency_code !== "USD" ||
    capture.amount.value !== "50.00"
  ) {
    throw new Error("PayPal did not confirm a completed USD 50.00 capture.");
  }

  await grantLifetime(env, order.uid, orderId, capture.id);
  await setDoc(env, "paypalOrders", orderId, {
    status: "completed",
    captureId: capture.id,
    completedAt: new Date(),
    updatedAt: new Date(),
  });
}

async function handleLifetimeCaptureReversal(env, event) {
  const captureId = event.resource && event.resource.id;
  if (!captureId) return;
  const match = await queryDocByField(env, "paypalOrders", "captureId", captureId);
  if (!match) return;
  const order = match.data;
  if (order.plan !== "lifetime" || !order.uid) return;

  const entitlement = await getDoc(env, "proEntitlements", order.uid);
  if (entitlement && entitlement.type === "lifetime" && entitlement.orderId === match.id) {
    await setDoc(env, "proEntitlements", order.uid, {
      active: false,
      revokedReason: event.event_type,
      updatedAt: new Date(),
    });
  }
  await setDoc(env, "paypalOrders", match.id, {
    status: event.event_type === "PAYMENT.CAPTURE.REFUNDED" ? "refunded" : "reversed",
    updatedAt: new Date(),
  });
}

async function handleSubscriptionEvent(env, event, token) {
  const resource = event.resource || {};
  const subscriptionId = event.event_type.startsWith("PAYMENT.SALE.")
    ? String(resource.billing_agreement_id || "")
    : String(resource.id || resource.billing_agreement_id || "");
  if (!subscriptionId) return;

  const subscription = await getDoc(env, "paypalSubscriptions", subscriptionId);
  const uid = subscription && subscription.uid;
  if (!uid || subscription.plan !== "monthly") return;

  const type = event.event_type;
  const isActiveEvent = type === "BILLING.SUBSCRIPTION.ACTIVATED" ||
    type === "PAYMENT.SALE.COMPLETED" ||
    (type === "BILLING.SUBSCRIPTION.UPDATED" && resource.status === "ACTIVE");

  if (isActiveEvent) {
    const entitlement = await getDoc(env, "proEntitlements", uid);
    if (entitlement && entitlement.active === true && entitlement.type === "lifetime") {
      return;
    }
    let expiryValue = resource.billing_info && resource.billing_info.next_billing_time;
    let currentSubscription = resource;
    if (!expiryValue || type === "BILLING.SUBSCRIPTION.ACTIVATED" || type === "PAYMENT.SALE.COMPLETED") {
      try {
        currentSubscription = await paypalRequest(
          env, token, "GET",
          "/v1/billing/subscriptions/" + encodeURIComponent(subscriptionId),
        );
        expiryValue = (currentSubscription.billing_info || {}).next_billing_time || expiryValue;
      } catch (_) {
        // The next billing time in the event is preferable; fallback is finite and conservative.
      }
    }
    let expiresAt = typeof expiryValue === "string" ? new Date(expiryValue) : null;
    if (!expiresAt || Number.isNaN(expiresAt.getTime())) {
      expiresAt = new Date(Date.now() + 35 * 24 * 60 * 60 * 1000);
    }
    await setDoc(env, "proEntitlements", uid, {
      active: true,
      type: "monthly",
      expiresAt: expiresAt,
      source: "paypal",
      subscriptionId: subscriptionId,
      updatedAt: new Date(),
    });
    await setDoc(env, "paypalSubscriptions", subscriptionId, {
      uid: uid,
      plan: "monthly",
      status: type === "PAYMENT.SALE.COMPLETED"
        ? "active"
        : (currentSubscription.status || resource.status || "active"),
      updatedAt: new Date(),
    });
    return;
  }

  const revokeEvents = [
    "BILLING.SUBSCRIPTION.CANCELLED",
    "BILLING.SUBSCRIPTION.SUSPENDED",
    "BILLING.SUBSCRIPTION.EXPIRED",
    "BILLING.SUBSCRIPTION.PAYMENT.FAILED",
    "PAYMENT.SALE.REFUNDED",
    "PAYMENT.SALE.REVERSED",
  ];
  if (
    revokeEvents.includes(type) ||
    (type === "BILLING.SUBSCRIPTION.UPDATED" && resource.status && resource.status !== "ACTIVE")
  ) {
    const entitlement = await getDoc(env, "proEntitlements", uid);
    if (entitlement && entitlement.type === "monthly") {
      await setDoc(env, "proEntitlements", uid, {
        active: false,
        revokedReason: type,
        updatedAt: new Date(),
      });
    }
    await setDoc(env, "paypalSubscriptions", subscriptionId, {
      uid: uid,
      plan: "monthly",
      status: type,
      updatedAt: new Date(),
    });
  }
}

async function handleWebhook(request, env) {
  if (!env.PAYPAL_WEBHOOK_ID) {
    throw new HttpError(503, "Falta configurar PAYPAL_WEBHOOK_ID nos segredos do Worker.");
  }
  const event = await request.json().catch(() => null);
  if (!event || typeof event.id !== "string" || typeof event.event_type !== "string") {
    throw new HttpError(400, "Evento PayPal inválido.");
  }
  const token = await paypalAccessToken(env);
  const verificationBody = {
    auth_algo: request.headers.get("paypal-auth-algo"),
    cert_url: request.headers.get("paypal-cert-url"),
    transmission_id: request.headers.get("paypal-transmission-id"),
    transmission_sig: request.headers.get("paypal-transmission-sig"),
    transmission_time: request.headers.get("paypal-transmission-time"),
    webhook_id: env.PAYPAL_WEBHOOK_ID,
    webhook_event: event,
  };
  if (
    !verificationBody.auth_algo ||
    !verificationBody.cert_url ||
    !verificationBody.transmission_id ||
    !verificationBody.transmission_sig ||
    !verificationBody.transmission_time
  ) {
    throw new HttpError(401, "Cabeçalhos de assinatura PayPal incompletos.");
  }
  const verification = await paypalRequest(
    env, token, "POST", "/v1/notifications/verify-webhook-signature", verificationBody,
  );
  if (verification.verification_status !== "SUCCESS") {
    throw new HttpError(401, "A assinatura do webhook PayPal não foi validada.");
  }

  const previous = await getDoc(env, "paypalWebhookEvents", event.id);
  if (previous && previous.processed === true) {
    return new Response("Already processed", { status: 200, headers: JSON_HEADERS });
  }

  if (event.event_type === "CHECKOUT.ORDER.APPROVED") {
    await handleOrderApproved(env, event, token);
  } else if (
    event.event_type === "PAYMENT.CAPTURE.REFUNDED" ||
    event.event_type === "PAYMENT.CAPTURE.REVERSED"
  ) {
    await handleLifetimeCaptureReversal(env, event);
  } else if (
    event.event_type.startsWith("BILLING.SUBSCRIPTION.") ||
    event.event_type.startsWith("PAYMENT.SALE.")
  ) {
    await handleSubscriptionEvent(env, event, token);
  }

  await setDoc(env, "paypalWebhookEvents", event.id, {
    eventType: event.event_type,
    processed: true,
    processedAt: new Date(),
  });
  return new Response("OK", { status: 200, headers: JSON_HEADERS });
}

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: JSON_HEADERS });
    }
    const url = new URL(request.url);
    if (request.method === "GET" && url.pathname === "/health") {
      return json({ ok: true, service: "animpro-paypal-worker" });
    }
    if (request.method === "POST" && url.pathname === "/api/checkout") {
      try {
        return await startCheckout(request, env);
      } catch (error) {
        if (error instanceof HttpError) return fail(error.status, error.message);
        console.error("Checkout failed:", error && error.message ? error.message : "unknown error");
        return fail(500, "Não foi possível iniciar o checkout. Verifica a configuração do Worker.");
      }
    }
    if (request.method === "POST" && url.pathname === "/api/paypal/webhook") {
      try {
        return await handleWebhook(request, env);
      } catch (error) {
        if (error instanceof HttpError) return fail(error.status, error.message);
        console.error("PayPal webhook failed:", error && error.message ? error.message : "unknown error");
        return fail(500, "Não foi possível processar o evento PayPal.");
      }
    }
    return fail(404, "Endpoint não encontrado.");
  },
};
