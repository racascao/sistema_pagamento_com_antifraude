# Lendo a máquina genérica

## O que você vai aprender

Ler uma declaração genérica real, seguir sua instanciação no teste, entender inferência e constraints, e escolher entre tipo concreto, interface e type parameter. A FSM é o exemplo; o assunto é o sistema de tipos de Go.

## O problema

O motor precisa percorrer estados e executar handlers sem conhecer `Payment`, `Decision` ou qualquer payload de fraude futuro. Se aceitasse `any` como valor dinâmico, cada handler precisaria de type assertion em runtime. Se a máquina fosse escrita para um único payload, seria duplicada para cada uso real. O type parameter conserva a relação entre `New`, `Handle` e `Run` em compilação.

## Onde isso aparece no projeto

Origem: `pkg/fsm/fsm.go`:

```go
type State string

type Handler[T any] func(context.Context, *T) (State, error)

type Machine[T any] struct {
	initial   State
	terminals map[State]bool
	handlers  map[State]Handler[T]
	fallbacks map[State]State
	maxHops   int
}
```

O parâmetro `T` é o **payload**, não o tipo dos estados. `State` é concreto e usado como chave dos mapas. `T` pode ser qualquer tipo admitido por `any`; o motor só passa `*T` aos handlers e não executa operações específicas do domínio.

## Lendo uma declaração genérica real

```text
type       declara um tipo
Machine    nome do tipo
[T any]    parâmetro T com constraint any
struct     representação composta por campos
```

`any` é alias de `interface{}`; como constraint, seu conjunto de tipos não restringe o argumento. Isso não significa que `Machine[T]` seja equivalente a `Machine[any]`: uma instância `Machine[payload]` mantém `*payload` em suas assinaturas. Para o código que usa `T`, o compilador verifica a mesma relação de tipo em todos os métodos.

Origem: `pkg/fsm/fsm.go`:

```go
func New[T any](initial State, opts ...Option[T]) *Machine[T] {
```

`New` é **função genérica**: declara seu próprio `T`. `initial State` é parâmetro comum; `opts ...Option[T]` e o retorno ligam o mesmo `T` à máquina construída. Origem: `pkg/fsm/fsm.go`:

```go
func (machine *Machine[T]) Run(ctx context.Context, data *T) ([]Transition, error) {
```

`Run` é **método de tipo genérico**: usa `T` já declarado em `Machine[T]`, sem introduzir outro parâmetro de tipo. Métodos com parâmetros de tipo **adicionais** não são aceitos pelo Go 1.26 declarado neste repositório; foram introduzidos em Go 1.27. Veja [Go moderno](../18-go-moderno/index.md).

## Da definição à execução

Origem: `pkg/fsm/fsm_test.go`:

```go
machine := fsm.New[payload]("start").
	Handle("start", func(_ context.Context, p *payload) (fsm.State, error) {
		record(p, "start")
		return "score", nil
	}).
```

```text
Machine[T] no package fsm
    ↓ New[payload]("start")
*Machine[payload] no teste
    ↓ Handle exige Handler[payload]
func(context.Context, *payload) (fsm.State, error)
    ↓ Run(ctx, &p)
trace e alterações no mesmo payload
```

O tipo `payload` é definido no teste, fora de `pkg/fsm`. A FSM não o importa. O código que define o handler sabe que `p` é `*payload` e pode alterar `score` sem type assertion. `fsm.New("start")` sozinho não consegue inferir `T`: `initial` é sempre `State`, e o tipo de retorno não fornece inferência a partir da atribuição. `fsm.New[payload]("start")` explicita o argumento; a chamada encadeada a `Handle` já conhece `T` pela máquina. `WithMaxHops[T](n)` também pode precisar do argumento explícito, pois `n int` não contém `T`.

## Type safety em compilação

**Este código não compila — propositalmente.** É um exemplo mínimo sobre a API real; não o adicione a `.go`:

```go
machine := fsm.New[payload]("start")
machine.Handle("start", func(_ context.Context, n *int) (fsm.State, error) {
	return "done", nil
})
```

`Handle` exige `Handler[payload]`, que recebe `*payload`; uma função com `*int` não satisfaz essa assinatura. O erro aparece no build, antes de qualquer pagamento ou teste executar. Com um payload dinâmico `any`, a incompatibilidade poderia chegar mais tarde como type assertion falha. Os testes atuais usam somente `payload`; eles verificam comportamento de `Machine[payload]`, não uma matriz artificial de tipos. [Testes](../08-testes/testando-fsm.md) explica esse limite.

## Constraints, `comparable` e conjuntos de tipos

Uma constraint define quais tipos podem instanciar um parâmetro e quais operações são seguras para todos eles. `any` permite qualquer tipo, mas não autoriza operações específicas como `+` sobre `T`. `comparable` permite `==`/`!=` e serve para chaves de `map[K]V`. Na FSM, as chaves são `State`, um tipo concreto baseado em `string` e portanto comparável; o payload `T` não precisa ser comparável e pode conter slices e maps.

**Exemplo mínimo** (não existe em `pkg/fsm`):

```go
type Integer interface {
	~int | ~int32 | ~int64
}

type HopCount int
```

`|` forma uma união de termos de tipo; `~int` inclui tipos definidos cujo underlying type é `int`, como `HopCount`. A interface acima é uma **constraint de conjunto de tipos**, não uma interface para guardar valores dinâmicos comuns. Ela só faria sentido aqui se houvesse um algoritmo aritmético realmente reutilizado por vários tipos inteiros. `maxHops` é `int`, e criar `Integer` para um campo não traria benefício. Interfaces como `error` descrevem métodos e podem ser valores; [Interfaces](../03-interfaces/interfaces-na-fsm.md) apresenta essa distinção. Uma interface genérica como o `Runner[T]` didático pode descrever comportamento relacionado a `T`, mas a FSM atual não define uma.

## Interface ou type parameter?

Use interface comum quando o consumidor só precisa chamar um comportamento, como `Error()` de `error` ou `Done()`/`Err()` de `context.Context`. Use parâmetro de tipo quando a relação entre entradas e saídas ou a operação sobre um conjunto de tipos precisa permanecer estática. Em `Machine[T]`, `Handler[T]` e `Run(..., *T)` precisam concordar sobre o mesmo payload. Uma interface `Runner[T]` seria um contrato opcional do consumidor, não substituto automático para `T`.

O compilador pode gerar instâncias especializadas ou compartilhar implementação com metadados conforme a versão e os tipos. O contrato da linguagem é a checagem estática e o comportamento, não um modelo único de monomorfização nem ganho automático de velocidade. Compare [Interfaces](../03-interfaces/interfaces-na-fsm.md) antes de escolher com base em microperformance.

## Onde generics piorariam este projeto

- `Transition` guarda `State`, `time.Duration` e `error` conhecidos. Tornar esses campos genéricos só aumentaria as assinaturas sem segundo uso real.
- `ErrNoTransition` é uma categoria de erro concreta; uma função genérica de criação de erros não ajudaria o chamador a reconhecê-la.
- `context.Context` já define o comportamento necessário; trocar a interface por um type parameter tornaria `Handler[T]` mais complexo.
- Os quatro `cmd/*/main.go` imprimem mensagens diferentes. Uma abstração genérica para essas poucas linhas esconderia pontos de entrada simples.
- `Machine[any]` deslocaria o tipo do payload para assertions em runtime; não é a mesma reutilização segura de `Machine[payload]`.

`AGENTS.md` prefere três linhas parecidas a uma generalização precoce. `Cache[V]` é outra abstração real de mecanismo; `pkg/batch` ainda está vazio, portanto não serve como exemplo implementado.

## Biblioteca padrão genérica moderna

Desde Go 1.21, `slices`, `maps` e `cmp` oferecem operações genéricas comuns. **Exemplos mínimos**, possíveis com tipos reais do teste mas **não presentes** em `pkg/fsm`:

```go
sawML := slices.Contains(p.visited, "ml")
snapshot := slices.Clone(trace)
terminalsCopy := maps.Clone(map[fsm.State]bool{"done": true})
order := cmp.Compare(fsm.State("done"), fsm.State("start"))
```

O compilador infere os argumentos de tipo das chamadas a partir dos parâmetros. `slices.Clone` e `maps.Clone` são cópias rasas; nenhum deles substitui sincronização ou validação. `cmp.Compare` compara estados por ordem lexical da string subjacente, **não** pela ordem do pipeline. Esses pacotes evitam helpers caseiros quando a operação genérica já existe, mas não justificam uma refatoração automática do motor. Veja a classificação por versão em [Go moderno](../18-go-moderno/index.md).

## Alternativas e armadilhas

Uma máquina específica de `payload` seria mais curta para um único uso, mas colocaria o tipo de teste ou um futuro tipo de fraude em `pkg/fsm`. Uma máquina de `any` aceitaria dados heterogêneos, perdendo a ligação estática entre handler e payload. Um `T comparable` seria restrição indevida: `payload` contém um slice e não é comparável. Não confunda o `State` concreto com `T`, nem uma interface usada como constraint com um valor de interface.

## Exercícios

- **Nível 1 — reconhecer:** localize `T` em `Machine`, `Handler`, `New` e `Run`; diga qual tipo é sempre `State`.
- **Nível 2 — explicar:** por que `fsm.New("start")` não infere `T`, mas `Handle` conhece `*payload` depois de `New[payload]`?
- **Nível 3 — modificar:** em branch de estudo, acrescente um caso table-driven ao teste com outro valor de `score`, mantendo o mesmo `payload`.
- **Nível 4 — diagnosticar:** alguém altera a API para `T comparable`. O teste atual compila? Localize o campo que determina a resposta.
- **Nível 5 — projetar:** para um novo mecanismo que indexa estados comparáveis de vários tipos, escolha entre mapa com `State`, interface comum e parâmetro `S comparable`; justifique o segundo uso real antes de generalizar.

## Checklist

- [ ] Sei ler `Foo[T Constraint]` e uma função genérica.
- [ ] Sei explicar `any`, `comparable`, type set, `|` e `~`.
- [ ] Sei seguir `Machine[T]` até `Machine[payload]` e `Run(ctx, &p)`.
- [ ] Sei distinguir método de tipo genérico de método com parâmetro adicional.
- [ ] Sei dizer quando não usar generics neste repositório.

## Próximo passo

Leia [Erros](../04-erros/index.md) para acompanhar o segundo retorno do handler e [Testes](../08-testes/testando-fsm.md) para verificar o contrato de uma instância concreta. O futuro [módulo FSM](../11-fsm/index.md) ficará com topologia e auditabilidade.
