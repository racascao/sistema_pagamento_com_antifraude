# Coleções e controle de fluxo

## O que você vai aprender

Ler arrays, slices, `len`, `cap`, `append`, mapas, `for`, `range` e condições da FSM. `switch` aparece como exemplo mínimo porque o código Go atual não o usa.

## Onde isso aparece no projeto

`pkg/fsm/fsm.go`, `pkg/fsm/fsm_test.go` e `pkg/memcache/memcache.go`.

## O problema

Uma execução da FSM precisa guardar um número variável de transições. Já o cache foi desenhado com exatamente 16 shards. A máquina precisa consultar rapidamente qual handler atende cada estado e interromper o loop após um limite.

## Modelo mental

Um array tem comprimento fixo e faz parte do tipo. Um slice é uma visão de um array subjacente, com comprimento e capacidade. Um mapa associa chaves a valores; consultar uma chave ausente retorna o zero value e, na forma de dois resultados, `ok=false`. Loops percorrem esses dados e decidem o próximo passo.

## Sintaxe de Go e código real

Origem: `pkg/memcache/memcache.go`:

```go
const shardCount = 16

type Cache[V any] struct {
	shards [shardCount]*shard[V]
	// outros campos omitidos
}
```

`[shardCount]*shard[V]` é um **array** de 16 ponteiros. A escolha fixa a quantidade na construção do cache; não cresce com `append`. O construtor percorre seus índices e inicializa cada `map`:

```go
for i := range cache.shards {
	cache.shards[i] = &shard[Value]{
		items: make(map[string]entry[Value]),
	}
}
```

`range` sobre o array fornece cada índice. Esse array não é um slice: `len(cache.shards)` é sempre 16 e `cap` não é uma propriedade separada para ele.

Origem: `pkg/fsm/fsm.go`:

```go
trace := make([]Transition, 0, machine.maxHops)
current := machine.initial

for hops := 0; hops < machine.maxHops; hops++ {
	// uma tentativa por hop
}
```

`make` cria um slice de comprimento zero e capacidade `maxHops`. `len(trace)` começa em zero; `cap(trace)` é a reserva inicial. `append` acrescenta transições e pode alocar outro array se a capacidade acabar. Uma variável que apontava para o array antigo não acompanha essa troca automaticamente. A reserva antecipa o limite de hops, mas um `WithMaxHops` negativo causaria panic em `make`; a API ainda não valida esse valor.

Origem: `pkg/fsm/fsm.go`:

```go
handler, ok := machine.handlers[current]
if !ok {
	return trace, fmt.Errorf("%w: %q", ErrNoTransition, current)
}
```

O mapa usa `State` como chave. O booleano `ok` distingue ausência de handler de um valor zero presente. Há uma sutileza: registrar um handler `nil` produziria `ok=true`, mas chamá-lo causaria panic. Esse caso não é validado pelo código atual.

Origem: `pkg/memcache/memcache.go`:

```go
currentEntry, ok := shard.items[key]
if !ok || cache.now().After(currentEntry.expiresAt) {
	var zero Value
	return zero, false
}
```

Aqui `items` é `map[string]entry[Value]`: a chave é a string recebida por `Get`; o valor contém o payload e seu instante de expiração. `ok` separa chave ausente de uma entrada presente cujo payload seja o zero value de `Value`. Para uma entrada expirada, `Get` também devolve zero e `false`; ela só é removida fisicamente na próxima varredura do janitor.

Origem: `pkg/fsm/fsm.go`:

```go
for _, state := range states {
	machine.terminals[state] = true
}
```

`range` percorre o slice recebido por `Terminal(states ...State)`; `_` descarta o índice. O mapa marca terminais por chave. O construtor cria os mapas com `make`; um mapa `nil` não aceitaria essa escrita. Para cada execução, `current` muda até atingir um terminal ou estourar `maxHops`.

**Exemplo mínimo — `switch` com estados existentes:**

```go
switch next {
case "done":
	return trace, nil
default:
	current = next
}
```

**No payment-processor:** `Run` usa `if machine.terminals[next]`, não esse `switch`. O mapa é apropriado porque a lista de terminais é configurável; um `switch` fixaria os estados no motor compartilhado.

## Como funciona por dentro

Um slice guarda ponteiro para array, comprimento e capacidade. Copiar o slice copia esse cabeçalho, não todos os elementos. Dois slices podem observar alterações no mesmo array até uma expansão realocar um deles. O mapa é uma estrutura mutável; não é seguro escrever e ler simultaneamente sem coordenação. No cache, cada mapa pertence a um shard e é protegido por seu `sync.RWMutex`; veja [Concorrência](../06-concorrencia/index.md).

## Por que foi feito assim, alternativas e armadilhas

O array de shards expressa cardinalidade fixa; o slice de trace expressa comprimento variável. Um `switch` para handlers faria o motor depender de nomes concretos. O mapa permite configurar handlers, com custo de acesso e necessidade de verificar ausência. `maxHops` evita execução infinita mesmo quando handlers formam um ciclo, embora o [ADR](../../adr/0005-fsm-with-deterministic-fallback.md) afirme que loops seriam estruturalmente impossíveis: o código atual só os limita.

## Go idiomático e Go moderno

Use a forma `value, ok := map[key]` quando ausência tem significado. `for range` evita manipular índices sem necessidade. O comportamento da variável de loop mudou no Go 1.22 para variáveis declaradas por iteração; consulte a [seção de Go moderno](../18-go-moderno/index.md) antes de interpretar closures antigas.

## Exercícios

- **Nível 1 — reconhecer:** encontre um array, um slice e três mapas no código atual.
- **Nível 2 — explicar:** o que `len(trace)` e `cap(trace)` valem imediatamente após `make` com `maxHops=32`?
- **Nível 4 — diagnosticar:** que acontece se `WithMaxHops` receber `-1`? E se um handler chamar outro estado para sempre?

## Checklist

- [ ] Distingo array de slice e sei o que `append` pode realocar.
- [ ] Sei por que o mapa é inicializado com `make`.
- [ ] Entendo `value, ok` e a função do limite de hops.
- [ ] Sei que `switch` acima é exemplo didático, não código em produção.

## Próximo passo

Leia [ponteiros, métodos e ciclo de vida](ponteiros-metodos.md) para entender quem modifica o payload e como a máquina é configurada.
