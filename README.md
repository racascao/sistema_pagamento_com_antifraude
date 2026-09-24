# Payment Processor

A payment platform built as a Go monorepo of four microservices,
with a machine learning fraud decision inside the synchronous
authorization path and an autonomous AI investigation outside it.

This repository is the reference project of a course on building
production AI systems with Go. Every component is written from
scratch on purpose: the tree model inference, the FSM orchestration,
the dynamic batcher and the MCP server are course material, not
vendored dependencies.

## Services

| Service | Port | Role |
|---|---|---|
| gateway | 8080 | Public HTTP API, rate limiting, SSE streaming |
| ledger | 9001 | Money movement, double entry, idempotency, outbox |
| fraud | 9002 | Scoring pipeline: rules, tree model, semantic cache |
| investigator | - | Investigates manual review cases with tools and RAG |
| console | 3001 | Operator web console: live feed, review queue, case detail |

Infrastructure: Postgres 16 with pgvector, Redpanda (Kafka API),
Prometheus and Grafana with a dashboard provisioned as code.

The operator console runs in a pre-built Docker container and lights up progressively as backend capabilities come online: each panel probes the gateway and renders a locked state naming the course module that unlocks it, see docs/adr/0011.

## Quick start

Requirements: Go 1.24+, Docker. Windows users work inside WSL2.

```bash
make setup          # verify tooling
make up             # build and start the full stack
make demo-approved  # a clean payment
make demo-denied    # a blocklisted card
make demo-review    # an ambiguous payment routed to investigation
```

Stream an investigation live (use the payment_id from demo-review):

```bash
make demo-stream PAYMENT_ID=<id>
```

Watch every event and the metrics:

```bash
make demo-feed    # global SSE stream of payments and reviews
make dashboards   # grafana and prometheus URLs
```

## Tests

```bash
make test              # unit tests with race detector
make up                # start the stack first
make test-integration  # end to end through the public API
make bench             # inference and batching benchmarks
make load-test         # k6 latency thresholds (requires k6)
```

## Optional integrations

Everything runs offline by default. Real integrations activate by
environment variable, see .env.example:

| Variable | Effect |
|---|---|
| ANTHROPIC_API_KEY | Claude agent investigates instead of the rule based advisor |
| STRIPE_API_KEY | charges go through Stripe test mode |
| SLACK_WEBHOOK_URL | investigation reports post to Slack |
| RESEND_API_KEY | investigation reports go out by email |
| GEO_PROVIDER=ipapi | real IP geolocation through ipapi.co |

## MCP server

The investigation tools are exposed over the Model Context Protocol:

```bash
go run ./cmd/investigator --mcp
```

Any MCP client can then call get_account_history, geo_lookup and
search_fraud_patterns against the running stack.

## Documentation

- docs/architecture.md, the system design and failure policy
- docs/adr, every significant decision with its tradeoffs
- docs/runbook.md, operating and debugging the local stack
- docs/diagrams, Excalidraw sources and SVG exports
