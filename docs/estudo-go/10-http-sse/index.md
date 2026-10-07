# HTTP e SSE

**Estado:** Planejado. Veja o [roadmap](../roadmap.md) para a sequência e os pré-requisitos.

## Onde isso aparece no projeto

O gateway atual apenas imprime uma mensagem. Endpoints HTTP e feed SSE constam da arquitetura e do Compose, mas não há handlers Go.

Fontes: `cmd/gateway/main.go`, [arquitetura](../../architecture.md), [ADR 0009](../../adr/0009-metrics-in-grafana-workflow-in-console.md).

## O que você vai aprender

Distinguir request/response de stream unidirecional; estudar cancelamento e backpressure com implementação real.

## Checkpoint desta etapa

- [ ] Consigo localizar as fontes mencionadas no checkout.
- [ ] Sei separar o comportamento implementado da intenção descrita nos ADRs.
- [ ] Sei qual conceito precisa estar claro antes do capítulo completo.

[Voltar ao mapa do projeto](../mapa-do-projeto.md).

