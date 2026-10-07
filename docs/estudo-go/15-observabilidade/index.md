# Observabilidade

**Estado:** Planejado. Veja o [roadmap](../roadmap.md) para a sequência e os pré-requisitos.

## Onde isso aparece no projeto

Prometheus e Grafana têm arquivos de configuração e dashboards. Nenhum serviço Go expõe `/metrics` hoje.

Fontes: `deploy/monitoring/`, [ADR 0009](../../adr/0009-metrics-in-grafana-workflow-in-console.md).

## O que você vai aprender

Distinguir métrica configurada no dashboard de série realmente emitida; estudar labels e cardinalidade.

## Checkpoint desta etapa

- [ ] Consigo localizar as fontes mencionadas no checkout.
- [ ] Sei separar o comportamento implementado da intenção descrita nos ADRs.
- [ ] Sei qual conceito precisa estar claro antes do capítulo completo.

[Voltar ao mapa do projeto](../mapa-do-projeto.md).

