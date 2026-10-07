# Testes e tooling

**Estado:** laboratório da FSM e testes de cache concorrente disponíveis; benchmarks e testes de serviços permanecem planejados. Veja o [roadmap](../roadmap.md).

## Onde isso aparece no projeto

`pkg/fsm/fsm_test.go` cobre caminho feliz, fallback e wrapping; `pkg/memcache/memcache_test.go` cobre TTL, incremento atômico, acesso concorrente e janitor. `TestRun` usa uma tabela com um caso. Leia [Testando a FSM](testando-fsm.md) para entender esse primeiro laboratório, [Concorrência](../06-concorrencia/index.md) para limites do race detector e [Cache](../12-cache/index.md) para o segundo. Não há benchmark Go neste checkout.

Fontes: `pkg/fsm/fsm_test.go`, `pkg/memcache/memcache_test.go`; `Makefile` e `go.mod`.

## O que você vai aprender

Usar `testing.T`, subtests, tabela de casos, `errors.Is`, helpers, fakes e race detector; reconhecer que `go vet` e benchmarks respondem perguntas diferentes.

## Checkpoint

- [ ] Sei escrever um teste table-driven com `t.Run`.
- [ ] Sei testar uma sentinela encapsulada com `errors.Is`.
- [ ] Sei explicar o propósito e o limite do race detector.
- [ ] Sei distinguir testes existentes de casos ainda não cobertos.

[Voltar ao mapa do projeto](../mapa-do-projeto.md).
