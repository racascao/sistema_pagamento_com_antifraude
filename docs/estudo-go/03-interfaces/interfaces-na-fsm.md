# Interfaces na execução da FSM

## O que você vai aprender

Ler interfaces como contratos de comportamento, reconhecer satisfação implícita, method sets e `nil` tipado, e decidir quando uma interface pequena ajuda um consumidor. A FSM é o laboratório; uma porta de `usecase` ainda não foi implementada.

## Onde isso aparece no projeto

Origem: `pkg/fsm/fsm.go`:

```go
type Handler[T any] func(context.Context, *T) (State, error)
```

`context.Context` e `error` são **interfaces reais da biblioteca padrão**. `Handler[T]` não é uma interface: é um tipo de função. `Machine[T]` também não é uma interface: é uma struct parametrizada. Origem adicional: `pkg/fsm/fsm_test.go` usa `context.Background()` e `errors.New(...)` ao chamar a máquina. [Fundamentos](../01-fundamentos/index.md) apresenta funções, structs e receivers.

## O problema

O motor precisa receber um contexto que possa ser cancelado e um erro que possa ser identificado, sem conhecer a implementação concreta desses valores. Em outro cenário, um consumidor poderia precisar apenas de `Run`, sem depender de todos os métodos de configuração de `Machine[T]`.

## Modelo mental: primeiro método, depois interface

Em Go, um tipo tem um **method set**: os métodos que pertencem a ele. Uma interface descreve métodos exigidos. Se o method set contém as assinaturas necessárias, o tipo satisfaz a interface automaticamente. Não existe palavra-chave `implements`. A verificação ocorre em atribuições, argumentos ou asserções de compilação.

Origem: `pkg/fsm/fsm.go`:

```go
func (machine *Machine[T]) Run(ctx context.Context, data *T) ([]Transition, error) {
```

`Run` tem receiver `*Machine[T]`. Portanto, `*Machine[payload]` tem esse método em seu method set; `Machine[payload]` não. Uma variável endereçável de tipo `Machine[payload]` pode aceitar a chamada `value.Run(...)` por conversão implícita para `(&value).Run(...)`. Isso **não** faz o valor `Machine[payload]` satisfazer uma interface que exige `Run`.

| Receiver declarado | Method set de `T` | Method set de `*T` |
|---|---|---|
| `func (T) M()` | Contém `M` | Contém `M` |
| `func (*T) M()` | Não contém `M` | Contém `M` |

Essa é a regra da linguagem. Usar ponteiro para `Machine` é uma decisão da FSM: `Handle`, `Terminal` e `FallbackTo` alteram seus mapas. Um método com receiver de valor em outro tipo poderia ser adequado quando não há mutação e a cópia é barata.

## Exemplo mínimo: interface do consumidor

O trecho a seguir **não está no repositório**. Ele representa o menor contrato que um futuro consumidor da FSM poderia exigir:

```go
type Runner[T any] interface {
	Run(context.Context, *T) ([]fsm.Transition, error)
}

var _ Runner[payload] = (*fsm.Machine[payload])(nil)
```

A última linha verifica em compilação que `*fsm.Machine[payload]` satisfaz `Runner[payload]`. Ela não registra nem declara uma implementação, não constrói uma máquina e não executa `Run`. Trocá-la por `fsm.Machine[payload]{}` falharia: `Run` pertence ao method set do ponteiro. `payload` é o tipo de teste real de `pkg/fsm/fsm_test.go`; `Runner` é didático.

## No payment-processor

O teste black-box instancia a máquina e a usa diretamente:

Origem: `pkg/fsm/fsm_test.go`:

```go
machine := fsm.New[payload]("start").
	Handle("start", func(_ context.Context, p *payload) (fsm.State, error) {
		record(p, "start")
		return "score", nil
	}).
```

`New` devolve `*Machine[payload]`, que possui `Run`. `context.Background()` fornece um valor que satisfaz `context.Context`; `errors.New("boom")` fornece um valor que satisfaz `error`. Essas implementações não precisam mencionar `implements`. A assinatura concreta do handler mantém `*payload` verificável em compilação; [Generics](../05-generics/machine-generica.md) detalha isso.

## `nil` na interface

Uma interface só é `nil` quando não há **nem tipo dinâmico nem valor dinâmico**. Uma interface contendo um ponteiro tipado `nil` continua não nula.

**Exemplo mínimo** (usa a interface didática acima; não é código de produção):

```go
var machine *fsm.Machine[payload]
var runner Runner[payload] = machine
fmt.Println(runner == nil) // false
```

O tipo dinâmico é `*fsm.Machine[payload]`; o valor é um ponteiro `nil`. Chamar `Run` nessa situação não é seguro. O mesmo cuidado vale para erros: devolver um ponteiro tipado `nil` como `error` produz uma interface não nula. Prefira devolver `nil` explícito quando não houve erro.

## Interface ou type parameter?

Uma interface comum como `error` permite passar valores de tipos diferentes por um único contrato e chamar seus métodos por despacho dinâmico. Já `Machine[T]` conserva o tipo do payload nas assinaturas de `Handler[T]` e `Run`: para uma `Machine[payload]`, o handler recebe `*payload`. Uma função `Execute(x Handler)` e outra `Execute[T Handler](x T)` não têm automaticamente a mesma intenção; o parâmetro de tipo só ajuda quando conservar a relação entre tipos ou expressar um conjunto de tipos melhora a API. Se toda operação usa apenas os métodos de uma interface, uma interface comum costuma bastar.

O compilador especializa ou compartilha código instanciado conforme sua implementação; não trate “uma cópia de código para cada T” como garantia da linguagem nem escolha generics por promessa de performance. Veja [Generics](../05-generics/machine-generica.md) para constraints e conjuntos de tipos. `AGENTS.md` reserva generics para motores genuinamente independentes do domínio.

## Interfaces em testes e arquitetura

**Exemplo mínimo:** se um futuro `usecase` consumir somente `Run`, ele pode definir `Runner[payload]` do seu lado e receber um fake que implemente apenas `Run`. O código abaixo não existe em `fsm_test.go`:

```go
type fakeRunner struct {
	trace []fsm.Transition
	err   error
}

func (f fakeRunner) Run(_ context.Context, _ *payload) ([]fsm.Transition, error) {
	return f.trace, f.err
}

var _ Runner[payload] = fakeRunner{}
```

O fake devolve transições e erro controlados para testar a decisão do consumidor; não precisa conhecer `Handle`, `Terminal` ou `FallbackTo`. O receiver por **valor** faz tanto `fakeRunner` quanto `*fakeRunner` satisfazerem `Runner[payload]`, contrastando com `Machine[payload]`. Não há necessidade de framework de mock nem de adicionar `Runner` a `pkg/fsm`. Os testes atuais da FSM usam handlers reais em memória, não fakes de porta.

Essa é a ponte arquitetural: `AGENTS.md` determina que o futuro `usecase/` dependa de portas, `infra/` as implemente e `adapter/` traduza transporte. Não existem essas portas no checkout atual. A semântica de satisfação implícita é Go; colocar a interface no consumidor é uma escolha de design; separar `domain/usecase/infra/adapter` é a arquitetura planejada do projeto.

## Armadilhas e alternativas

- Uma interface grande obriga o fake e o consumidor a conhecer métodos que não usam.
- Guardar `*Machine[T]` em uma interface não torna segura a configuração concorrente dos mapas.
- Uma interface `Runner[T]` não é necessária quando só um chamador usa diretamente a máquina; criar portas antecipadas prejudica a clareza.
- Substituir `*T` por `any` no handler perderia a checagem de tipo do payload. Substituir toda interface por generics adicionaria complexidade sem benefício.

## Exercícios

- **Nível 1 — reconhecer:** localize as duas interfaces padrão na assinatura de `Handler[T]` e identifique o que não é interface.
- **Nível 2 — explicar:** por que `*Machine[payload]` satisfaz o `Runner[payload]` didático e `Machine[payload]` não?
- **Nível 3 — modificar:** em um rascunho fora do código de produção, defina uma interface com apenas `Run` e um fake mínimo para um consumidor que precisa dela.
- **Nível 4 — diagnosticar:** uma interface guarda `(*Machine[payload])(nil)` e a comparação com `nil` retorna `false`. Explique as duas partes do valor da interface.
- **Nível 5 — projetar:** quando existir um `usecase` que só precisa executar scoring, onde você colocaria sua porta e que método mínimo ela exigiria? Justifique sem presumir a implementação do serviço.

## Checklist

- [ ] Sei explicar satisfação implícita.
- [ ] Sei diferenciar value e pointer method sets.
- [ ] Sei dizer quem deve possuir uma interface e quando não criar nenhuma.
- [ ] Sei criar um fake mínimo.
- [ ] Não confundo `Handler[T]` (tipo de função), `Runner[T]` (interface didática) e `Machine[T]` (struct real).

## Próximo passo

Leia [Generics](../05-generics/machine-generica.md) para entender a relação entre tipo concreto e type parameter; depois [Erros](../04-erros/index.md) para acompanhar o retorno `error`.
