# Cache, sharding e TTL

**Estado:** laboratório funcional. O cache em memória é genérico, possui 16 shards, TTL, limpeza em background e API pública para leitura, escrita, incremento, tamanho e encerramento.

## Estrutura e escolha do shard

Origem: `pkg/memcache/memcache.go`:

```go
type entry[Value any] struct {
	value     Value
	expiresAt time.Time
}

type Cache[Value any] struct {
	shards [shardCount]*shard[Value]
	ttl    time.Duration
	now    func() time.Time
	stop   chan struct{}
	once   sync.Once
}
```

`Cache[Value]` mantém o tipo do valor estático, como `Cache[int]` nos testes. `entry` associa o payload ao instante em que deixa de ser válido. Sharding não é recurso de Go: é a decisão de dividir o estado em várias estruturas menores para reduzir contenção. Go fornece as peças — array, `map`, método e lock.

```go
func (cache *Cache[Value]) shardFor(key string) *shard[Value] {
	h := fnv.New32a()
	_, _ = h.Write([]byte(key))
	return cache.shards[h.Sum32()%shardCount]
}
```

FNV-1a transforma a chave em número determinístico; o módulo por 16 escolhe o índice. O retorno é um ponteiro para o shard que guarda tanto o mapa como seu lock.

## TTL e expiração

TTL é uma duração (`time.Duration`). O instante de expiração é um `time.Time` calculado na escrita:

```go
expiresAt: cache.now().Add(ttl),
```

```text
inserção → agora + TTL → expiresAt → Get verifica validade
```

`Set` usa o TTL padrão do cache; `SetTTL` recebe uma duração específica. `Get` lê a entrada e devolve `false` se a chave não existe ou se `cache.now().After(currentEntry.expiresAt)`. Ele não apaga a entrada nesse caminho: a limpeza física é responsabilidade do janitor. Portanto, uma entrada pode estar inválida para leitura e ainda contar em `Len` até a próxima varredura.

## Escrita e incremento atômico

`Increment` seleciona um único shard, mantém seu `Lock` enquanto consulta a entrada, chama a função de atualização e grava o novo valor com o TTL padrão renovado. Essa é a propriedade observada por `TestIncrementIsAtomic`: 100 goroutines incrementam `card:123` e o valor final é 100. O pacote não usa `sync/atomic`; “atômico” aqui descreve a atualização indivisível garantida pelo lock. Veja [Concorrência](../06-concorrencia/index.md) para a diferença.

O callback executa sob o lock daquele shard. Ele deve ser curto e não deve chamar de volta o mesmo cache de forma que tente obter o mesmo lock; além de aumentar contenção, isso pode bloquear a operação. Essa é uma consequência do código, não uma nova regra de API.

## Limpeza periódica e encerramento

Janitor não é propriedade obrigatória de todo cache; é uma estratégia de limpeza periódica usada por algumas implementações. Nesta, `New` inicia uma goroutine com `janitor(sweepEvery)`. A cada tick, ela percorre todos os shards e remove apenas entradas cujo `expiresAt` já passou. O channel `stop` permite encerrar o laço; `Close` usa `sync.Once` para tornar esse encerramento idempotente.

Não há `context.Context` nessa API. O proprietário que cria o cache deve chamar `Close`; o ticker é parado pelo `defer` dentro do janitor. Veja o tratamento de locks e lifecycle em [Concorrência](../06-concorrencia/index.md).

## O que os testes observam

`pkg/memcache/memcache_test.go` é black-box: importa o pacote e usa apenas a API exportada.

- `TestSetGet` verifica escrita e leitura.
- `TestExpiration` mostra que a leitura invalida uma entrada expirada mesmo antes de uma varredura longa.
- `TestIncrementIsAtomic` verifica atualização concorrente no mesmo shard.
- `TestConcurrentAccessAcrossShards` exercita `Set` e `Get` concorrentes em 50 chaves.
- `TestJanitorEvictsExpired` grava 100 chaves e usa `Len` para aguardar a remoção, sem `sleep` no teste.

## Limites do componente atual

O cache é local ao processo, não é Redis e não oferece invalidação distribuída. `Len` conta as entradas presentes nos mapas no momento das leituras de cada shard, não uma visão global transacional. A quantidade de shards é fixa em 16 e não foi justificada por benchmark neste checkout.

Para entender `RWMutex`, data race e contenção, veja [Concorrência](../06-concorrencia/index.md). Para entender o parâmetro `Value`, veja [Generics](../05-generics/machine-generica.md).
