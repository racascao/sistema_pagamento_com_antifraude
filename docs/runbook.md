# Runbook

Operational commands and checks for the local stack.

> [!NOTE]
> Estes comandos e verificações de fumaça (*smoke checks*) são aplicáveis **após** a implementação dos serviços Go (Módulo 2 em diante). Ao clonar o repositório inicial limpo (*scratch*), os contêineres Go (`gateway`, `ledger`, `fraud`, `investigator`) irão compilar, iniciar e encerrar imediatamente, restando ativos apenas os serviços de infraestrutura (Postgres, Redpanda, Grafana, Console).

## Start and stop

```bash
make up      # build and start everything
make ps      # container status
make logs    # follow logs
make down    # stop and remove volumes
```

## Smoke checks

```bash
curl -s http://localhost:8080/healthz
make demo-approved
make demo-denied
make demo-review
make demo-reviews    # review queue as JSON
make demo-feed       # global SSE feed, fire a payment in another shell
```

## Console

The operator console runs at http://localhost:3001. It fires test
payments (three presets), shows the live decision feed over SSE, the
review queue and the agent investigation per case. Open a case to
apply the human decision: Approve charges the processor and writes
the double entry records, Deny closes the case without moving money.
If a panel shows "Waiting for backend", the capability it needs is
not running yet.

```bash
# decide from the command line instead of the console
curl -X POST http://localhost:8080/v1/reviews/<payment_id>/decision \
  -H 'Content-Type: application/json' \
  -d '{"decision":"approved","operator":"cli"}'
```

## Monitoring

```bash
make dashboards
# business:   http://localhost:3000/d/payment-processor
# technical:  http://localhost:3000/d/payment-processor-tech
# prometheus: http://localhost:9090/targets
```

The business dashboard answers what the system decided: approval
rate, money volume, decisions, review queue, risk score
distribution, decision reasons and investigations. The technical
dashboard answers how the system runs: HTTP routes and status codes,
gRPC methods and codes, CPU, memory, goroutines, GC pauses and
Postgres pool usage per service.

All four scrape targets must be up in Prometheus. The Grafana
dashboard is provisioned from the repository, edits belong in
deploy/monitoring/grafana/dashboards, not in the UI.

A manual review response returns a payment_id. Watch the
investigation live:

```bash
make demo-stream PAYMENT_ID=<id from demo-review>
```

## Database inspection

```bash
docker compose exec postgres psql -U postgres -d payments

-- recent payments and their decisions
SELECT id, status, risk_score, reasons FROM payments ORDER BY created_at DESC LIMIT 10;

-- double entry check: every payment must balance to zero
SELECT payment_id,
       SUM(CASE direction WHEN 'debit' THEN amount_cents ELSE -amount_cents END) AS balance
FROM ledger_entries GROUP BY payment_id HAVING
       SUM(CASE direction WHEN 'debit' THEN amount_cents ELSE -amount_cents END) <> 0;

-- unpublished outbox rows, should stay near zero
SELECT count(*) FROM outbox WHERE published_at IS NULL;

-- reviews and their state
SELECT payment_id, status, left(report, 80) FROM reviews ORDER BY created_at DESC LIMIT 10;
```

## Kafka inspection

```bash
docker compose exec redpanda rpk topic list
docker compose exec redpanda rpk topic consume payments.events -n 5
docker compose exec redpanda rpk topic consume reviews.events -n 5
```

## Common symptoms

| Symptom | Likely cause | Check |
|---|---|---|
| every payment goes to manual_review with degraded=true | fraud service down or slow | docker compose logs fraud |
| outbox count grows | redpanda unreachable from ledger | rpk cluster health |
| reviews stuck in pending | investigator not consuming | docker compose logs investigator |
| SSE stream silent | no events for that payment id yet | rpk topic consume reviews.events |
| 429 responses | rate limiter, 50 req/s per client IP | expected under load from one IP |

## MCP session against the investigation tools

The investigator binary doubles as an MCP server:

```bash
DATABASE_URL=postgres://postgres:postgres@localhost:5432/payments?sslmode=disable \
LEDGER_GRPC_ADDR=localhost:9001 \
go run ./cmd/investigator --mcp
```

Register it in any MCP client to call get_account_history, geo_lookup
and search_fraud_patterns interactively.
