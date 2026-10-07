# Fundamentos de Go no projeto

O primeiro problema é representar estados, transições e dados temporários sem perder o controle de quem pode alterá-los. O motor em `pkg/fsm` e a estrutura inicial de `pkg/memcache` dão exemplos concretos; os quatro `cmd/*/main.go` mostram o ponto de entrada de cada executável.

Siga [Tipos, funções e estado](tipos-funcoes-estado.md), [Coleções e controle de fluxo](colecoes-fluxo.md) e [Ponteiros, métodos e ciclo de vida](ponteiros-metodos.md). O pacote de cache é parcial; os exemplos explicam a estrutura presente, não operações de leitura/escrita ainda inexistentes.

## Você deve conseguir explicar

- [ ] O que diferencia `package main` de `package fsm`.
- [ ] Por que `State` é um tipo definido, e não alias de `string`.
- [ ] Quando um slice compartilha o mesmo array subjacente.
- [ ] Como a FSM usa mapas para resolver handlers e terminais.
- [ ] Por que `Run` recebe `*T` e `Machine` usa receiver de ponteiro.
- [ ] Onde o código usa `for`, `range` e múltiplos retornos.
- [ ] O que ainda é exemplo didático: `switch` e `defer` não aparecem no código Go atual.
