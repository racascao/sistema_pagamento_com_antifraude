# Architecture

The system authorizes card payments with a fraud decision inside the
synchronous path and an autonomous investigation outside it.

Diagrams live in docs/diagrams as Excalidraw files. Open them at
https://excalidraw.com or with the VS Code Excalidraw extension.

## Services

| Service | Role | Transport |
|---|---|---|
| gateway | Public HTTP edge, rate limiting, SSE streaming | HTTP in, gRPC out |
| ledger | Money movement, idempotency, double entry, outbox | gRPC |
| fraud | Scoring pipeline: rules, tree model, semantic tiebreak | gRPC |
| investigator | Async investigation of manual review cases | Kafka in, MCP tools |

## Synchronous authorization path

1. Client sends POST /v1/payments with an Idempotency-Key header.
2. Gateway rate limits by client IP and forwards to ledger.Authorize.
3. Ledger replays stored responses for known idempotency keys.
4. Ledger calls fraud.Score with a 100 millisecond budget.
5. Fraud runs the FSM: enrich, fast rules, ml score, tiebreak.
6. Approved charges call the payment processor, then everything is
   committed in one transaction: payment, ledger entries, review row
   when applicable, outbox event, idempotency record.
7. If fraud does not answer inside the budget, the charge routes to
   manual review flagged as degraded. Authorization never blocks on
   the model.

## Asynchronous investigation path

1. The outbox relay publishes payment events to Kafka.
2. The investigator consumes manual review events.
3. The advisor investigates using three tools: account history from
   the ledger, geo lookup, similarity search over historical fraud
   patterns in pgvector.
4. With ANTHROPIC_API_KEY set, a Claude agent loop chooses the tools.
   Without it, a deterministic rule based advisor runs the same tools
   in fixed order.
5. Progress steps stream through Kafka to the gateway, which serves
   them to operators over SSE at /v1/reviews/{payment_id}/stream.
6. The review row is resolved with the report and recommendation.
   Slack and email notifications fire when configured.
7. A human closes the case through POST /v1/reviews/{id}/decision.
   Approval charges the processor and writes the double entry
   records inside one transaction, denial just closes. The decision
   emits both a payment event and a review event through the outbox,
   and the agreement between decision and recommendation is measured
   as ledger_review_decisions_total.

## Data

Single Postgres instance. Money uses double entry accounting: every
approved payment writes a debit and a credit that must sum to zero,
enforced twice, in domain code and by a deferred database trigger.

Fraud patterns are embedded into 256 dimension vectors stored in a
pgvector column with an ivfflat cosine index.

## Latency design

Three mechanisms keep the hot path flat:

1. Native tree inference, around 8 nanoseconds per score with zero
   allocations, measured by BenchmarkScore.
2. Dynamic batching in front of the scorer, grouping concurrent
   requests in 5 millisecond windows of up to 32 items.
3. In process caches for velocity counting and semantic tiebreaks,
   no network round trip on the hot path.

## Console facing API

The gateway serves the operator console:

| Endpoint | Purpose |
|---|---|
| POST /v1/payments | payment intake, Idempotency-Key required |
| GET /v1/payments/recent | live feed backfill on console load |
| GET /v1/reviews | review queue, optional status filter |
| POST /v1/reviews/{id}/decision | human decision, closes the case |
| GET /v1/reviews/{id}/stream | SSE, one investigation live |
| GET /v1/events/stream | SSE, every payment and review event |
| GET /metrics | Prometheus exposition |

Read models come from the ledger over gRPC. Live events come from
the EventHub, an in process fan out that consumes the payments and
reviews topics once per gateway replica. The browser never talks to
Kafka or the database. See docs/adr/0009.

## Monitoring

Every service exposes /metrics: the gateway on its HTTP port, the
gRPC services on dedicated listeners (ledger 9101, fraud 9102,
investigator 9103). Prometheus scrapes all four and Grafana ships
one provisioned dashboard versioned at
deploy/monitoring/grafana/dashboards.

Signals worth knowing: gateway_http_request_duration_seconds (edge
latency), fraud_stage_duration_seconds (FSM stage cost),
fraud_verdicts_total{degraded="true"} (fallback activity),
ledger_decisions_total (business outcomes), ledger_outbox_unpublished
(Kafka health) and investigator_recommendations_total.

The same monitoring manifests run on compose, kind and GKE. In the
cloud, Managed Service for Prometheus is enabled at the cluster
level by Terraform, see docs/adr/0010.

## Failure policy

Every dependency has a declared behavior when it fails:

| Dependency | Failure behavior |
|---|---|
| fraud service | ledger routes to manual review, degraded flag set |
| tree model | FSM falls back to finalize, manual review |
| geo provider | scoring continues without the country signal |
| payment processor | error returned, nothing persisted, safe retry |
| kafka | outbox rows accumulate, relay drains after recovery |
| llm advisor | rule based advisor is the no key default |
