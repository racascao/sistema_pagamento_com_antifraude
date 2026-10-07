# FSM: juntando as peças

Esta seção reúne conceitos já apresentados separadamente. A implementação é o motor genérico em `pkg/fsm/fsm.go`; ela não configura ainda uma pipeline de fraude concreta.

## O motor real

Origem: `pkg/fsm/fsm.go`:

```go
type Machine[Data any] struct {
	initial   State
	terminals map[State]bool
	handlers  map[State]Handler[Data]
	fallbacks map[State]State
	maxHops   int
}

func (machine *Machine[Data]) Run(ctx context.Context, data *Data) ([]Transition, error)
```

`Machine[Data]` combina configuração e execução: parte de `initial`, localiza o handler do estado corrente, registra uma `Transition` e para ao alcançar um terminal, encontrar um erro sem fallback, observar cancelamento do contexto ou esgotar `maxHops`.

```text
estado atual → handler → Transition → terminal?
                    │
                    └── erro → fallback configurado? → próximo estado
```

## Como os conceitos se conectam

```text
Machine[Data]
├── Generics: Data mantém o payload estático em Handler[Data] e Run
├── Interfaces: context.Context e error são contratos da biblioteca padrão
├── Erros: ErrNoTransition e %w preservam a categoria ou a causa
└── Testes: fsm_test observa o comportamento pela API pública
```

Esses são recursos distintos: `struct`, métodos, mapas, ponteiros e parâmetros de tipo são linguagem Go; `context`, `errors`, `fmt` e `time` são biblioteca padrão; uma máquina de estados, seus terminais e fallback são decisões de design.

Leia os detalhes em [Interfaces](../03-interfaces/interfaces-na-fsm.md), [Erros](../04-erros/fsm-erros.md), [Generics](../05-generics/machine-generica.md) e [Testes](../08-testes/testando-fsm.md).

## Construção e execução

O teste de caminho feliz monta a máquina encadeando métodos que devolvem o mesmo `*Machine[payload]`:

```go
machine := fsm.New[payload]("start").
	Handle("start", func(_ context.Context, p *payload) (fsm.State, error) {
		record(p, "start")
		return "score", nil
	}).
	Handle("score", func(_ context.Context, p *payload) (fsm.State, error) {
		record(p, "score")
		p.score = 0.9
		return "done", nil
	}).
	Terminal("done")
```

Origem: `pkg/fsm/fsm_test.go`.

`New` cria os mapas e usa 32 como limite padrão. `Handle` relaciona um estado a uma função; `Terminal` marca estados de encerramento. `Run` recebe um ponteiro para o payload, portanto a alteração em `score` e o `append` em `visited` podem ser observados após a chamada. Cada hop entra no trace com origem, destino devolvido pelo handler, duração e eventual erro.

O fluxo não considera automaticamente o estado inicial como terminal: o teste declara `"done"` como terminal e o handler anterior precisa devolvê-lo.

## Falha, trace e fallback

Quando falta handler, `Run` devolve uma cadeia que contém `ErrNoTransition`:

```go
handler, ok := machine.handlers[current]
if !ok {
	return trace, fmt.Errorf("%w: %q", ErrNoTransition, current)
}
```

Quando um handler devolve erro, a transição é acrescentada antes da decisão. Sem fallback, `Run` envolve a causa com `%w` e encerra. Com `FallbackTo("ml", "rules_only")`, o motor muda para `rules_only` e pode terminar sem erro final; a falha continua em `trace[1].Err`. O destino registrado nessa transição é o valor retornado pelo handler, não o destino escolhido pelo fallback.

Isso não transforma fallback em mecanismo de erro: `error` e `errors.Is` pertencem à linguagem/biblioteca padrão; fallback é a política de rota da FSM.

## Limites e responsabilidades

`maxHops` limita ciclos de handlers. Ele não prova que a topologia é acíclica e a mensagem de erro atual contém o estado em que o limite foi atingido. A máquina não sincroniza suas configurações: construa-a antes de compartilhá-la entre goroutines, como pede o comentário do tipo. Ela também não implementa nenhum pipeline de fraude; o ADR descreve intenção futura, não uma configuração existente.

## Exercícios

- Localize em `Run` a ordem entre chamar o handler, criar a transição e consultar fallback.
- Explique por que `Machine[payload]` não precisa saber o tipo concreto `payload` do teste.
- Desenhe o trace produzido por `TestFallbackKeepsPipelineAvailable` e identifique onde a falha permanece acessível.

## Próximo passo

O próximo laboratório muda de modelo de execução sequencial para estado compartilhado entre goroutines: [Concorrência](../06-concorrencia/index.md) usa o cache real.
