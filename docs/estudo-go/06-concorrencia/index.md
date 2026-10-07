# Concorrência: memória compartilhada no cache

**Estado:** parcial — memória compartilhada, locks, channel de sinalização e `select` têm laboratório real em `pkg/memcache`. Channels de dados, pipelines e coordenação por `context.Context` aguardam outros componentes.

## Concorrência não é paralelismo

Concorrência é a capacidade de múltiplas tarefas progredirem de forma intercalada. Paralelismo é a execução simultânea de tarefas. `go cache.janitor(...)` introduz concorrência: o runtime decide quando essa goroutine e as chamadas de cache executam. A execução paralela depende do scheduler, CPUs disponíveis e workload; uma goroutine não significa, por definição, execução paralela.

## O problema concreto

O cache possui estado compartilhado. Enquanto uma goroutine chama `Get`, outras podem chamar `Set` ou `Increment`, e o janitor pode remover entradas expiradas. Todas alcançam um dos mapas do cache:

```text
goroutine A → Get
goroutine B → Set
goroutine C → Increment
janitor     → remove expirados
                     │
                     ▼
             map compartilhado
```

Um `map` é a estrutura de dados; ele não fornece sincronização por conta própria. A sincronização vem do `sync.RWMutex` que o código associa a cada shard.

Origem: `pkg/memcache/memcache.go`:

```go
type shard[Value any] struct {
	mu    sync.RWMutex
	items map[string]entry[Value]
}

type Cache[Value any] struct {
	shards [shardCount]*shard[Value]
	// outros campos omitidos
}
```

## Data race e visibilidade

Quando duas goroutines acessam a mesma memória e ao menos uma escreve, o acesso precisa de sincronização apropriada. Sem isso, além de resultados incorretos, não há uma relação confiável de visibilidade entre as operações.

**Exemplo incorreto — não pertence ao projeto:**

```go
go func() { items["a"] = entry[int]{value: 1} }()
go func() { items["b"] = entry[int]{value: 2} }()
```

Escritas concorrentes em um mapa sem coordenação são inválidas. O cache seleciona um shard e obtém o lock associado antes de ler ou alterar seu mapa. Locks e operações atômicas da biblioteca padrão estabelecem as relações de sincronização necessárias; a questão não é só evitar uma falha de execução, mas preservar correção e visibilidade da memória. Veja o [Go Memory Model](https://go.dev/ref/mem).

## Região crítica e invariantes

Uma região crítica não protege apenas uma linha isolada: ela protege uma invariante do estado. Em `Increment`, a entrada atual, sua validade pelo TTL, o cálculo do novo valor e a escrita precisam formar uma única operação observável para aquela chave.

Origem: `pkg/memcache/memcache.go`:

```go
shard.mu.Lock()
defer shard.mu.Unlock()
currentEntry, ok := shard.items[key]
valid := ok && !cache.now().After(currentEntry.expiresAt)
next := counter(currentEntry.value, valid)
shard.items[key] = entry[Value]{
	value:     next,
	expiresAt: cache.now().Add(cache.ttl),
}
```

Reduzir essa região, liberando o lock antes de gravar, permitiria que dois incrementos partissem do mesmo valor. Ampliá-la sem necessidade aumenta contenção. O callback também roda sob esse lock, então deve ser curto e não deve tentar obter novamente o lock do mesmo shard.

## Mutex ou `RWMutex`?

`Get` somente lê o mapa; nesta implementação ele não atualiza métricas, TTL ou LRU. Por isso usa lock de leitura:

```go
shard.mu.RLock()
currentEntry, ok := shard.items[key]
shard.mu.RUnlock()
```

`SetTTL`, `Increment` e o janitor alteram `items`, portanto usam `Lock` e `Unlock`. O quadro resume o comportamento real:

| Operação sobre o estado protegido | Lock usado |
|---|---|
| Leitura do mapa em `Get` e `Len` | `RLock` / `RUnlock` |
| Escrita em `SetTTL` e `Increment` | `Lock` / `Unlock` |
| Remoção de expirados pelo janitor | `Lock` / `Unlock` |

`RWMutex` permite leitores concorrentes na ausência de escritor e exclui escritores. Não é um “Mutex mais rápido”: possui bookkeeping adicional, pode perder para um `Mutex` simples em workloads pouco contenciosos e deve ser avaliado pela frequência, duração e concorrência reais das operações. Não há benchmark do cache neste checkout; [Performance](../17-performance/index.md) é o lugar para medições futuras.

## Sharding e granularidade de lock

O cache usa 16 shards fixos. O caminho de uma chave é:

```text
key → FNV-1a → hash % shardCount → shard → lock local → map local
```

Origem: `pkg/memcache/memcache.go`:

```go
func (cache *Cache[Value]) shardFor(key string) *shard[Value] {
	h := fnv.New32a()
	_, _ = h.Write([]byte(key))
	return cache.shards[h.Sum32()%shardCount]
}
```

FNV-1a é uma função de hash não criptográfica; aqui serve para distribuir chaves, não para segurança. Colisões de hash ou de índice não corrompem dados: mais de uma chave pode usar o mesmo shard, aumentando a contenção nele.

Com um lock global, toda operação disputaria o mesmo lock. Com locks por shard, operações em shards diferentes podem progredir independentemente. Essa é uma forma de granularidade mais fina, com mais estruturas e mais raciocínio. Sharding reduz a superfície de contenção quando as chaves se distribuem adequadamente; não elimina contenção nem demonstra ganho quantitativo sem benchmark. Veja a aplicação completa em [Cache, sharding e TTL](../12-cache/index.md).

## Atomicidade não é `sync/atomic`

`TestIncrementIsAtomic` usa “atômico” no sentido de que cada incremento aparece como uma atualização indivisível da entrada: 100 goroutines resultam em 100. O código não importa nem usa `sync/atomic`; ele alcança essa propriedade com o `Lock` do shard cobrindo a invariante inteira.

`sync/atomic` é apropriado para operações simples sobre valores adequados e tem semântica mais restrita. Um mutex protege conjuntos de estado e suas relações — neste caso, leitura, expiração, cálculo e escrita do mapa. Não há uma operação `sync/atomic` no cache para mostrar; escolher `atomic` apenas por haver concorrência seria uma generalização incorreta.

## Channel de parada e `select`

O cache possui um channel real de sinalização:

```go
type Cache[Value any] struct {
	// outros campos omitidos
	stop chan struct{}
	once sync.Once
}

func New[Value any](ttl, sweepEvery time.Duration) *Cache[Value] {
	cache := &Cache[Value]{
		stop: make(chan struct{}),
	}
	go cache.janitor(sweepEvery)
	return cache
}
```

`chan T` descreve um canal capaz de transportar valores de `T`. Aqui o tipo é `chan struct{}`: um channel bidirecional cujo valor não carrega payload útil. `struct{}` representa uma struct vazia, de tamanho zero; para este contrato, o evento relevante é “pare”, não um dado. Isso o torna um **channel de sinalização**, diferente de um channel de dados que transportaria valores de trabalho.

O código não envia valores para `stop`. O janitor só recebe, com `<-cache.stop`, e `Close` fecha o channel. Um receive pode ser usado apenas como sinal porque a comunicação — neste caso, o fechamento — é o que importa.

Origem: `pkg/memcache/memcache.go`:

```go
for {
	select {
	case <-ticker.C:
		// limpeza
	case <-cache.stop:
		return
	}
}
```

```text
                 janitor
                    │
                 select
                /      \
        <-ticker.C    <-stop
             │           │
          cleanup       return
```

Um `select` sem `default` bloqueia enquanto nenhum case puder prosseguir. Um tick torna o primeiro case pronto; fechar `stop` torna o segundo case pronto. Se mais de um case estiver pronto, o runtime escolhe um dos cases prontos; não é necessário assumir uma política de fairness para entender este cache.

## Fechamento e ownership

Fechar um channel não é enviar um valor especial: muda o estado do channel. Receives em um channel fechado podem prosseguir imediatamente; na forma completa, `value, ok := <-ch`, `ok` informa se houve valor enviado antes do fechamento. Esse padrão não aparece no cache porque `case <-cache.stop` só precisa detectar o sinal e retornar.

A pergunta “quem pode fechar `stop`?” tem resposta no código: o `Cache` é dono do channel, pois o cria em `New`, guarda-o como campo não exportado e o fecha dentro de `Close`.

```go
func (cache *Cache[Value]) Close() error {
	cache.once.Do(func() {
		close(cache.stop)
	})
	return nil
}
```

Fechar o mesmo channel duas vezes causa panic. `sync.Once` executa a função de fechamento somente uma vez, inclusive se `Close` for chamado repetidamente. Um channel `nil` bloquearia para sempre em send ou receive simples e, em um `select`, seu case ficaria desabilitado; esta implementação cria `stop` com `make`, portanto ele não é nil.

## Janitor, TTL e ticker

TTL é verificado de duas formas reais. `Get` aplica expiração preguiçosa: devolve `false` para uma entrada expirada, mas não a remove do mapa. O janitor faz limpeza em background para remover fisicamente entradas expiradas.

```text
New → goroutine janitor → ticker.C → varredura dos shards → Close → retorno
```

Origem: `pkg/memcache/memcache.go`:

```go
func (cache *Cache[Value]) janitor(every time.Duration) {
	ticker := time.NewTicker(every)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			// percorre shards, bloqueia cada um e remove entradas expiradas
		case <-cache.stop:
			return
		}
	}
}
```

O `time.Ticker` entrega eventos periódicos em `Ticker.C`. `ticker.Stop()` interrompe ticks futuros; não fecha `Ticker.C` para avisar o consumidor. Neste código, `close(cache.stop)` sinaliza receivers de outro channel. O `defer ticker.Stop()` liga o fim da goroutine ao fim do ticker. `defer shard.mu.Unlock()` é usado em `SetTTL` e `Increment` para liberar o lock em qualquer retorno; no laço do janitor, o `Unlock` é explícito para liberar cada shard antes do próximo.

Janitor é uma estratégia de implementação, não propriedade obrigatória de todo cache. Nesta implementação ele evita que entradas já inválidas para `Get` permaneçam indefinidamente nos mapas.

## Ownership, `Close` e goroutine leaks

O lifecycle efetivo é `New → cria stop → inicia janitor → select aguarda ticker ou stop → Close → fecha stop → janitor observa stop → retorna`. `New` cria tanto o cache quanto a goroutine do janitor. Portanto, quem possui o cache precisa chamar `Close` quando não for mais usá-lo. `Close` usa `sync.Once` para fechar `stop` uma única vez, evitando panic por fechar um channel repetidamente.

Não há `WaitGroup`, channel de confirmação nem outro mecanismo para esperar a goroutine terminar; assim, `Close` sinaliza o encerramento, mas não confirma ao chamador que o janitor já retornou. `stop` significa “pare”; um `WaitGroup` serviria conceitualmente para “espere terminar”. Os testes usam `sync.WaitGroup` para aguardar as goroutines de incremento e acesso concorrente, mas o cache não o usa para seu lifecycle. Também não há teste específico para chamadas repetidas de `Close`; os testes usam `defer cache.Close()` para liberar o recurso criado.

Se um owner abandonar um recurso que iniciou uma goroutine sem estratégia de parada, a goroutine pode continuar esperando e se tornar um goroutine leak. O código não demonstra esse vazamento: ele fornece `Close` e `stop` justamente como estratégia de encerramento. O risco permanece para quem não chama `Close`.

## Testes e race detector

`pkg/memcache/memcache_test.go` é black-box e exercita a API exportada:

| Teste | O que observa | O que não prova |
|---|---|---|
| `TestSetGet` | escrita e leitura | concorrência ou expiração |
| `TestExpiration` | `Get` rejeita valor após o TTL | remoção física pelo janitor |
| `TestIncrementIsAtomic` | 100 incrementos concorrentes chegam a 100 | todas as interleavings possíveis |
| `TestConcurrentAccessAcrossShards` | `Set` e `Get` concorrentes em 50 chaves | que cada goroutine use shard distinto |
| `TestJanitorEvictsExpired` | a varredura remove 100 entradas | término confirmado após `Close` |

No Dev Container, execute:

```bash
go test -race ./pkg/memcache
go test -race ./...
```

O race detector instrumenta acessos à memória e encontra conflitos que ocorrem nos caminhos realmente executados, com overhead esperado. Uma execução sem alerta significa que nenhum data race foi observado nesses caminhos; não é prova matemática de ausência de races. Veja também [Testes e tooling](../08-testes/index.md).

## Escopo de channels neste laboratório

O cache cobre um channel de sinalização, `close`, receive, bloqueio e `select` com dois cases reais. Não cobre channels de dados, fan-in, fan-out, worker pools, pipelines, semáforos ou coordenação entre serviços. Channels são outra ferramenta de coordenação entre goroutines e serão aprofundados no próximo componente real que os utilizar. A frase “share memory by communicating” não proíbe mutexes: Go oferece ambas as ferramentas, e locks são diretos e apropriados para o estado compartilhado deste cache.

## Próximo passo

Revise [Fundamentos](../01-fundamentos/colecoes-fluxo.md) para `map`, struct e ponteiros, e [Cache](../12-cache/index.md) para TTL. `context.Context` será aprofundado quando existir uma cadeia real de operações canceláveis entre serviços.
