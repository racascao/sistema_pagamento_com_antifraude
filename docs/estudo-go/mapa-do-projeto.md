# Mapa do projeto

Este mapa foi conferido no código atual. A [Arquitetura](../architecture.md) descreve o destino do curso; a coluna “agora” descreve o checkout.

| Área | Agora | Fonte | Próximo estudo |
|---|---|---|---|
| `cmd/gateway`, `cmd/ledger`, `cmd/fraud`, `cmd/investigator` | Cada `main` imprime uma mensagem e termina; não há servidores | `cmd/*/main.go` | [Fundamentos](01-fundamentos/index.md) |
| `pkg/fsm` | Motor genérico com handlers, limite de hops, trace e fallback; testes black-box | `pkg/fsm/fsm.go`, `fsm_test.go` | [Interfaces](03-interfaces/interfaces-na-fsm.md), [Generics](05-generics/machine-generica.md), [Erros](04-erros/fsm-erros.md), [Testes](08-testes/testando-fsm.md), [FSM](11-fsm/index.md) |
| `pkg/memcache` | Cache genérico com 16 shards, hash FNV, `RWMutex`, TTL, janitor, `Close`, leitura, escrita e incremento; testes black-box incluindo concorrência | `pkg/memcache/memcache.go`, `memcache_test.go` | [Concorrência](06-concorrencia/index.md), [Cache](12-cache/index.md), [Generics](05-generics/index.md) |
| `pkg/batch`, `pkg/mcp` | Apenas declaração de package | `pkg/batch/batch.go`, `pkg/mcp/mcp.go` | [Concorrência](06-concorrencia/index.md), [MCP](16-mcp/index.md) |
| Contratos | `FraudService` e `LedgerService` declarados sem RPCs | `proto/fraud/v1/fraud.proto`, `proto/ledger/v1/ledger.proto` | [Protobuf e gRPC](09-protobuf-grpc/index.md) |
| Banco | Sete migrações SQL e `embed.FS`; não há repositório Go nem relay | `migrations/` | [Postgres e Outbox](13-postgres-outbox/index.md) |
| Infraestrutura | Compose, imagens, monitoramento e manifests versionados; isso não implica endpoints ativos | `docker-compose.yml`, `deploy/` | [Observabilidade](15-observabilidade/index.md) |

## Fluxos descritos, ainda sem código Go correspondente

Os documentos projetam `gateway → ledger → fraud`, investigação assíncrona via Kafka, SSE e MCP. No checkout atual, não existem implementações Go para HTTP, gRPC, consumer Kafka, EventHub, inferência de modelo, métricas ou portas `domain/usecase/infra/adapter`. Não há benchmarks Go. O teste de carga em `test/load/payment-flow.js` pressupõe a API futura.

## Divergências úteis para estudar

- O README pede Go 1.24+, mas `go.mod` declara `go 1.26.4`; o Docker de serviços usa `golang:1.26-alpine`.
- [ADR 0002](../adr/0002-postgres-as-the-single-database.md) fala em índice `ivfflat`, mas a migração atual cria `hnsw` em `fraud_patterns.embedding`.
- [Arquitetura](../architecture.md) atribui métricas, scoring, gRPC e SSE aos serviços; seus `main.go` atuais ainda não os iniciam.
- [ADR 0005](../adr/0005-fsm-with-deterministic-fallback.md) descreve estados do pipeline de fraude; `pkg/fsm` é apenas o motor compartilhado, sem pipeline `fraud` configurado.

Use [Do conceito ao código](conceito-para-codigo.md) para confirmar o estado de qualquer outra afirmação.

## Relações de estudo

```text
pkg/fsm/fsm.go
  → generics, interfaces, erros e testes

pkg/memcache/memcache.go
  → structs, maps, métodos, RWMutex, sharding, TTL e concorrência
```
