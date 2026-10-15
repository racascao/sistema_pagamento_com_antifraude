# Padrões no payment-processor

## Antes de falar em patterns

Nem todo recurso reutilizável é GoF, nem toda solução arquitetural é recurso de Go, e nem toda otimização é arquitetura. A classificação abaixo descreve o código que existe hoje; ADRs e a [Arquitetura](../architecture.md) descrevem também usos futuros desses mecanismos.

| Componente | Problema | Solução no código | Classificação |
|---|---|---|---|
| `pkg/fsm` | fluxo com estados, transições e fallback | máquina explícita com handlers e trace | modelo de máquina de estados; padrão comportamental de engenharia |
| `pkg/batch` | agrupar pedidos individuais por tamanho ou tempo | coletor com fila limitada e flush | batching/micro-batching, agregação e producer-consumer |
| `pkg/memcache` | estado local rápido com expiração e contenção | cache TTL em shards com locks locais | in-process TTL cache, sharding, lock striping e janitor |

## Linguagem, biblioteca, design e arquitetura

| Categoria | Exemplos reais |
|---|---|
| Linguagem Go | `struct`, métodos, type parameters, `map`, ponteiros, channels e `select` |
| Biblioteca padrão | `context`, `errors`, `sync.RWMutex`, `sync.Once`, `sync.WaitGroup`, `time.Timer` e `time.Ticker` |
| Design/engenharia | FSM, batching, TTL cache, lock striping e limpeza em background |
| Arquitetura | Clean Architecture, Outbox e transportes entre serviços — ainda não implementados pelos packages compartilhados |
| Técnica de performance | batching para amortizar custo fixo, cache local para evitar hop de rede e shards para reduzir contenção |

As técnicas podem melhorar desempenho, mas não provam ganho sem benchmark. Os packages `pkg/` são mecanismos reutilizáveis; eles não são, sozinhos, a arquitetura dos serviços.

## Estudos de caso

- [FSM](11-fsm/index.md): estados nomeados, transições e fallback.
- [Batcher](06-concorrencia/batcher.md): tamanho ou janela de tempo para liberar trabalho.
- [Cache](12-cache/index.md): TTL, shards, locks e janitor.

## Relação entre os três mecanismos

| Componente | Pergunta que responde |
|---|---|
| FSM | Qual etapa vem agora? |
| Batcher | Quando e com quantos itens processar? |
| Cache | Posso reutilizar este valor localmente? |

Eles são complementares. Uma configuração de domínio futura pode combinar os três, mas não há consumidor de produção que os conecte neste checkout.

## Policy e mechanism

`Machine[Data]` é o mecanismo de executar transições; a topologia concreta de scoring é política de domínio. `Batcher[In, Out]` agrupa pedidos; `Flusher` define o trabalho de cada lote. `Cache[Value]` armazena valores; o consumidor decide o que guardar e quando consultar. Essa separação explica por que os três tipos usam generics sem conhecer pagamentos.

## Checklist

- [ ] Sei diferenciar recurso da linguagem de pattern.
- [ ] Sei explicar por que FSM não significa automaticamente GoF State.
- [ ] Sei explicar batching como agregação temporal/de tamanho.
- [ ] Sei diferenciar sharding de lock striping.
- [ ] Sei explicar por que um cache não é automaticamente Cache-Aside.
- [ ] Sei identificar o trade-off throughput × latency no batcher.
- [ ] Sei dizer quais classificações são comprovadas pelo código atual.
