# FSM

**Estado:** Planejado. Veja o [roadmap](../roadmap.md) para a sequência e os pré-requisitos.

## Onde isso aparece no projeto

O motor genérico existe em `pkg/fsm`; o pipeline `enrich → fast rules → ml score` descrito no ADR ainda não foi configurado em `fraud`. Os capítulos de [Interfaces](../03-interfaces/interfaces-na-fsm.md), [Erros](../04-erros/fsm-erros.md), [Generics](../05-generics/machine-generica.md) e [Testes](../08-testes/testando-fsm.md) usam esse motor como laboratório de linguagem.

Fontes: `pkg/fsm/fsm.go`, `pkg/fsm/fsm_test.go`, [ADR 0005](../../adr/0005-fsm-with-deterministic-fallback.md).

## O que você vai aprender

O futuro módulo de FSM abordará a **topologia** dos estados, handlers, transições, bounded hops, fallback, trace e auditabilidade. Seu foco será explicar por que uma FSM explícita foi escolhida e como uma pipeline de fraude futura poderá configurá-la, sem repetir a semântica de Go ensinada nos quatro capítulos acima.

## Checkpoint desta etapa

- [ ] Consigo localizar as fontes mencionadas no checkout.
- [ ] Sei separar o comportamento implementado da intenção descrita nos ADRs.
- [ ] Sei qual conceito precisa estar claro antes do capítulo completo.

[Voltar ao mapa do projeto](../mapa-do-projeto.md).
