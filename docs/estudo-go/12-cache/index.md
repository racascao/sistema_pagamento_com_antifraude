# Cache, sharding e TTL

**Estado:** Planejado. Veja o [roadmap](../roadmap.md) para a sequência e os pré-requisitos.

## Onde isso aparece no projeto

A estrutura tem 16 shards e função FNV para seleção, mas não possui operações públicas de get/set nem expiração funcional: `janitor` está vazio.

Fontes: `pkg/memcache/memcache.go`, [ADR 0008](../../adr/0008-in-process-caches-over-redis.md).

## O que você vai aprender

Explicar TTL, hash, contenção de locks e limites de estado local sem atribuir ao código comportamento ainda inexistente.

## Checkpoint desta etapa

- [ ] Consigo localizar as fontes mencionadas no checkout.
- [ ] Sei separar o comportamento implementado da intenção descrita nos ADRs.
- [ ] Sei qual conceito precisa estar claro antes do capítulo completo.

[Voltar ao mapa do projeto](../mapa-do-projeto.md).

