# Concorrência

**Estado:** Planejado. Veja o [roadmap](../roadmap.md) para a sequência e os pré-requisitos.

## Onde isso aparece no projeto

O cache declara `sync.RWMutex`, `sync.Once` e inicia um `janitor` em goroutine, mas o método ainda está vazio. Não há batcher, relay ou EventHub Go neste checkout.

Fontes: `pkg/memcache/memcache.go`; [ADR de cache](../../adr/0008-in-process-caches-over-redis.md) para intenção.

## O que você vai aprender

Diferenciar concorrência de paralelismo; estudar ownership, channels, locks, races e encerramento quando os caminhos reais existirem.

## Checkpoint desta etapa

- [ ] Consigo localizar as fontes mencionadas no checkout.
- [ ] Sei separar o comportamento implementado da intenção descrita nos ADRs.
- [ ] Sei qual conceito precisa estar claro antes do capítulo completo.

[Voltar ao mapa do projeto](../mapa-do-projeto.md).

