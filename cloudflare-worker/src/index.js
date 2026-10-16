const JSON_HEADERS = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store",
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "GET,POST,OPTIONS",
  "access-control-allow-headers": "authorization,content-type",
};

let cachedGoogleToken = "";
let cachedGoogleTokenExpiresAt = 0;

const PAYPAL_SANDBOX_API_BASE = "https://api-m.sandbox.paypal.com";
const PAYPAL_LIVE_API_BASE = "https://api-m.paypal.com";
// Resolve the PayPal environment from the credentials server-side. This keeps
// the mobile app independent of Sandbox/Live switches and supports key rotation.
const paypalResolvedBases = new WeakMap();

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
  if (!body) throw new HttpError(503, "O serviço de pagamentos está temporariamente indisponível.");
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
  const authorization = request.headers.get("authorization") || "";
  const match = authorization.match(/^Bearer\s+(.+)$/i);
  if (!match) throw new HttpError(401, "Inicia sessão no AnimPro antes de comprar.");
  if (!env.FIREBASE_API_KEY || !env.FIREBASE_PROJECT_ID) {
    throw new HttpError(503, "O serviço de conta está temporariamente indisponível.");
  }

  // Resolve the ID token with Firebase Identity Toolkit. Never trust a UID supplied by the app.
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
    throw new HttpError(401, "A sessão expirou. Entra novamente na tua conta.");
  }
  if (user.disabled === true) {
    throw new HttpError(403, "Esta conta não está disponível para compras.");
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
      "O serviço de pagamentos está temporariamente indisponível.",
    );
  }

  let account;
  try {
    account = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT_JSON);
  } catch (_) {
    throw new HttpError(503, "O serviço de pagamentos está temporariamente indisponível.");
  }
  if (
    account.type !== "service_account" ||
    !account.client_email ||
    !account.private_key ||
    account.project_id !== env.FIREBASE_PROJECT_ID
  ) {
    throw new HttpError(503, "O serviço de pagamentos está temporariamente indisponível.");
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

function paypalMode(env) {
  const mode = String(env.PAYPAL_MODE || env.PAYPAL_ENVIRONMENT || "").trim().toLowerCase();
  if (mode === "live" || mode === "production") return "live";
  if (mode === "sandbox" || mode === "test") return "sandbox";
  if (mode) {
    throw new HttpError(503, "PAYPAL_MODE deve ser Sandbox ou Live.");
  }
  return "";
}

function paypalApiBase(env) {
  const resolved = paypalResolvedBases.get(env);
  if (resolved) return resolved;
  const mode = paypalMode(env);
  if (mode === "live") return PAYPAL_LIVE_API_BASE;
  if (mode === "sandbox") return PAYPAL_SANDBOX_API_BASE;
  const configured = String(env.PAYPAL_API_BASE || "").trim().replace(/\/$/, "");
  if (configured === PAYPAL_SANDBOX_API_BASE || configured === PAYPAL_LIVE_API_BASE) {
    return configured;
  }
  if (configured) {
    throw new HttpError(503, "PAYPAL_API_BASE não corresponde a um endpoint oficial suportado.");
  }
  return PAYPAL_SANDBOX_API_BASE;
}

function paypalCandidateBases(env) {
  const mode = paypalMode(env);
  if (mode === "live") return [PAYPAL_LIVE_API_BASE];
  if (mode === "sandbox") return [PAYPAL_SANDBOX_API_BASE];

  const configured = String(env.PAYPAL_API_BASE || "").trim().replace(/\/$/, "");
  if (configured && configured !== PAYPAL_SANDBOX_API_BASE && configured !== PAYPAL_LIVE_API_BASE) {
    throw new HttpError(503, "PAYPAL_API_BASE não corresponde a um endpoint oficial suportado.");
  }
  // Try the configured endpoint first, then infer the real environment from
  // OAuth. If only the Client ID/Secret are switched in Cloudflare, no APK
  // update (and no manual base-URL switch) is needed.
  const first = configured || PAYPAL_SANDBOX_API_BASE;
  const second = first === PAYPAL_SANDBOX_API_BASE
    ? PAYPAL_LIVE_API_BASE
    : PAYPAL_SANDBOX_API_BASE;
  return [first, second];
}

async function paypalAccessToken(env) {
  if (!env.PAYPAL_CLIENT_ID || !env.PAYPAL_CLIENT_SECRET) {
    throw new HttpError(503, "O serviço de pagamentos está temporariamente indisponível.");
  }

  let lastStatus = 0;
  for (const base of paypalCandidateBases(env)) {
    try {
      const response = await fetch(base + "/v1/oauth2/token", {
        method: "POST",
        headers: {
          authorization: "Basic " + btoa(env.PAYPAL_CLIENT_ID + ":" + env.PAYPAL_CLIENT_SECRET),
          "content-type": "application/x-www-form-urlencoded",
        },
        body: "grant_type=client_credentials",
      });
      const payload = await response.json().catch(() => ({}));
      if (response.ok && payload.access_token) {
        paypalResolvedBases.set(env, base);
        return payload.access_token;
      }
      lastStatus = response.status;
      // Wrong-environment credentials normally return 401. Try the other
      // official endpoint when mode was not explicitly pinned.
      if (paypalMode(env)) break;
    } catch (_) {
      if (paypalMode(env)) break;
    }
  }

  console.error("PayPal OAuth failed after checking the configured environment(s); HTTP " + lastStatus);
  throw new HttpError(
    503,
    "Não foi possível autenticar no PayPal. Confirma se o Client ID e o Secret pertencem ao mesmo ambiente (Sandbox ou Live).",
  );
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

function approvalUrl(payload, env) {
  const link = (payload.links || []).find((item) =>
    item.rel === "approve" || item.rel === "payer-action");
  if (!link || typeof link.href !== "string") {
    throw new HttpError(502, "O PayPal não devolveu um link de aprovação.");
  }
  const url = new URL(link.href);
  const host = url.hostname.toLowerCase();
  const sandboxHost = host === "sandbox.paypal.com" || host.endsWith(".sandbox.paypal.com");
  const liveHost = (host === "paypal.com" || host.endsWith(".paypal.com")) && !sandboxHost;
  const expectedHost = paypalApiBase(env) === PAYPAL_SANDBOX_API_BASE ? sandboxHost : liveHost;
  if (url.protocol !== "https:" || !expectedHost) {
    throw new HttpError(502, "O PayPal devolveu um link de aprovação incompatível com o ambiente ativo.");
  }
  return url.toString();
}

function entitlementIsActive(entitlement) {
  if (!entitlement || entitlement.active !== true) return false;
  if (entitlement.type === "lifetime" && entitlement.expiresAt == null) return true;
  const expiresAt = parseDate(entitlement.expiresAt);
  return expiresAt !== null && expiresAt.getTime() > Date.now();
}

async function startCheckout(request, env) {
  const uid = await firebaseUserId(request, env);
  const body = await request.json().catch(() => null);
  const plan = body && body.plan;
  if (plan !== "monthly" && plan !== "lifetime") {
    throw new HttpError(400, "Plano inválido.");
  }

  // Prevent accidental duplicate monthly charges when the user's existing
  // entitlement is still valid. A monthly subscriber may still upgrade to
  // the one-time lifetime plan.
  const existingEntitlement = await getDoc(env, "proEntitlements", uid);
  if (
    entitlementIsActive(existingEntitlement) &&
    (
      existingEntitlement.type === "lifetime" ||
      (existingEntitlement.type === "monthly" && plan === "monthly")
    )
  ) {
    throw new HttpError(409, "A tua licença Pro já está ativa. Não precisas de comprar novamente.");
  }
  const token = await paypalAccessToken(env);
  const returnUrl = env.PAYPAL_RETURN_URL ||
    "https://nexauren1.github.io/Animations-2D-/payment-return.html";
  const cancelUrl = env.PAYPAL_CANCEL_URL ||
    "https://nexauren1.github.io/Animations-2D-/payment-return.html?cancelled=1";

  if (plan === "monthly") {
    const liveEnvironment = paypalApiBase(env) === PAYPAL_LIVE_API_BASE;
    const monthlyPlanId = liveEnvironment
      ? env.PAYPAL_MONTHLY_PLAN_ID_LIVE
      : (env.PAYPAL_MONTHLY_PLAN_ID_SANDBOX || env.PAYPAL_MONTHLY_PLAN_ID);
    if (!monthlyPlanId) {
      throw new HttpError(
        503,
        liveEnvironment
          ? "O plano mensal Live ainda não está configurado. Adiciona PAYPAL_MONTHLY_PLAN_ID_LIVE no Cloudflare."
          : "O plano mensal Sandbox ainda não está disponível.",
      );
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
      approvalUrl: approvalUrl(subscription, env),
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
  return json({ plan: "lifetime", orderId: order.id, approvalUrl: approvalUrl(order, env) });
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

function paymentAmountMatches(amount, expectedValue) {
  if (!amount || typeof amount !== "object") return false;
  const currency = amount.currency_code || amount.currency;
  const rawValue = amount.value !== undefined ? amount.value : amount.total;
  return currency === "USD" &&
    (typeof rawValue === "string" || typeof rawValue === "number") &&
    Number.isFinite(Number(rawValue)) &&
    Number(rawValue) === expectedValue;
}

function parseDate(value) {
  if (typeof value !== "string" && !(value instanceof Date)) return null;
  const parsed = value instanceof Date ? new Date(value.getTime()) : new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function paidThroughDate(subscription, paidAt) {
  const nextBilling = parseDate(
    subscription && subscription.billing_info && subscription.billing_info.next_billing_time,
  );
  const latestAcceptable = paidAt.getTime() + 40 * 24 * 60 * 60 * 1000;
  if (
    nextBilling &&
    nextBilling.getTime() > paidAt.getTime() &&
    nextBilling.getTime() <= latestAcceptable
  ) {
    return nextBilling;
  }
  return new Date(paidAt.getTime() + 35 * 24 * 60 * 60 * 1000);
}

async function handleSubscriptionEvent(env, event, token) {
  const resource = event.resource || {};
  const type = event.event_type;
  const subscriptionId = type.startsWith("PAYMENT.SALE.")
    ? String(resource.billing_agreement_id || "")
    : String(resource.id || resource.billing_agreement_id || "");
  if (!subscriptionId) return;

  const subscriptionRef = await getDoc(env, "paypalSubscriptions", subscriptionId);
  if (
    !subscriptionRef ||
    !subscriptionRef.uid ||
    subscriptionRef.plan !== "monthly" ||
    !subscriptionRef.planId
  ) {
    console.warn("Ignoring unmapped subscription event", type);
    return;
  }

  const uid = subscriptionRef.uid;
  const isSaleCompleted = type === "PAYMENT.SALE.COMPLETED";
  const isSubscriptionActive = type === "BILLING.SUBSCRIPTION.ACTIVATED" ||
    (type === "BILLING.SUBSCRIPTION.UPDATED" && resource.status === "ACTIVE");

  if (isSaleCompleted || isSubscriptionActive) {
    // Fetch the canonical subscription. The signed event alone is not enough to
    // prove that this belongs to our USD 5/month plan.
    const currentSubscription = await paypalRequest(
      env,
      token,
      "GET",
      "/v1/billing/subscriptions/" + encodeURIComponent(subscriptionId),
    );
    if (
      currentSubscription.id !== subscriptionId ||
      currentSubscription.plan_id !== subscriptionRef.planId ||
      currentSubscription.custom_id !== uid
    ) {
      console.warn("Ignoring subscription with an unexpected plan ID", subscriptionId);
      return;
    }

    if (!isSaleCompleted) {
      // ACTIVATED/UPDATED may happen without a successful charge. Record status,
      // but grant access only from a verified PAYMENT.SALE.COMPLETED event.
      await setDoc(env, "paypalSubscriptions", subscriptionId, {
        uid: uid,
        plan: "monthly",
        status: currentSubscription.status || resource.status || "active",
        updatedAt: new Date(),
      });
      return;
    }

    if (!paymentAmountMatches(resource.amount, 5)) {
      console.warn("Ignoring subscription sale with unexpected amount", subscriptionId);
      return;
    }

    const billingInfo = currentSubscription.billing_info || {};
    const lastPayment = billingInfo.last_payment || {};
    const eventPaymentAt = parseDate(resource.create_time) ||
      parseDate(resource.update_time);
    const canonicalPaymentAt = parseDate(lastPayment.time);
    if (
      !paymentAmountMatches(lastPayment.amount, 5) ||
      !eventPaymentAt ||
      !canonicalPaymentAt ||
      Math.abs(eventPaymentAt.getTime() - canonicalPaymentAt.getTime()) > 48 * 60 * 60 * 1000
    ) {
      console.warn("Ignoring subscription sale without a matching canonical payment record", subscriptionId);
      return;
    }
    const paymentAt = canonicalPaymentAt;

    const savedPaymentAt = parseDate(subscriptionRef.lastPaymentAt);
    if (savedPaymentAt && savedPaymentAt.getTime() >= paymentAt.getTime()) {
      // Out-of-order or duplicate sale events must never move the paid-through
      // date backwards or extend it from an older transaction.
      return;
    }

    const entitlement = await getDoc(env, "proEntitlements", uid);
    if (entitlement && entitlement.active === true && entitlement.type === "lifetime") {
      return;
    }

    const expiresAt = paidThroughDate(currentSubscription, paymentAt);
    if (expiresAt.getTime() <= Date.now()) {
      console.warn("Ignoring expired subscription sale event", subscriptionId);
      return;
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
      planId: subscriptionRef.planId,
      status: currentSubscription.status || "active",
      lastPaymentAt: paymentAt,
      expiresAt: expiresAt,
      updatedAt: new Date(),
    });
    return;
  }

  if (type === "BILLING.SUBSCRIPTION.CANCELLED") {
    // Cancellation stops renewal; do not remove already-paid access early.
    // ProAccessService and the upgrade screen check the stored expiresAt date.
    await setDoc(env, "paypalSubscriptions", subscriptionId, {
      uid: uid,
      plan: "monthly",
      planId: subscriptionRef.planId,
      status: "CANCELLED",
      cancelledAt: new Date(),
      updatedAt: new Date(),
    });
    return;
  }

  const revocationEvents = [
    "BILLING.SUBSCRIPTION.SUSPENDED",
    "BILLING.SUBSCRIPTION.EXPIRED",
    "BILLING.SUBSCRIPTION.PAYMENT.FAILED",
    "PAYMENT.SALE.REFUNDED",
    "PAYMENT.SALE.REVERSED",
  ];
  const updatedToNonActive =
    type === "BILLING.SUBSCRIPTION.UPDATED" &&
    resource.status &&
    resource.status !== "ACTIVE";

  if (revocationEvents.includes(type) || updatedToNonActive) {
    const entitlement = await getDoc(env, "proEntitlements", uid);
    const expiry = entitlement ? parseDate(entitlement.expiresAt) : null;
    const wasRefundedOrReversed =
      type === "PAYMENT.SALE.REFUNDED" || type === "PAYMENT.SALE.REVERSED";
    const accessAlreadyExpired = !expiry || expiry.getTime() <= Date.now();
    if (
      entitlement &&
      entitlement.type === "monthly" &&
      (wasRefundedOrReversed || accessAlreadyExpired || type === "BILLING.SUBSCRIPTION.EXPIRED")
    ) {
      await setDoc(env, "proEntitlements", uid, {
        active: false,
        revokedReason: type,
        updatedAt: new Date(),
      });
    }
    await setDoc(env, "paypalSubscriptions", subscriptionId, {
      uid: uid,
      plan: "monthly",
      planId: subscriptionRef.planId,
      status: type === "BILLING.SUBSCRIPTION.UPDATED"
        ? String(resource.status)
        : type,
      updatedAt: new Date(),
    });
  }
}

async function handleWebhook(request, env) {
  if (!env.PAYPAL_WEBHOOK_ID) {
    throw new HttpError(503, "O serviço de pagamentos está temporariamente indisponível.");
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
