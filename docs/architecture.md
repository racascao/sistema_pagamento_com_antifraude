# Architecture

This page describes the **target architecture** of the payment processor: fraud decisions in the synchronous authorization path and investigation outside it. The current implementation must be checked against code and tests; the status below summarizes this checkout. The [project vision](visao-do-projeto.md) explains the purpose of the course, while the [ADRs](adr/0001-monorepo-with-independent-deployments.md) record specific decisions and trade-offs.

## Current implementation status

| Capability | Status | Evidence and boundary |
|---|---|---|
| Generic FSM | Implemented | `pkg/fsm` supports handlers, traces, a hop limit and fallback; tests exercise the happy path and error/fallback behavior, but no fraud pipeline consumes it. |
| Generic batcher | Implemented | `pkg/batch` and tests cover size/time flush, cancellation and shutdown; no scorer consumes it. |
| In-process cache | Implemented | `pkg/memcache` and tests cover TTL, sharding, locks and janitor; no service consumes it. |
| Gateway, ledger, investigator | Planned | Their `cmd/*/main.go` files print a message and exit; transport and use-case implementations are absent. |
| Fraud service | Partial | Domain feature extraction and fast rules exist in `internal/fraud/domain`; no scoring server or integrated pipeline. |
| gRPC | Partial | `.proto` source contracts and module dependencies exist; no running client or server. |
| HTTP and SSE | Planned | No Go HTTP listener, route handler or SSE stream. |
| PostgreSQL and pgvector | Partial | SQL migrations and Compose configuration exist; no application persistence path or migration runner. |
| Outbox | Partial | Table migration exists; no transactional writer or relay. |
| Kafka | Partial | Redpanda and broker configuration exist; no Go producer or consumer. |
| Observability | Partial | Prometheus/Grafana configuration and dashboards exist; the Go stubs expose no metrics. |
| MCP | Planned | `pkg/mcp` contains only a package declaration. |
| Kubernetes and GCP | Partial | Manifests and Terraform files exist; an operational deployment of the planned services is not demonstrated. |

The target design below remains a design even where some of its building blocks are already present.

## Target services

| Service | Role | Transport |
|---|---|---|
| gateway | Public HTTP edge, rate limiting, SSE streaming | HTTP in, gRPC out |
| ledger | Money movement, idempotency, double entry, outbox | gRPC |
| fraud | Scoring pipeline: rules, tree model, semantic tiebreak | gRPC |
| investigator | Async investigation of manual review cases | Kafka in, MCP tools |

## Target synchronous authorization path

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

## Target asynchronous investigation path

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

The target uses one PostgreSQL instance. Each approved payment should write a debit and a credit that balance to zero, checked in domain code and by a deferred database trigger. The SQL migrations define tables and constraints, but no Go payment transaction uses them yet.

Fraud patterns are designed as 256-dimensional vectors in pgvector. [ADR 0002](adr/0002-postgres-as-the-single-database.md) describes an `ivfflat` cosine index; the current SQL migration `00005_create_fraud_patterns.sql` instead declares `hnsw`. This discrepancy is recorded here for a future decision review; neither index is exercised by an application flow in this checkout.

## Latency design

The target hot path combines three mechanisms:

1. Native tree inference in the fraud process. No scorer or `BenchmarkScore` exists in this checkout, so the latency and allocation figures in [ADR 0004](adr/0004-native-tree-inference-in-go.md) are not reproducible here.
2. Dynamic batching in front of the scorer, with the intended configuration of up to 32 items or a 5 millisecond window. The implemented generic batcher is not connected to a scorer or configured with these values by a service.
3. In-process velocity and semantic caches to avoid network calls in the hot path. The implemented generic cache is not connected to either use case.

## Console facing API

The target gateway serves the operator console through these endpoints; none is exposed by the current Go binary:

| Endpoint | Purpose |
|---|---|
| POST /v1/payments | payment intake, Idempotency-Key required |
| GET /v1/payments/recent | live feed backfill on console load |
| GET /v1/reviews | review queue, optional status filter |
| POST /v1/reviews/{id}/decision | human decision, closes the case |
| GET /v1/reviews/{id}/stream | SSE, one investigation live |
| GET /v1/events/stream | SSE, every payment and review event |
| GET /metrics | Prometheus exposition |

The planned read models come from the ledger over gRPC. The planned EventHub fans out Kafka payment and review events once per gateway replica; the browser talks to the gateway rather than Kafka or the database. See [ADR 0009](adr/0009-metrics-in-grafana-workflow-in-console.md).

## Monitoring

In the target system, every service exposes `/metrics`: the gateway on its HTTP port and the gRPC services on dedicated listeners (ledger 9101, fraud 9102, investigator 9103). Prometheus is configured to scrape all four; Grafana dashboards are versioned under `deploy/monitoring/grafana/dashboards`. Current service binaries do not expose these targets.

Signals worth knowing: gateway_http_request_duration_seconds (edge
latency), fraud_stage_duration_seconds (FSM stage cost),
fraud_verdicts_total{degraded="true"} (fallback activity),
ledger_decisions_total (business outcomes), ledger_outbox_unpublished
(Kafka health) and investigator_recommendations_total.

The monitoring design spans Compose, kind and GKE. Managed Service for Prometheus is part of the GCP target described in [ADR 0010](adr/0010-gcp-as-cloud-target.md); this checkout does not demonstrate a running cloud deployment.

## Failure policy

The intended failure policies are:

| Dependency | Failure behavior |
|---|---|
| fraud service | ledger routes to manual review, degraded flag set |
| tree model | FSM falls back to finalize, manual review |
| geo provider | scoring continues without the country signal |
| payment processor | error returned, nothing persisted, safe retry |
| kafka | outbox rows accumulate, relay drains after recovery |
| llm advisor | rule based advisor is the no key default |
