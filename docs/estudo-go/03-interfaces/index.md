# Interfaces e arquitetura

**Estado:** capítulo de linguagem completo; aplicação a portas dos serviços ainda planejada. O package `pkg/fsm` usa as interfaces padrão `error` e `context.Context`, mas não declara uma interface própria. Os packages `domain/usecase/infra/adapter` descritos em `AGENTS.md` ainda não existem.

Comece por [Interfaces na execução da FSM](interfaces-na-fsm.md): métodos, satisfação implícita, method sets, `nil`, fakes e a diferença entre interfaces e parâmetros de tipo. Depois siga para [Generics](../05-generics/index.md), [Erros](../04-erros/index.md) e [Testes](../08-testes/index.md).

## Checkpoint

- [ ] Sei explicar satisfação implícita e a ausência de `implements`.
- [ ] Sei diferenciar os method sets de `Machine[T]` e `*Machine[T]`.
- [ ] Sei dizer quem deve possuir uma interface pequena.
- [ ] Sei criar um fake mínimo para um consumidor hipotético sem afirmar que essa porta já existe.
