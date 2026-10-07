# Roadmap do material

“Completo” aqui significa capítulo com problema real, análise de código, trade-offs, exercícios e checkpoint. “Introdução” indica apenas objetivos e fontes de estudo; não substitui o capítulo futuro.

| Módulo | Estado | Pré-requisito | Código para acompanhar |
|---|---|---|---|
| [Fundamentos](01-fundamentos/index.md) | Completo nesta etapa | Nenhum | `cmd/`, `pkg/fsm`, `pkg/memcache`, `migrations` |
| [Modelagem](02-modelagem/index.md) | Introdução | Fundamentos | Migrações e tipos futuros de domínio |
| [Interfaces](03-interfaces/index.md) | Semântica de Go completa; portas de serviço planejadas | Fundamentos | `error`, `context.Context`, métodos de `pkg/fsm` |
| [Erros](04-erros/index.md) | Modelo e fallback completos; tradução de transporte planejada | Interfaces | `pkg/fsm` e seus testes |
| [Generics](05-generics/index.md) | Estudo da FSM completo; outros mecanismos futuros | Interfaces | FSM e cache parcial |
| [Concorrência](06-concorrencia/index.md) | Introdução | Fundamentos | Cache e futuro batcher |
| [Context](07-context/index.md) | Introdução | Erros, concorrência | FSM; chamada distribuída futura |
| [Testes](08-testes/index.md) | Laboratório da FSM completo; benchmarks futuros | Fundamentos, erros, generics | Testes da FSM |
| [Protobuf e gRPC](09-protobuf-grpc/index.md) | Introdução | Interfaces, context | Contratos sem RPCs |
| [HTTP e SSE](10-http-sse/index.md) | Introdução | Context, gRPC | Gateway ainda mínimo |
| [FSM](11-fsm/index.md) | Introdução | Generics, erros | Motor em `pkg/fsm` |
| [Cache](12-cache/index.md) | Introdução | Generics, concorrência | `pkg/memcache` parcial |
| [Postgres e Outbox](13-postgres-outbox/index.md) | Introdução | Modelagem, erros | Migrações SQL |
| [Kafka](14-kafka/index.md) | Introdução | Outbox, concorrência | Configuração Redpanda; cliente futuro |
| [Observabilidade](15-observabilidade/index.md) | Introdução | HTTP, gRPC | Configuração Prometheus/Grafana |
| [MCP](16-mcp/index.md) | Introdução | HTTP/JSON, interfaces | `pkg/mcp` vazio |
| [Performance](17-performance/index.md) | Introdução | Testes, concorrência | Sem benchmarks Go ainda |
| [Go moderno](18-go-moderno/index.md) | Tabela de versões dos temas atuais; restante planejado | Fundamentos, generics | `go.mod`, toolchains dos containers |

Próximo bloco editorial recomendado: implementar as portas e adapters dos serviços antes de escrever estudos de caso sobre Clean Architecture e tradução HTTP/gRPC. O motor da FSM já oferece material de linguagem; sua topologia específica de fraude dependerá de um consumidor real.
