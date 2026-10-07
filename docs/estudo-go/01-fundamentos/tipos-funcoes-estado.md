# Tipos, funções e estado

## O que você vai aprender

Identificar packages e imports, entender declaração e inferência de valores, diferenciar alias de tipo definido, ler structs, funções e múltiplos retornos no motor da FSM.

## Onde isso aparece no projeto

`cmd/gateway/main.go`, `pkg/fsm/fsm.go`, `pkg/fsm/fsm_test.go` e `migrations/migrations.go`. Os executáveis são mínimos: iniciar uma API ainda é trabalho futuro.

## O problema

Uma transição precisa ter um nome de estado, duração e eventual erro. Se todo nome fosse uma `string` indistinta, aceitar um valor incorreto ficaria fácil. O motor também deve devolver tanto o próximo estado quanto a falha do handler.

## Modelo mental

Um package agrupa declarações. O nome do package define como seu código é usado; `main` fornece um executável, `fsm` uma biblioteca importável. Um tipo definido cria uma identidade nova sobre uma representação conhecida. Uma struct agrupa dados com significado. Uma função pode devolver mais de um resultado, o que facilita expressar “valor + erro”.

## Sintaxe de Go e código real

Origem: `cmd/gateway/main.go`:

```go
package main

import "fmt"

func main() {
	fmt.Println("Gateway service starting...")
}
```

`main` torna o package executável; `import` disponibiliza `fmt`, da biblioteca padrão. O texto impresso não inicia servidor HTTP. Outros três `cmd/*/main.go` seguem a mesma forma.

Origem: `pkg/fsm/fsm.go`:

```go
type State string

type Handler[T any] func(context.Context, *T) (State, error)

type Transition struct {
	From     State
	To       State
	Duration time.Duration
	Err      error
}
```

`State` é um **tipo definido** cuja representação é `string`. `type State = string` seria um **alias**: não criaria identidade distinta. `Handler[T]` também é tipo definido, desta vez para uma assinatura de função. `Transition` é uma struct; seus campos começam em maiúscula porque são acessíveis aos testes no package `fsm_test`. `time.Duration` é um tipo definido da biblioteca padrão, usado para que duração não seja apenas um inteiro sem unidade.

Origem: `pkg/fsm/fsm.go`:

```go
startedAt := time.Now()
next, err := handler(ctx, data)
```

`:=` declara e infere tipos dentro da função. `next` recebe `State`; `err`, `error`. A chamada retorna ambos, permitindo que o motor guarde o erro na `Transition` e escolha entre fallback e abortar. Fora de função, declarações como `var ErrNoTransition = errors.New(...)` usam `var`.

Em `pkg/memcache/memcache.go`, `const shardCount = 16` fixa a contagem de shards em tempo de compilação. O valor zero importa: um `State` não inicializado é `""`, `error` não inicializado é `nil`, e um `time.Duration` não inicializado é zero. Um mapa zero (`nil`) pode ser lido, mas escrever nele causa panic; por isso o construtor da FSM usa `make`.

## Como funciona por dentro

O compilador verifica tipos em chamadas: não se passa um `time.Duration` onde se exige `State`. Ele infere os tipos de variáveis criadas com `:=`; não converte arbitrariamente tipos definidos. O segundo retorno `error` é uma interface: `nil` significa ausência de valor dinâmico. [Erros](../04-erros/fsm-erros.md) aprofunda o efeito do wrapping.

## Por que foi feito assim

`State` concentra a linguagem da FSM sem introduzir uma hierarquia de classes. `Handler[T]` serve a qualquer payload porque o motor é independente do domínio de pagamentos, conforme a regra de `AGENTS.md`. Um `Transition` explícito permite auditar cada hop; o [ADR da FSM](../../adr/0005-fsm-with-deterministic-fallback.md) explica a intenção arquitetural, ainda sem pipeline de fraude concreto.

## Alternativas e armadilhas

Usar `string` em toda assinatura reduziria declarações, mas perderia distinção semântica. Criar um enum fechado para estados específicos colocaria conhecimento do pipeline no pacote genérico. Não confunda valor zero de `State` com estado terminal: a máquina só encerra para estados registrados em `Terminal`.

## Go idiomático e Go moderno

Prefira retorno `(valor, error)` explícito e `:=` quando a inferência fica evidente. `go.mod` declara `go 1.26.4`; as formas deste capítulo são estáveis há muitas versões. O [módulo Go moderno](../18-go-moderno/index.md) separará recursos novos dos usados aqui.

## Exercícios

- **Nível 1 — reconhecer:** localize os quatro packages `main` e explique o que cada binário faz hoje.
- **Nível 2 — explicar:** por que `State` e `time.Duration` são tipos definidos em vez de `string` e `int64` soltos?
- **Nível 3 — modificar:** em um branch de estudo, acrescente a `Transition` um campo que represente a razão de uma transição e ajuste o teste black-box para lê-lo; reflita se isso pertence ao motor genérico.

## Checklist

- [ ] Distingo package executável de biblioteca.
- [ ] Sei a diferença entre `type State string` e `type State = string`.
- [ ] Consigo explicar `next, err := handler(ctx, data)` sem imaginar exceções.
- [ ] Reconheço os zero values dos campos usados aqui.

## Próximo passo

Veja como [coleções e controle de fluxo](colecoes-fluxo.md) fazem a máquina percorrer estados e guardar o trace.
