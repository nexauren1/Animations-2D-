import test from "node:test";
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
