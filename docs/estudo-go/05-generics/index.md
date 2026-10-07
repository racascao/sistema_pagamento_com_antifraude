# Generics

**Estado:** capítulo completo com a FSM como laboratório. O cache é uma segunda instância de mecanismo genérico, ainda parcial. Veja o [roadmap](../roadmap.md).

## Onde isso aparece no projeto

`Machine[T]`, `Handler[T]` e `Cache[V]` são mecanismos independentes de pagamentos. `pkg/batch` ainda só declara o package. Leia [Lendo a máquina genérica](machine-generica.md) para acompanhar a instanciação real em `fsm_test.go` e decidir quando um type parameter agrega valor.

Fontes: `pkg/fsm/fsm.go`, `pkg/memcache/memcache.go`, `pkg/batch/batch.go`.

## O que você vai aprender

Entender type parameters, inferência, constraints, type sets, `~`, `comparable`, pacotes `slices`/`maps`/`cmp` e a diferença entre interface comum e interface como constraint. O [módulo Interfaces](../03-interfaces/interfaces-na-fsm.md) antecede este capítulo.

## Checkpoint

- [ ] Sei ler `Foo[T Constraint]` e instanciar `Machine[payload]`.
- [ ] Sei explicar por que `any` não transforma um parâmetro de tipo em interface dinâmica.
- [ ] Sei explicar `comparable`, type set, `|` e `~`.
- [ ] Sei dizer onde generics piorariam este projeto.

[Voltar ao mapa do projeto](../mapa-do-projeto.md).
