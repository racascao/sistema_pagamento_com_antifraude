# Ponteiros, métodos e ciclo de vida

## O que você vai aprender

Entender ponteiros, receivers, métodos, composição de structs e o papel de `defer` na liberação de recursos. A FSM fornece o exemplo principal; `defer` é introduzido como exemplo mínimo porque não aparece no Go atual do repositório.

## Onde isso aparece no projeto

`pkg/fsm/fsm.go`, `pkg/fsm/fsm_test.go` e `pkg/memcache/memcache.go`.

## O problema

O handler de scoring do teste precisa alterar `score` e registrar `visited`; o próximo handler deve enxergar essas alterações. Configurar `Handle` e `Terminal` também precisa mudar a mesma máquina encadeada.

## Modelo mental e sintaxe de Go

`*T` é um ponteiro para um valor de tipo `T`. Passá-lo permite que a função opere sobre o mesmo payload; o ponteiro não implica automaticamente segurança entre goroutines. Um método é uma função com receiver. `Machine[T]` encapsula mapas e opções; seus métodos têm receiver `*Machine[T]` para modificar a instância.

Origem: `pkg/fsm/fsm.go`:

```go
type Handler[T any] func(context.Context, *T) (State, error)

func (machine *Machine[T]) Handle(state State, handler Handler[T]) *Machine[T] {
	machine.handlers[state] = handler
	return machine
}
```

O payload é passado por ponteiro ao handler. `Handle` registra uma função no mapa da máquina e devolve o mesmo ponteiro, permitindo encadear chamadas. Não é um construtor de novas máquinas. Métodos com receiver de valor poderiam copiar o array de ponteiros e os cabeçalhos dos mapas; isso confundiria o contrato de mutação.

Origem: `pkg/fsm/fsm_test.go`:

```go
func record(p *payload, name string) {
	p.visited = append(p.visited, name)
}
```

`append` pode atualizar o cabeçalho do slice. Receber `*payload` faz a atribuição a `p.visited` permanecer visível ao chamador. O teste happy path também altera `p.score = 0.9` em outro handler.

Origem: `pkg/fsm/fsm.go`:

```go
type Machine[T any] struct {
	initial   State
	terminals map[State]bool
	handlers  map[State]Handler[T]
	fallbacks map[State]State
	maxHops   int
}
```

`Machine` é composta por campos com responsabilidades específicas: estado inicial, mapas de configuração e limite de hops. Composição por campos não é herança. Go também permite *embedding* de um tipo como campo sem nome para promover métodos, mas `Machine` não usa esse recurso; a configuração explícita torna visível de onde cada parte vem.

**Exemplo mínimo — liberação em uma operação futura do cache:**

```go
target.mu.Lock()
defer target.mu.Unlock()
// operação sobre target.items
```

**No payment-processor:** `pkg/memcache/memcache.go` declara `mu sync.RWMutex` e `items`, mas ainda não contém métodos de leitura ou escrita. O trecho acima não foi implementado. `defer` executaria o `Unlock` ao sair da função, inclusive por `return` ou panic, depois de `Lock` ter sido adquirido. Não o coloque dentro de um loop longo sem considerar quanto tempo o lock ficaria retido.

## Como funciona por dentro

Passar um ponteiro copia o endereço, não o valor inteiro. A memória pode ir para heap se a análise de escape determinar que precisa sobreviver à chamada; ponteiro não significa obrigatoriamente alocação no heap. `defer` registra uma chamada para o retorno da função e seus argumentos são avaliados no momento do `defer`.

## Por que foi feito assim, alternativas e armadilhas

Passar payload por valor isolaria mudanças como `score`; retornar uma cópia a cada handler tornaria a assinatura mais complexa. Um `Machine` configurado pode ser reutilizado em execuções sequenciais; configurar mapas enquanto outras goroutines chamam `Run` exigiria sincronização que o pacote não implementa. O comentário do código pede construir uma vez e só depois reutilizar. `Cache` declara `sync.Once` e `stop` para um ciclo de vida futuro, mas seu `janitor` está vazio: ainda não existe `Close`.

## Go idiomático e Go moderno

Escolha receiver de ponteiro quando o método modifica o valor ou quando copiar a struct seria inadequado. Use `defer` próximo da aquisição de um recurso, quando a liberação no retorno for desejada. Não adicione um método só para demonstrar sintaxe. O [módulo de concorrência](../06-concorrencia/index.md) abordará locks e ownership em profundidade.

## Exercícios

- **Nível 2 — explicar:** por que `record` não recebe `payload` por valor?
- **Nível 3 — modificar:** acrescente em branch de estudo uma asserção de `visited` no happy path e verifique que as duas etapas alteram o mesmo payload.
- **Nível 4 — diagnosticar:** o que poderia acontecer se `Handle` fosse chamado ao mesmo tempo que `Run`?

## Checklist

- [ ] Sei diferenciar `T` de `*T` neste fluxo.
- [ ] Entendo por que `Handle` devolve `*Machine[T]`.
- [ ] Sei o que `defer` garantiria no exemplo e que ele ainda não está no cache.
- [ ] Não confundo ponteiros com segurança concorrente.

## Próximo passo

Os handlers devolvem `error`: veja [Erros e fallback na FSM](../04-erros/fsm-erros.md) para entender como a causa é preservada e quando o pipeline prossegue.
