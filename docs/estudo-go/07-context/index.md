# Context

**Estado:** Planejado. Veja o [roadmap](../roadmap.md) para a sequência e os pré-requisitos.

## Onde isso aparece no projeto

`Machine.Run` verifica `ctx.Err()` no início de cada hop e passa `ctx` ao handler. A propagação gateway → ledger → fraud ainda não existe em Go.

`Context` será aprofundado quando existir uma cadeia real de operações canceláveis entre serviços. O cache não o utiliza e não será usado artificialmente como exemplo deste módulo.

Fontes: `pkg/fsm/fsm.go`, `pkg/fsm/fsm_test.go`; [arquitetura](../../architecture.md) para fluxo planejado.

## O que você vai aprender

Explicar cancelamento local, deadline e causa; distinguir o objeto Context de sinais propagados por gRPC.

## Checkpoint desta etapa

- [ ] Consigo localizar as fontes mencionadas no checkout.
- [ ] Sei separar o comportamento implementado da intenção descrita nos ADRs.
- [ ] Sei qual conceito precisa estar claro antes do capítulo completo.

[Voltar ao mapa do projeto](../mapa-do-projeto.md).
