# Payment Processor

This repository is the Go course project for a payment processor with synchronous fraud checks and asynchronous investigation. The intended system has four independently deployed services in one monorepo. Its [project vision](docs/visao-do-projeto.md) describes the destination; the code and tests show what works in this checkout.

## Current state

| Status | What exists |
|---|---|
| Implemented | Generic, tested packages: [FSM](pkg/fsm/fsm.go) with transition traces and fallback; [batcher](pkg/batch/batch.go) with size/time flush and a bounded queue; [in-process cache](pkg/memcache/memcache.go) with TTL, shards and a janitor. |
| Partial | Fraud domain types and fast rules; SQL migration files and embedded schema; Protocol Buffer source contracts; Compose, monitoring and Kubernetes configuration. These pieces are not connected into a payment flow. |
| Planned | Working gateway, ledger, fraud and investigator services; HTTP/SSE and gRPC endpoints; database transactions, outbox relay, Kafka clients, model inference, MCP tools and end-to-end authorization. |

Each `cmd/*/main.go` currently prints a startup message and exits. In particular, the generic FSM is not a configured fraud pipeline, the batcher has no scorer consumer, and the cache is not yet used by the services. The console image is declared in Compose, but its backend capabilities depend on services that have not been built.

## Target architecture

The target services are **gateway** (HTTP edge and SSE), **ledger** (idempotency, double-entry accounting and outbox), **fraud** (low-latency scoring) and **investigator** (asynchronous manual-review investigation). The design uses gRPC internally, PostgreSQL with pgvector for data, Kafka for events, and Prometheus and Grafana for monitoring. Kubernetes and GKE are deployment targets. See the [technical architecture](docs/architecture.md) and [ADRs](docs/adr/0001-monorepo-with-independent-deployments.md) for decisions and trade-offs.

## Local development

Run Go commands inside the project's Dev Container; no Go installation on the host is needed:

```bash
go build ./...
go vet ./...
go test ./...
```

From outside the Dev Container, the same checks can run in its Docker Compose service:

```bash
docker compose -f .devcontainer/docker-compose.yml run --rm --no-deps --user vscode app sh -lc 'go build ./... && go vet ./... && go test ./...'
```

The documentation has its own Docker service:

```bash
make docs-build
make docs-serve
```

`make up` starts the Compose stack, including infrastructure and the current Go stubs. It does **not** provide a working payment API yet. Demo requests, integration tests and the MCP session described in the [runbook](docs/runbook.md) depend on later service implementation.

## Documentation

- [Project vision](docs/visao-do-projeto.md) — purpose and destination.
- [Architecture](docs/architecture.md) — target technical design and current implementation status.
- [ADRs](docs/adr/0001-monorepo-with-independent-deployments.md) — decisions and trade-offs.
- [Runbook](docs/runbook.md) — commands available now and procedures for later stages.
- [Go study material](docs/estudo-go/index.md) and [teacher references](docs/estudo-go/referencias-do-professor.md) — progressive learning and complementary articles.
