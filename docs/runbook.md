# Runbook

This runbook separates commands available in the current checkout from procedures for the [target architecture](architecture.md). The four Go entry points still print startup messages and exit. There is no payment API, fraud gRPC server, outbox relay, Kafka client or MCP session to operate yet.

## Available now: Go packages and documentation

Run Go checks inside the Dev Container:

```bash
go build ./...
go vet ./...
go test ./...
```

From the host, use the Dev Container service to run the same commands without installing Go locally:

```bash
docker compose -f .devcontainer/docker-compose.yml run --rm --no-deps --user vscode app sh -lc 'go build ./... && go vet ./... && go test ./...'
```

The MkDocs site can be built or served independently of the payment stack:

```bash
make docs-build
make docs-serve
```

`make docs-build` uses `mkdocs build --strict`. Open the served site at <http://localhost:8000>.

## Available now: infrastructure and stubs

These targets exist in the Makefile:

```bash
make up    # builds and starts the Compose services
make ps    # shows container status
make logs  # follows container logs
make down  # stops the stack and removes its named volumes
```

`make up` can start PostgreSQL, Redpanda, Grafana, Prometheus and the declared console image, but the Go service binaries exit after printing a message. A running container or dashboard does not establish a working payment flow. `make down` invokes `docker compose down -v` and removes the local PostgreSQL volume.

After bringing up infrastructure, these commands inspect only the available infrastructure:

```bash
docker compose exec postgres psql -U postgres -d payments
docker compose exec redpanda rpk topic list
make dashboards  # prints Grafana and Prometheus URLs
```

The SQL migration files are embedded in the Go package, but no service or migration runner applies them automatically in this checkout. A successful database connection therefore does not imply that `payments`, `ledger_entries`, `outbox` or `reviews` tables exist. Prometheus has scrape targets configured, but the Go stubs do not expose application metrics.

## Planned: payment smoke checks and console workflow

The following commands and endpoints depend on later gateway, ledger, fraud and investigator implementations. Make targets for some demo requests already exist, but they do not produce successful payment responses now:

```bash
curl -s http://localhost:8080/healthz
make demo-approved
make demo-denied
make demo-review
make demo-reviews
make demo-feed
make demo-stream PAYMENT_ID=<payment_id>
```

The declared console image targets <http://localhost:3001>. Its payment presets, live feed, review queue and human decision workflow require gateway endpoints and backing services. The intended manual decision request is:

```bash
curl -X POST http://localhost:8080/v1/reviews/<payment_id>/decision \
  -H 'Content-Type: application/json' \
  -d '{"decision":"approved","operator":"cli"}'
```

These API requests are examples of the target interface, not current smoke tests.

## Planned: payment data and events

After a migration runner and transaction path exist, database inspection can use:

```sql
SELECT id, status, risk_score, reasons FROM payments ORDER BY created_at DESC LIMIT 10;

SELECT payment_id,
       SUM(CASE direction WHEN 'debit' THEN amount_cents ELSE -amount_cents END) AS balance
FROM ledger_entries GROUP BY payment_id HAVING
       SUM(CASE direction WHEN 'debit' THEN amount_cents ELSE -amount_cents END) <> 0;

SELECT count(*) FROM outbox WHERE published_at IS NULL;
SELECT payment_id, status, left(report, 80) FROM reviews ORDER BY created_at DESC LIMIT 10;
```

Once producers and the relay create the target topics, their messages can be inspected with:

```bash
docker compose exec redpanda rpk topic consume payments.events -n 5
docker compose exec redpanda rpk topic consume reviews.events -n 5
```

Until then, these topic and SQL checks may return “not found”; they are not evidence of a running application.

## Planned: monitoring and diagnosis

`make dashboards` prints local URLs. The target business dashboard covers approvals, decisions and investigations; the technical dashboard covers HTTP/gRPC latency, resources and pool usage. Those signals require service instrumentation. The intended endpoints include Grafana at <http://localhost:3000> and Prometheus targets at <http://localhost:9090/targets>.

The following symptom table is useful only after the related service paths exist:

| Symptom | Target behavior to investigate |
|---|---|
| Payments degrade to manual review | fraud service timeout or failure |
| Unpublished outbox rows grow | relay or Kafka unavailable |
| Reviews remain pending | investigator consumer not progressing |
| SSE stream is silent | no event for the case, or gateway fan-out unavailable |
| HTTP 429 responses | gateway rate limiter rejecting requests |

## Planned: MCP investigation session

The `--mcp` command is part of the target design. `cmd/investigator` does not parse the flag or start an MCP server yet; `pkg/mcp` is a placeholder.

```bash
DATABASE_URL=postgres://postgres:postgres@localhost:5432/payments?sslmode=disable \
LEDGER_GRPC_ADDR=localhost:9001 \
go run ./cmd/investigator --mcp
```

When implemented, the session is intended to expose `get_account_history`, `geo_lookup` and `search_fraud_patterns`. See [ADR 0007](adr/0007-mcp-from-scratch.md) for the decision to implement the protocol directly.
