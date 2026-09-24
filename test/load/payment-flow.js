// Real capacity test for the payment authorization path, not a smoke
// test. payment-flow.js proves correctness under light, steady load;
// this ramps the write path until it actually strains, races the
// same idempotency key under real concurrency, and mixes in the read
// endpoints the console/frontend actually uses, all at once.
//
// Run: k6 run test/load/stress.js
import http from "k6/http";
import { check } from "k6";

const BASE = __ENV.BASE_URL || "http://localhost:8080";

export const options = {
  scenarios: {
    write_ramp: {
      executor: "ramping-arrival-rate",
      exec: "writeTraffic",
      startRate: 50,
      timeUnit: "1s",
      preAllocatedVUs: 300,
      maxVUs: 3000,
      stages: [
        { target: 100, duration: "20s" },
        { target: 300, duration: "30s" },
        { target: 600, duration: "30s" },
        { target: 1000, duration: "30s" },
        { target: 1500, duration: "30s" },
        { target: 0, duration: "10s" },
      ],
    },
    read_mix: {
      executor: "constant-vus",
      exec: "readTraffic",
      vus: 30,
      duration: "150s",
      startTime: "5s",
    },
    idempotency_race: {
      executor: "shared-iterations",
      exec: "idempotencyRace",
      vus: 60,
      iterations: 60,
      startTime: "160s",
      maxDuration: "20s",
    },
  },
  thresholds: {
    "http_req_duration{scenario:write_ramp}": ["p(99)<5000"],
  },
};

const accounts = [
  "00000000-0000-0000-0000-000000000002",
  "00000000-0000-0000-0000-000000000003",
];

function pick(list) {
  return list[Math.floor(Math.random() * list.length)];
}

export function writeTraffic() {
  const roll = Math.random();

  let body;
  if (roll < 0.05) {
    body = {
      account_id: pick(accounts),
      card_fingerprint: "fp_stolen_card_001",
      amount_cents: 10000,
      currency: "BRL",
      merchant_category: "electronics",
    };
  } else if (roll < 0.2) {
    body = {
      account_id: pick(accounts),
      card_fingerprint: `fp_stress_${__VU}`,
      amount_cents: 480000,
      currency: "BRL",
      merchant_category: "gambling",
    };
  } else {
    body = {
      account_id: pick(accounts),
      card_fingerprint: `fp_stress_${__VU}`,
      amount_cents: Math.floor(Math.random() * 20000) + 1000,
      currency: "BRL",
      merchant_category: "electronics",
    };
  }

  const res = http.post(`${BASE}/v1/payments`, JSON.stringify(body), {
    headers: {
      "Content-Type": "application/json",
      "Idempotency-Key": `stress-${__VU}-${__ITER}-${Date.now()}`,
      "X-Forwarded-For": `10.98.${Math.floor(__VU / 250)}.${__VU % 250}`,
    },
    tags: { name: "authorize" },
  });

  check(res, {
    "status is 201": (r) => r.status === 201,
    "has payment_id": (r) => r.json("payment_id") !== "",
  });
}

export function readTraffic() {
  const recent = http.get(`${BASE}/v1/payments/recent`, {
    tags: { name: "payments_recent" },
  });
  check(recent, { "recent status is 200": (r) => r.status === 200 });

  const reviews = http.get(`${BASE}/v1/reviews?status=pending`, {
    tags: { name: "reviews_pending" },
  });
  check(reviews, { "reviews status is 200": (r) => r.status === 200 });
}

export function idempotencyRace() {
  const body = {
    account_id: accounts[0],
    card_fingerprint: "fp_idempotency_race",
    amount_cents: 5000,
    currency: "BRL",
    merchant_category: "electronics",
  };

  const res = http.post(`${BASE}/v1/payments`, JSON.stringify(body), {
    headers: {
      "Content-Type": "application/json",
      "Idempotency-Key": "stress-idempotency-race-key",
      "X-Forwarded-For": "10.98.99.1",
    },
    tags: { name: "idempotency_race" },
  });

  check(res, {
    "status is 201": (r) => r.status === 201,
    "has payment_id": (r) => r.json("payment_id") !== "",
  });
}
