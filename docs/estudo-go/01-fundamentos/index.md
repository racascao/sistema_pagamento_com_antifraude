# Fundamentos de Go no projeto

O primeiro problema é representar estados, transições e dados temporários sem perder o controle de quem pode alterá-los. O motor em `pkg/fsm` e o cache em `pkg/memcache` dão exemplos concretos; os quatro `cmd/*/main.go` mostram o ponto de entrada de cada executável.

Siga [Tipos, funções e estado](tipos-funcoes-estado.md), [Coleções e controle de fluxo](colecoes-fluxo.md) e [Ponteiros, métodos e ciclo de vida](ponteiros-metodos.md). O cache permite observar structs, mapas, arrays, ponteiros e métodos em uma implementação que também será aprofundada em [Concorrência](../06-concorrencia/index.md) e [Cache](../12-cache/index.md).

## Você deve conseguir explicar

- [ ] O que diferencia `package main` de `package fsm`.
- [ ] Por que `State` é um tipo definido, e não alias de `string`.
- [ ] Quando um slice compartilha o mesmo array subjacente.
- [ ] Como a FSM usa mapas para resolver handlers e terminais.
- [ ] Por que `Run` recebe `*T` e `Machine` usa receiver de ponteiro.
- [ ] Onde o código usa `for`, `range` e múltiplos retornos.
- [ ] O que ainda é exemplo didático: `switch` e `defer` não aparecem no código Go atual.
