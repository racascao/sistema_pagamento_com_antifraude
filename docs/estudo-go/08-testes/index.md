# Testes e tooling

**Estado:** laboratório de testes da FSM completo; benchmarks e testes de serviços permanecem planejados. Veja o [roadmap](../roadmap.md).

## Onde isso aparece no projeto

Os testes disponíveis estão em `pkg/fsm/fsm_test.go`; `TestRun` usa uma tabela com um caso, e os outros testes cobrem fallback e wrapping. Leia [Testando a FSM](testando-fsm.md) para entender o que cada teste prova e o que ainda falta. Não há benchmark Go neste checkout.

Fontes: `pkg/fsm/fsm_test.go`; `Makefile` e `go.mod`.

## O que você vai aprender

Usar `testing.T`, subtests, tabela de casos, `errors.Is`, helpers, fakes e race detector; reconhecer que `go vet` e benchmarks respondem perguntas diferentes.

## Checkpoint

- [ ] Sei escrever um teste table-driven com `t.Run`.
- [ ] Sei testar uma sentinela encapsulada com `errors.Is`.
- [ ] Sei explicar o propósito e o limite do race detector.
- [ ] Sei distinguir testes existentes de casos ainda não cobertos.

[Voltar ao mapa do projeto](../mapa-do-projeto.md).
