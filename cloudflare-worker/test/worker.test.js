import test from "node:test";
import { generateKeyPairSync } from "node:crypto";
import assert from "node:assert/strict";

import worker from "../src/index.js";

async function call(path, options = {}, env = {}) {
  return worker.fetch(
    new Request("https://animpro-worker.test" + path, options),
    env,
  );
}

test("health endpoint returns only an availability signal", async () => {
  const response = await call("/health");
  assert.equal(response.status, 200);
  assert.match(response.headers.get("cache-control") || "", /no-store/i);
  assert.deepEqual(await response.json(), {
    ok: true,
    service: "animpro-paypal-worker",
  });
});

test("unknown paths do not expose internal route information", async () => {
  const response = await call("/internal-debug");
  assert.equal(response.status, 404);
  assert.deepEqual(await response.json(), { error: "Endpoint não encontrado." });
});

test("CORS preflight does not require credentials", async () => {
  const response = await call("/api/checkout", { method: "OPTIONS" });
  assert.equal(response.status, 204);
});

test("checkout rejects requests without a Firebase bearer token before doing network work", async () => {
  const response = await call("/api/checkout", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ plan: "lifetime" }),
  });
  assert.equal(response.status, 401);
  assert.deepEqual(await response.json(), {
    error: "Inicia sessão no AnimPro antes de comprar.",
  });
});

test("checkout does not trust the client-supplied UID", async () => {
  const response = await call("/api/checkout", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ plan: "lifetime", uid: "someone-else" }),
  });
  assert.equal(response.status, 401);
});

test("webhook fails closed when the signature verification ID is absent", async () => {
  const response = await call("/api/paypal/webhook", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ id: "test-event", event_type: "CHECKOUT.ORDER.APPROVED" }),
  });
  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), {
    error: "O serviço de pagamentos está temporariamente indisponível.",
  });
});

test("checkout recognizes a valid Bearer header before reporting missing server configuration", async () => {
  const response = await call("/api/checkout", {
    method: "POST",
    headers: {
      authorization: "Bearer test-token",
      "content-type": "application/json",
    },
    body: JSON.stringify({ plan: "lifetime" }),
  });
  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), {
    error: "O serviço de conta está temporariamente indisponível.",
  });
});

test("checkout blocks a second monthly subscription while Pro access is paid and active", async () => {
  const previousFetch = globalThis.fetch;
  const calls = [];
  const { privateKey } = generateKeyPairSync("rsa", { modulusLength: 2048 });
  const serviceAccount = {
    type: "service_account",
    project_id: "animpro-audit-test",
    client_email: "worker@animpro-audit-test.iam.gserviceaccount.com",
    private_key: privateKey.export({ type: "pkcs8", format: "pem" }).toString(),
  };

  globalThis.fetch = async (input) => {
    const url = String(input);
    calls.push(url);

    if (url.startsWith("https://identitytoolkit.googleapis.com/v1/accounts:lookup")) {
      return new Response(JSON.stringify({ users: [{ localId: "uid-monthly-test" }] }), {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    }
    if (url === "https://oauth2.googleapis.com/token") {
      return new Response(JSON.stringify({ access_token: "mock-firestore-token", expires_in: 3600 }), {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    }
    if (url.includes("/documents/proEntitlements/uid-monthly-test")) {
      return new Response(JSON.stringify({
        fields: {
          active: { booleanValue: true },
          type: { stringValue: "monthly" },
          expiresAt: { timestampValue: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString() },
        },
      }), {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    }
    throw new Error("Unexpected network request in test: " + url);
  };

  try {
    const response = await call("/api/checkout", {
      method: "POST",
      headers: {
        authorization: "Bearer mock-firebase-id-token",
        "content-type": "application/json",
      },
      body: JSON.stringify({ plan: "monthly" }),
    }, {
      FIREBASE_API_KEY: "mock-firebase-api-key",
      FIREBASE_PROJECT_ID: "animpro-audit-test",
      FIREBASE_SERVICE_ACCOUNT_JSON: JSON.stringify(serviceAccount),
      PAYPAL_CLIENT_ID: "mock-sandbox-client-id",
      PAYPAL_CLIENT_SECRET: "mock-sandbox-client-secret",
      PAYPAL_API_BASE: "https://api-m.sandbox.paypal.com",
      PAYPAL_MONTHLY_PLAN_ID: "P-mock-monthly-plan",
    });

    assert.equal(response.status, 409);
    assert.deepEqual(await response.json(), {
      error: "A tua licença Pro já está ativa. Não precisas de comprar novamente.",
    });
    assert.equal(
      calls.some((url) => url.startsWith("https://api-m.sandbox.paypal.com/")),
      false,
      "PayPal must not be called when a valid monthly entitlement already exists",
    );
  } finally {
    globalThis.fetch = previousFetch;
  }
});

test("checkout detects Live credentials even when the old configured base is Sandbox", async () => {
  const previousFetch = globalThis.fetch;
  const calls = [];
  const { privateKey } = generateKeyPairSync("rsa", { modulusLength: 2048 });
  const serviceAccount = {
    type: "service_account",
    project_id: "animpro-live-test",
    client_email: "worker@animpro-live-test.iam.gserviceaccount.com",
    private_key: privateKey.export({ type: "pkcs8", format: "pem" }).toString(),
  };

  globalThis.fetch = async (input, init = {}) => {
    const url = String(input);
    calls.push({ url, method: init.method || "GET" });

    if (url.startsWith("https://identitytoolkit.googleapis.com/v1/accounts:lookup")) {
      return new Response(JSON.stringify({ users: [{ localId: "uid-live-test" }] }), {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    }
    if (url === "https://oauth2.googleapis.com/token") {
      return new Response(JSON.stringify({ access_token: "mock-firestore-token", expires_in: 3600 }), {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    }
    if (url.includes("/documents/proEntitlements/uid-live-test")) {
      return new Response(JSON.stringify({ error: { status: "NOT_FOUND" } }), {
        status: 404,
        headers: { "content-type": "application/json" },
      });
    }
    if (url === "https://api-m.sandbox.paypal.com/v1/oauth2/token") {
      return new Response(JSON.stringify({ error: "invalid_client" }), {
        status: 401,
        headers: { "content-type": "application/json" },
      });
    }
    if (url === "https://api-m.paypal.com/v1/oauth2/token") {
      return new Response(JSON.stringify({ access_token: "mock-live-paypal-token", expires_in: 3600 }), {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    }
    if (url === "https://api-m.paypal.com/v2/checkout/orders") {
      return new Response(JSON.stringify({
        id: "ORDER-LIVE-TEST",
        links: [{ rel: "approve", href: "https://www.paypal.com/checkoutnow?token=live-test" }],
      }), {
        status: 201,
        headers: { "content-type": "application/json" },
      });
    }
    if (url.includes("/documents/paypalOrders/ORDER-LIVE-TEST")) {
      return new Response(JSON.stringify({ name: "paypalOrders/ORDER-LIVE-TEST" }), {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    }
    throw new Error("Unexpected network request in test: " + url);
  };

  try {
    const response = await call("/api/checkout", {
      method: "POST",
      headers: {
        authorization: "Bearer mock-live-firebase-id-token",
        "content-type": "application/json",
      },
      body: JSON.stringify({ plan: "lifetime" }),
    }, {
      FIREBASE_API_KEY: "mock-firebase-api-key",
      FIREBASE_PROJECT_ID: "animpro-live-test",
      FIREBASE_SERVICE_ACCOUNT_JSON: JSON.stringify(serviceAccount),
      PAYPAL_CLIENT_ID: "mock-live-client-id",
      PAYPAL_CLIENT_SECRET: "mock-live-client-secret",
      // Existing deployments may still have this Sandbox URL. Credentials are
      // switched on the server; the client APK remains unchanged.
      PAYPAL_API_BASE: "https://api-m.sandbox.paypal.com",
    });

    assert.equal(response.status, 200);
    const payload = await response.json();
    assert.equal(payload.approvalUrl, "https://www.paypal.com/checkoutnow?token=live-test");
    assert.equal(
      calls.some((item) => item.url === "https://api-m.paypal.com/v2/checkout/orders" && item.method === "POST"),
      true,
      "Live order creation must use the Live endpoint after Live OAuth succeeds",
    );
  } finally {
    globalThis.fetch = previousFetch;
  }
});

