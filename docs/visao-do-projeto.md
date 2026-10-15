# Visão do projeto

!!! info "Visão do curso e do projeto"
    Esta página descreve a visão arquitetural e pedagógica do `payment-processor`: o sistema que o curso pretende construir e os princípios que orientam sua evolução.

    Ela não comprova, por si só, que uma capacidade já esteja implementada. Para verificar o estado atual, consulte o código, os testes e o [roadmap do material](estudo-go/roadmap.md).

## Por que este projeto existe

Aprender a sintaxe de Go é apenas o começo. O desafio é aplicar a linguagem a concorrência, comunicação entre serviços, consistência transacional, tolerância a falhas, observabilidade, testes e requisitos de latência.

O `payment-processor` é o laboratório desse percurso. Em vez de um CRUD isolado, o curso evolui um processador de pagamentos composto por quatro serviços:

- **gateway**: borda HTTP, rate limiting, SSE e comunicação com serviços internos;
- **ledger**: autorização financeira, idempotência, movimentação de valores, dupla entrada e outbox;
- **fraud**: decisão antifraude no caminho síncrono;
- **investigator**: investigação assíncrona dos casos em revisão manual.

Os serviços são unidades independentes de execução e deploy, mas compartilham o monorepo para manter contratos, decisões e material didático próximos. O desenho técnico detalhado está em [Arquitetura](architecture.md); esta página explica o propósito e a direção.

## Arquitetura-alvo

A arquitetura-alvo usa Protocol Buffers e **gRPC** entre serviços, HTTP e **Server-Sent Events (SSE)** na borda, e Kafka para comunicação assíncrona. PostgreSQL é a fonte principal para dados transacionais; `pgvector` pode apoiar busca vetorial nos casos de fraude quando esse fluxo estiver implementado.

Movimentações aprovadas seguem contabilidade de dupla entrada: cada operação deve produzir lançamentos balanceados. A publicação de eventos usa o **Transactional Outbox Pattern**, para que a alteração de estado e a intenção de publicar participem da mesma transação local. Os ADRs descrevem as decisões e os trade-offs dessa direção, sem substituir o comportamento compilado.

## O caminho crítico da autorização

Uma autorização não deve esperar indefinidamente por modelo, integração externa ou decisão de IA. A direção do fluxo síncrono é:

```text
cliente → gateway → ledger → fraud → decisão
                 HTTP     gRPC      gRPC
```

Quando implementadas, as dependências terão orçamento de tempo, política de falha e fallback definidos. Se uma decisão automática não puder ser obtida com segurança no orçamento, o caso deverá seguir para revisão manual com degradação explícita e observável. A [Arquitetura](architecture.md) detalha a política planejada; o código e os testes dizem quais partes já existem.

## O motor de fraude

O serviço `fraud` é um laboratório para mecanismos de baixa latência executados em Go. Os packages compartilhados existentes fornecem mecanismos genéricos; a configuração concreta do pipeline antifraude continua sendo política de domínio a implementar.

### Inferência nativa

O curso prevê carregar e executar a árvore de decisão no próprio processo Go, evitando uma chamada de rede para um runtime separado. Isso permite estudar representação de modelos, hot paths, alocações, benchmarks, latência e trade-offs operacionais. Resultados de desempenho só devem ser afirmados quando houver benchmark reproduzível.

### Finite State Machine

[`pkg/fsm`](estudo-go/11-fsm/index.md) contém uma máquina de estados genérica com handlers, transições, trace e fallback. Ela é o **mecanismo**; definir estados do scoring e suas regras é a **política** de uma futura pipeline de fraude. A máquina não configura sozinha esse pipeline.

### Dynamic batching

[`pkg/batch`](estudo-go/06-concorrencia/batcher.md) implementa batching por tamanho ou janela de tempo. O `Batcher[In, Out]` é o mecanismo de agrupamento; o `Flusher` e o consumidor que decidirá o que processar em lote são política. Ele permite estudar goroutines, channels, timer, agregação, lifecycle e backpressure, além do trade-off entre throughput e latência. Não há consumidor de produção do batcher neste checkout.

### Cache em memória

[`pkg/memcache`](estudo-go/12-cache/index.md) implementa cache local genérico com TTL, shards, lock striping e janitor. O cache é o mecanismo; a escolha de dados, a fonte de verdade e a política de invalidação pertencem ao consumidor. O componente atual não prova uma integração Cache-Aside nem cache distribuído.

## Investigação assíncrona

Casos que exigem análise adicional devem sair do caminho síncrono. A arquitetura-alvo é:

```text
ledger → outbox → Kafka → investigator
```

O `investigator` deverá combinar dados históricos, ferramentas de consulta e busca por similaridade. O curso também prevê ferramentas expostas por **Model Context Protocol (MCP)**, implementado sobre os mecanismos fundamentais do protocolo para fins didáticos. Uma integração com modelo de linguagem será opcional; sem ela, o fluxo precisa preservar um caminho determinístico.

## Engenharia antes de abstração

Abstrações devem nascer de necessidades reais, não apenas da possibilidade de criá-las. Generics, interfaces e packages compartilhados só entram quando há uma relação genuinamente reutilizável.

```text
Machine[Data]    → mecanismo genérico de FSM
Batcher[In, Out] → mecanismo genérico de agrupamento
Cache[Value]     → mecanismo de armazenamento temporário
```

Regras específicas de pagamentos e fraude permanecem no domínio que as conhece. Essa separação entre **mechanism** e **policy** evita que packages compartilhados dependam do domínio de pagamentos. Veja também [Padrões no projeto](estudo-go/padroes-no-projeto.md).

## Clean Architecture

Cada serviço deverá manter as regras de domínio independentes de escolhas de transporte e infraestrutura:

```text
adapter → usecase → domain
infra   → implementa portas dos casos de uso
```

O objetivo não é reproduzir diagramas por formalidade. A separação protege regras de domínio de detalhes como PostgreSQL, Kafka, gRPC e provedores externos. A estrutura completa por serviço só deve ser considerada existente quando código e testes a confirmarem.

## Consistência e eventos

Persistir um pagamento e publicar um evento em sistemas distintos cria uma janela de falha. A direção adotada pelo projeto é registrar pagamento, lançamentos, revisão quando necessária e evento de outbox na mesma transação PostgreSQL; um relay publica depois no Kafka.

Consumidores devem tolerar entrega *at least once* e possíveis duplicatas. Consulte o [ADR de Outbox](adr/0006-outbox-for-event-publishing.md) para as consequências dessa escolha.

## Observabilidade

O sistema-alvo prevê métricas técnicas e de negócio, Prometheus para coleta, Grafana para visualização, traces onde ajudam a investigar mecanismos e benchmarks para decisões do caminho crítico. O console operacional mostra workflow; as ferramentas de monitoramento mostram comportamento agregado e saúde. Esses são objetivos arquiteturais: a disponibilidade de cada sinal deve ser confirmada no código e no ambiente em execução.

## Decisões arquiteturais explícitas

Os [ADRs](adr/0001-monorepo-with-independent-deployments.md) registram problema, restrições, decisão, razão e consequências. A visão diz **onde** o projeto pretende chegar; os ADRs explicam **por que** decisões específicas foram tomadas; [Arquitetura](architecture.md) descreve o desenho técnico. Não são substitutos entre si.

## Do desenvolvimento local à produção

O curso parte de um módulo Go e evolui progressivamente para serviços, containers, observabilidade, Kubernetes e GKE/GCP:

```text
go.mod → packages → serviços → containers → observabilidade → Kubernetes → GKE
```

Cada camada deve acrescentar uma necessidade verificável ao sistema, não apenas uma nova ferramenta. O [Runbook](runbook.md) é a referência operacional para o que puder ser executado localmente.

## O que este curso ensina

O projeto aprofunda Go moderno, ponteiros, métodos, interfaces, errors, generics, goroutines, channels, `select`, `sync`, `context`, testes table-driven, race detector, benchmarks e profiling. A evolução arquitetural cobre também gRPC, HTTP/SSE, PostgreSQL e transações, idempotência, dupla entrada, Outbox, Kafka, cache, FSM, dynamic batching, inferência nativa, MCP, agentes de IA, observabilidade, containers, Kubernetes, GCP e análise de trade-offs.

Os módulos já estudados e os ainda planejados aparecem no [roadmap](estudo-go/roadmap.md).

## Pré-requisitos

O curso pressupõe Go básico: reconhecer `func`, `struct`, `if`, `for` e `package`. Concorrência, generics, gRPC, sistemas distribuídos e Kubernetes são desenvolvidos progressivamente com o projeto.

## Para quem é este material

Este material é destinado a quem já conhece a sintaxe básica de Go e quer avançar para sistemas reais. A meta é saber responder perguntas como: por que uma interface existe, onde um lock é necessário, por que usar uma FSM, como reagir à indisponibilidade do Kafka, onde colocar um timeout, se um generic é necessário e se um ganho de performance foi medido.

## Como esta página deve ser usada

Esta é a visão canônica do projeto e do curso. Ela orienta direção arquitetural, módulos futuros, exemplos didáticos e próximos prompts, mas descreve também arquitetura-alvo.

> Visão não é sinônimo de implementação atual.

Antes de afirmar que uma capacidade existe, consulte código e testes. Nenhum prompt futuro deve concluir que uma funcionalidade está implementada apenas porque aparece nesta página.

## Fontes de verdade do projeto

| Pergunta | Fonte principal |
|---|---|
| O que já está implementado? | código e testes |
| Quais regras de desenvolvimento devem ser seguidas? | `AGENTS.md` |
| Como o sistema está organizado? | [Arquitetura](architecture.md) |
| Por que uma decisão foi tomada? | [ADRs](adr/0001-monorepo-with-independent-deployments.md) |
| Qual é a visão e o destino? | esta página |
| O que já foi estudado? | [Roadmap](estudo-go/roadmap.md) |
| Como operar o sistema? | [Runbook](runbook.md) |

## Ciclo de evolução

```text
visão
  ↓
inspecionar estado atual
  ↓
consultar ADRs
  ↓
projetar próxima evolução
  ↓
implementar
  ↓
testar
  ↓
atualizar documentação
```

Esse ciclo orienta a evolução do `payment-processor`.
