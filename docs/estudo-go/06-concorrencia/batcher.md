# Batcher: channels de dados e micro-batching

`pkg/batch/batch.go` é um laboratório real de batching com channels de dados. Ele recebe pedidos individuais e os libera em lote quando alcança `maxSize` ou quando passa `maxWait`.

## Problema e modelo mental

```text
request A ─┐
request B ─┼──> queue ──> coletor ──> [A B C] ──> Flusher
request C ─┘
```

Esse é batching; como acontece no caminho online, em lotes pequenos limitados por tempo, também pode ser chamado de micro-batching. São termos de engenharia, não um padrão GoF. O código é uma forma de **size-or-time batching**: o primeiro limite atingido libera o lote.

## API e tipos reais

Origem: `pkg/batch/batch.go`:

```go
type Flusher[In any, Out any] func(context.Context, []In) ([]Out, error)

type Batcher[In any, Out any] struct {
	maxSize int
	maxWait time.Duration
	queue   chan request[In, Out]
	wg      sync.WaitGroup
}
```

`Batcher[In, Out]` é um tipo genérico: cada pedido carrega `In`, e cada resposta espera `Out`. `request` associa o item a `resp chan result[Out]`, permitindo que a resposta do lote retorne ao caller correto. `New` normaliza `maxSize` para pelo menos 1 e cria uma fila com capacidade `maxSize*4`.

## Producer-consumer e agregação

`Submit` produz um `request` e o envia para `queue`; a goroutine `loop` recebe, acumula pedidos em `pending` e chama `dispatch`; `dispatch` invoca o `Flusher`. Essa topologia corresponde ao modelo producer-consumer e tem relação com o **Aggregator Pattern**: itens independentes são combinados para processamento conjunto. Não é um dos 23 padrões GoF.

A goroutine do loop é a dona prática de `pending` e do timer. Isso se parece com um event loop, mas o package não implementa nem declara um Actor Model: há mutex para coordenar `Submit` e `Close`, e o flusher é chamado diretamente pelo loop.

## Channels, bloqueio e backpressure

`queue` é um channel de dados bufferizado. Enviar com `batcher.queue <- req` pode prosseguir enquanto houver espaço; quando a fila está cheia, `Submit` bloqueia até haver espaço ou até `ctx.Done()` ficar pronto. Essa capacidade limitada é uma forma de backpressure: produtores mais rápidos desaceleram ou falham pelo contexto em vez de a fila crescer sem limite.

`resp` também é bufferizado, com capacidade 1. Se um caller cancelar depois de enfileirar o pedido, o dispatcher ainda consegue publicar uma resposta sem ficar preso em um send sem receiver.

## `select`: dois laboratórios, problemas distintos

No cache, `select` escolhe entre tick de limpeza e sinal de parada. No batcher, ele coordena pedido novo, timeout de lote e fechamento da fila:

```go
select {
case req, ok := <-batcher.queue:
	// coleta um pedido ou drena após Close
case <-timerC:
	// libera o lote pelo tempo
}
```

O timer só existe quando há pedidos pendentes. Ao chegar ao tamanho máximo, o lote é liberado imediatamente; ao vencer `maxWait`, um lote menor também é liberado. `TestBatchesBySize` e `TestFlushesByTimeWindow` isolam esses dois gatilhos com parâmetros deliberadamente distantes.

## Throughput e latência

Agrupar itens pode amortizar custo fixo de uma operação posterior, mas cada caller pode esperar pela formação do lote. `maxSize` limita o tamanho; `maxWait` limita a espera. Este pacote não tem consumidor de produção nem benchmark neste checkout, portanto a melhoria de throughput é uma hipótese de design, não uma medição do projeto.

## Lifecycle, cancelamento e erros

`New` executa `wg.Add(1)` antes de iniciar `go batcher.loop()`. `Close` marca o batcher como fechado, fecha `queue` e chama `wg.Wait()`. A fila fechada continua entregando seus itens bufferizados; quando o loop observa `ok=false`, ele para o timer, faz flush do lote pendente e retorna. Assim, `Close` solicita shutdown **e** espera a goroutine do loop terminar.

`Submit` verifica `ctx.Err()` antes de enfileirar e usa `ctx.Done()` tanto ao tentar entrar em uma fila cheia quanto ao aguardar a resposta. O `Flusher`, porém, recebe `context.Background()`: o cancelamento individual não é propagado para o processamento do lote. `TestContextCancelUnblocksCaller` cobre o retorno do caller cancelado; a resposta bufferizada impede que isso bloqueie o shutdown.

Erros do `Flusher` são devolvidos aos pedidos do lote. Se ele não retornar uma quantidade de resultados igual à de itens sem fornecer erro, `dispatch` cria um erro de contrato.

## Limites atuais

Não há consumidor em `cmd/` ou `internal/` que coloque este batcher diante de um scorer. A [Arquitetura](../../architecture.md) descreve esse uso e valores futuros, mas eles não são configuração efetiva deste package. O loop chama `dispatch` de forma síncrona, logo os flushes não se sobrepõem no código atual, apesar de o comentário de `Flusher` mencionar essa possibilidade.

## Exercícios

- Identifique as duas condições que liberam um lote.
- Explique por que fila limitada é backpressure, sem afirmar que ela resolve toda sobrecarga.
- Diferencie `Close` de cancelar o contexto de um único `Submit`.
- Descreva por que batching troca parte da latência individual por potencial throughput.

## Próximo passo

Compare este laboratório de channels de dados com o [janitor do cache](index.md) e consulte [Performance](../17-performance/index.md) para a diferença entre hipótese de otimização e benchmark.
