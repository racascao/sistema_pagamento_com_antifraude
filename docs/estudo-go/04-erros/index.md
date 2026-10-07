# Erros

**Estado:** modelo de erros e estudo do fallback completos; tradução HTTP/gRPC permanece planejada. Veja o [roadmap](../roadmap.md).

## Onde isso aparece no projeto

A FSM já usa `errors.New` e `%w`, e os testes verificam `errors.Is`. Comece por [Modelo e cadeia de erros](cadeia-de-erros.md) para entender a regra de Go; em seguida leia [Erros e fallback na FSM](fsm-erros.md) para ver a política do motor. Tradução para status gRPC e HTTP aguarda adapters reais.

Fontes: `pkg/fsm/fsm.go` e `pkg/fsm/fsm_test.go`. Leia [Erros e fallback na FSM](fsm-erros.md).

## O que você vai aprender

Ler `valor, error`, sentinelas, `%w`, `errors.Is`, `errors.As` e `errors.AsType`; distinguir identidade de mensagem e erro de fallback. A [página de Testes](../08-testes/testando-fsm.md) mostra como verificar a cadeia.

## Checkpoint

- [ ] Sei explicar `%w` e por que `%v` não preserva a causa.
- [ ] Sei usar `errors.Is` para uma sentinela encapsulada.
- [ ] Sei diferenciar identidade de erro e mensagem.
- [ ] Sei explicar erro (mecanismo de Go) versus fallback (política da FSM).

[Voltar ao mapa do projeto](../mapa-do-projeto.md).
