# Kafka e investigação assíncrona

**Estado:** Planejado. Veja o [roadmap](../roadmap.md) para a sequência e os pré-requisitos.

## Onde isso aparece no projeto

Redpanda aparece no Compose, mas não existe producer nem consumer Go. A outbox é tabela, não publicação automática.

Fontes: `docker-compose.yml`, `migrations/00004_create_outbox.sql`, [ADR 0006](../../adr/0006-outbox-for-event-publishing.md).

## O que você vai aprender

Rastrear evento da transação ao broker quando o relay for implementado; explicar entrega, ordenação e idempotência.

## Checkpoint desta etapa

- [ ] Consigo localizar as fontes mencionadas no checkout.
- [ ] Sei separar o comportamento implementado da intenção descrita nos ADRs.
- [ ] Sei qual conceito precisa estar claro antes do capítulo completo.

[Voltar ao mapa do projeto](../mapa-do-projeto.md).

