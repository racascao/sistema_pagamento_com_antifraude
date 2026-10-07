# Modelagem com Go

**Estado:** Planejado. Veja o [roadmap](../roadmap.md) para a sequência e os pré-requisitos.

## Onde isso aparece no projeto

As migrações definem `payments`, `ledger_entries` e `reviews`, mas ainda não existem structs de domínio Go correspondentes. O módulo estudará como traduzir invariantes SQL em tipos e funções de domínio sem importar infraestrutura.

Fontes: `migrations/00002_create_payments_and_entries.sql`, `migrations/00006_create_reviews.sql` e `migrations/00007_review_decisions.sql`.

## O que você vai aprender

Distinguir esquema de banco de modelo de domínio; escolher campos e invariantes; comparar composição com acoplamento.

## Checkpoint desta etapa

- [ ] Consigo localizar as fontes mencionadas no checkout.
- [ ] Sei separar o comportamento implementado da intenção descrita nos ADRs.
- [ ] Sei qual conceito precisa estar claro antes do capítulo completo.

[Voltar ao mapa do projeto](../mapa-do-projeto.md).

