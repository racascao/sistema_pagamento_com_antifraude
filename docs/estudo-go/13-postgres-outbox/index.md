# Postgres e Outbox

**Estado:** Planejado. Veja o [roadmap](../roadmap.md) para a sequência e os pré-requisitos.

## Onde isso aparece no projeto

As migrações criam pagamentos, lançamentos, idempotência e outbox. Ainda não há adapter de persistência Go, transação de autorização ou relay.

Fontes: `migrations/00002_create_payments_and_entries.sql`, `00003_create_idempotency_keys.sql`, `00004_create_outbox.sql`, [ADR 0006](../../adr/0006-outbox-for-event-publishing.md).

## O que você vai aprender

Separar garantias de constraints SQL das garantias que dependerão de transação e relay; entender duplicatas at-least-once.

## Checkpoint desta etapa

- [ ] Consigo localizar as fontes mencionadas no checkout.
- [ ] Sei separar o comportamento implementado da intenção descrita nos ADRs.
- [ ] Sei qual conceito precisa estar claro antes do capítulo completo.

[Voltar ao mapa do projeto](../mapa-do-projeto.md).

