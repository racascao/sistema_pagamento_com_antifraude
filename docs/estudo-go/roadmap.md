# Roadmap do material

“Completo” aqui significa capítulo com problema real, análise de código, trade-offs, exercícios e checkpoint. “Introdução” indica apenas objetivos e fontes de estudo; não substitui o capítulo futuro.

| Módulo | Estado | Pré-requisito | Código para acompanhar |
|---|---|---|---|
| [Fundamentos](01-fundamentos/index.md) | Completo nesta etapa | Nenhum | `cmd/`, `pkg/fsm`, `pkg/batch`, `pkg/memcache`, `migrations` |
| [Modelagem](02-modelagem/index.md) | Introdução | Fundamentos | Migrações e tipos futuros de domínio |
| [Interfaces](03-interfaces/index.md) | Semântica de Go completa; portas de serviço planejadas | Fundamentos | `error`, `context.Context`, métodos de `pkg/fsm` |
| [Erros](04-erros/index.md) | Modelo e fallback completos; tradução de transporte planejada | Interfaces | `pkg/fsm` e seus testes |
| [Generics](05-generics/index.md) | FSM, batcher e cache como mecanismos genéricos | Interfaces | `pkg/fsm`, `pkg/batch`, `pkg/memcache` |
| [Concorrência](06-concorrencia/index.md) | Parcial: locks, channels de sinalização e de dados, `select`, timer, `WaitGroup`, lifecycle e race detector; pipelines avançados pendentes | Fundamentos | `pkg/memcache`, `pkg/batch` |
| [Context](07-context/index.md) | Parcial: cancelamento local no FSM e batcher; propagação distribuída futura | Erros, concorrência | `pkg/fsm`, `pkg/batch` |
| [Testes](08-testes/index.md) | FSM, cache e batcher; benchmarks futuros | Fundamentos, erros, generics | Testes dos três packages |
| [Protobuf e gRPC](09-protobuf-grpc/index.md) | Introdução | Interfaces, context | Contratos sem RPCs |
| [HTTP e SSE](10-http-sse/index.md) | Introdução | Context, gRPC | Gateway ainda mínimo |
| [FSM](11-fsm/index.md) | Estudo integrado de mecanismo, trace e fallback | Generics, erros, testes | Motor em `pkg/fsm` |
| [Cache](12-cache/index.md) | Laboratório funcional de TTL, janitor e sharding | Generics, concorrência | `pkg/memcache` |
| [Postgres e Outbox](13-postgres-outbox/index.md) | Introdução | Modelagem, erros | Migrações SQL |
| [Kafka](14-kafka/index.md) | Introdução | Outbox, concorrência | Configuração Redpanda; cliente futuro |
| [Observabilidade](15-observabilidade/index.md) | Introdução | HTTP, gRPC | Configuração Prometheus/Grafana |
| [MCP](16-mcp/index.md) | Introdução | HTTP/JSON, interfaces | `pkg/mcp` vazio |
| [Performance](17-performance/index.md) | Hipóteses reais de batching/cache; benchmarks pendentes | Testes, concorrência | `pkg/batch`, `pkg/memcache` |
| [Go moderno](18-go-moderno/index.md) | Tabela de versões dos temas atuais; restante planejado | Fundamentos, generics | `go.mod`, toolchains dos containers |

Próximo bloco editorial recomendado: implementar as portas e adapters dos serviços antes de escrever estudos de caso sobre Clean Architecture e tradução HTTP/gRPC. O motor da FSM já oferece material de linguagem; sua topologia específica de fraude dependerá de um consumidor real.
