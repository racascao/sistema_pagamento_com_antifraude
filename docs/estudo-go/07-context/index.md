# Context

**Estado:** parcial. Há cancelamento local nos componentes genéricos; a propagação entre serviços continua planejada. Veja o [roadmap](../roadmap.md) para a sequência.

## Onde isso aparece no projeto

`Machine.Run` verifica `ctx.Err()` no início de cada hop e passa `ctx` ao handler. A propagação gateway → ledger → fraud ainda não existe em Go.

`Batcher.Submit` verifica `ctx.Err()` antes de enfileirar e seleciona entre a fila, `ctx.Done()` e a resposta; isso evita que um chamador fique preso quando sua espera expira. Depois de aceito, porém, o lote chama o flusher com `context.Background()`: o cancelamento daquele chamador não cancela o trabalho compartilhado. O cache não usa contexto.

`Context` será aprofundado quando existir uma cadeia real de operações canceláveis entre serviços. Não há propagação gRPC, deadline distribuído ou causa de cancelamento demonstrável neste checkout.

Fontes: `pkg/fsm/fsm.go`, `pkg/fsm/fsm_test.go`; [arquitetura](../../architecture.md) para fluxo planejado.

## O que você vai aprender

Explicar cancelamento local, deadline e causa; distinguir o objeto Context de sinais propagados por gRPC.

## Checkpoint desta etapa

- [ ] Consigo localizar as fontes mencionadas no checkout.
- [ ] Sei separar o comportamento implementado da intenção descrita nos ADRs.
- [ ] Sei qual conceito precisa estar claro antes do capítulo completo.

[Voltar ao mapa do projeto](../mapa-do-projeto.md).
