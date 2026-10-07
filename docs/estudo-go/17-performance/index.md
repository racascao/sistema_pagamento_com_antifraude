# Performance

**Estado:** Planejado. Veja o [roadmap](../roadmap.md) para a sequência e os pré-requisitos.

## Onde isso aparece no projeto

Não há `BenchmarkScore` nem benchmark do batcher no checkout. Números citados no ADR de inferência são metas/relatos do desenho, não resultados reproduzíveis deste código.

Fontes: `pkg/batch/batch.go`, [ADR 0004](../../adr/0004-native-tree-inference-in-go.md), `test/load/payment-flow.js`.

## O que você vai aprender

Ler `ns/op` e `allocs/op`; medir antes de otimizar; comparar custo de CPU, lote e rede quando houver implementação.

## Checkpoint desta etapa

- [ ] Consigo localizar as fontes mencionadas no checkout.
- [ ] Sei separar o comportamento implementado da intenção descrita nos ADRs.
- [ ] Sei qual conceito precisa estar claro antes do capítulo completo.

[Voltar ao mapa do projeto](../mapa-do-projeto.md).

