# Dynamic Batching

## Onde esta aula entra no curso

Módulo **05 — pkg/batch**, aula **01 — teoria**. A aula vem depois das bases de [Generics](../01-go-na-pratica/generics-em-go.md), goroutines, channels e `select`: agora esses recursos coordenam um mecanismo reutilizável de agregação. O [tutorial de concorrência](../../estudo-go/06-concorrencia/batcher.md) acompanha a leitura linha a linha do package.

!!! warning "Batcher implementado; uso no scorer é futuro"
    `pkg/batch/batch.go` e testes existem. A chamada ao scorer em `internal/fraud/usecase/pipeline.go`, mostrada como destino do motor no slide, ainda não existe; não há `Flusher` de fraude em produção neste checkout.

## O problema que motiva a aula

Quando cada autorização invoca o scorer isoladamente, cada chamada paga custos fixos de coordenação e preparação. Se muitas chegam quase juntas, pode ser mais eficiente processá-las em um lote. Mas esperar um lote cheio para sempre travaria tráfego baixo. A pergunta de projeto é: **quando despachar, e como devolver a cada chamador só a sua resposta?**

## Modelo mental

Um `Submit` representa uma requisição individual. O batcher a coloca numa fila e espera a resposta num canal próprio. Uma goroutine de loop mantém o lote corrente. O primeiro item inicia uma janela; o lote fecha ao atingir `maxSize`, vencer `maxWait` ou encerrar o batcher. O `Flusher` processa o slice e devolve um resultado por posição.

```text
Submit A ─┐                      ┌─ resposta A
Submit B ─┼─ fila → lote → Flusher ┼─ resposta B
Submit C ─┘                      └─ resposta C
               tamanho OU tempo
```

O contrato de posição importa: `results[i]` pertence ao pedido `batch[i]`. Se o flusher devolver quantidade diferente de resultados, o código atual transforma isso em erro para todo o lote, em vez de deslocar respostas silenciosamente.

## Conceitos apresentados

- **`Batcher[In, Out]`** separa entrada e saída sem embutir scoring no package.
- **`Flusher[In, Out]`** recebe `context.Context` e `[]In`, devolvendo `[]Out` e `error`.
- **`maxSize`** fecha um lote assim que há itens suficientes; `New` normaliza valores menores que 1 para 1.
- **`maxWait`** conta a partir do primeiro item do lote corrente. A escolha expressa um orçamento de espera, não uma garantia de latência total do `Submit`.
- **Fila com channel**: o buffer atual tem capacidade `4*maxSize`; isso absorve rajadas, mas não é ilimitado.
- **`select` e timer**: o loop escolhe entre nova requisição e expiração; em Go, quando mais de um caso está pronto, a escolha não deve ser tratada como prioridade fixa.
- **`WaitGroup` e `Close`**: o construtor inicia um loop e soma um worker; `Close` fecha a fila e espera esse loop terminar.

## O que o professor está construindo

Uma API que, para o chamador, ainda parece síncrona: `Submit(ctx, item)` devolve o `Out` daquele item. O agrupamento fica interno e pode ser aplicado a um flusher concreto de ML ou outra operação que realmente ganhe ao receber vários itens. A política de *qual* trabalho agrupar fica fora de `pkg/batch`.

## Código apresentado na aula

Contrato **atual** de `pkg/batch/batch.go`:

```go
type Flusher[In any, Out any] func(context.Context, []In) ([]Out, error)

func New[In any, Out any](maxSize int, maxWait time.Duration,
    flush Flusher[In, Out]) *Batcher[In, Out]

func (b *Batcher[In, Out]) Submit(ctx context.Context, item In) (Out, error)
func (b *Batcher[In, Out]) Close()
```

O exemplo do slide que liga `batch.New(...)` ao `TreeModel.Score` é **código da aula / arquitetura futura**. O arquivo `internal/fraud/usecase/pipeline.go` e o scorer não existem neste checkout.

O loop **atual** despacha de modo síncrono: chama `dispatch`, que chama o `Flusher`, e só então volta a ler a fila. Portanto janelas **não se sobrepõem** nesta implementação, apesar de um comentário em `Flusher` sugerir que ele deva ser seguro para chamadas concorrentes. Essa precaução não é prova de paralelismo real no código atual.

## Como isso aparece no projeto hoje

| Situação | Evidência | Limite |
|---|---|---|
| **IMPLEMENTADO** | `pkg/batch/batch.go` e testes externos/internos | Flush por tamanho ou tempo, resultado por posição, cancelamento de `Submit`, erros e fechamento. |
| **IMPLEMENTADO** | `Close` fecha a fila e aguarda o loop | Itens já enfileirados são drenados, inclusive o lote pendente; o fechamento pode esperar o `Flusher` terminar. |
| **PLANEJADO** | Pipeline de fraude e scorer | Nenhum consumidor de produção do batcher está presente. |

Há dois limites de cancelamento. Antes de enfileirar, `Submit` observa `ctx.Err()`; durante envio e espera de resposta, também pode retornar `ctx.Err()`. Porém um item já aceito pode continuar sendo processado após o chamador desistir. `dispatch` passa `context.Background()` ao `Flusher`, não o contexto de um pedido individual. Isso evita escolher arbitrariamente o prazo de um chamador para todo o lote, mas requer uma política própria se o trabalho do flusher puder bloquear indefinidamente.

## Padrões de projeto e arquitetura

O mecanismo é **micro-batching por tamanho ou tempo** e segue uma relação **producer–consumer / aggregator**: múltiplos produtores enviam, um loop reúne e despacha. Esses nomes descrevem o fluxo; não são GoF. O `Flusher` é uma função injetada que separa mecanismo de processamento concreto.

## Trade-offs

| Ganho | Custo | Por que aceitar aqui |
|---|---|---|
| Menos chamadas downstream para cargas agrupáveis | Item isolado espera até `maxWait` | O lote pode amortizar custo fixo se medido no workload real. |
| API síncrona simples para cada chamador | Fila e goroutine exigem lifecycle e backpressure | O package encapsula a coordenação, sem fazê-la vazar ao consumidor. |
| Fechamento com draining | `Close` pode bloquear enquanto o flusher roda | Não abandonar requisições aceitas é parte do contrato atual. |

O slide ensina o trade-off **throughput versus latency**; ele não fornece benchmark reproduzível neste checkout que prove melhora de throughput no pipeline de fraude. `maxSize` e `maxWait` são parâmetros a medir, não números universais.

## Relação com os ADRs

O [ADR 0004](../../adr/0004-native-tree-inference-in-go.md) decide inferência nativa no processo de fraude. O batcher pode servi-la, mas sua existência isolada não implementa o scorer nem valida os números de inferência citados no ADR. A integração futura deve respeitar a decisão sem transformar números históricos em garantia atual.

## Aprofunde no tutorial

Veja [8. Concorrência](../../estudo-go/06-concorrencia/index.md), [Canais de dados e batcher](../../estudo-go/06-concorrencia/batcher.md), [9. Context](../../estudo-go/07-context/index.md), [17. Performance](../../estudo-go/17-performance/index.md) e [Testes](../../estudo-go/08-testes/index.md).

## Artigos do professor relacionados

[A Maioria dos Serviços em Go Não Precisa Ser Concorrente](../../artigos-completos/pt/go-concorrencia-prematura-problemas.md) provoca a pergunta certa — qual custo o lote amortiza? [Por que o `context.Context` é o sistema nervoso do Go moderno](../../artigos-completos/pt/context-nervous-system-go.md) aprofunda cancelamento. As medições desses textos pertencem aos seus próprios workloads, não ao batcher deste checkout.

## Documentação oficial

A [especificação de `select`](https://go.dev/ref/spec#Select_statements), a API de [`time.Timer`](https://pkg.go.dev/time#Timer), [`sync.WaitGroup`](https://pkg.go.dev/sync#WaitGroup) e [`context.Context`](https://pkg.go.dev/context#Context) ajudam a verificar os contratos de janela, encerramento e cancelamento.

## Perguntas para revisão

1. Por que o primeiro item precisa iniciar um timer?
2. O que acontece quando `maxSize` é atingido antes de `maxWait`?
3. Como o resultado do índice `i` volta ao `Submit` correto?
4. O que ocorre se o flusher devolver menos resultados que pedidos?
5. Um `Submit` cancelado garante que seu item não será processado?
6. Por que `Close` pode demorar mesmo depois de fechar a fila?
7. Janelas de flush são processadas em paralelo neste checkout?

## Checklist

- [ ] Distingo limite por tamanho de limite por tempo.
- [ ] Localizei fila, loop, timer, dispatch e draining no código.
- [ ] Sei explicar cancelamento do chamador versus contexto do flusher.
- [ ] Não afirmo ganho de performance sem benchmark da integração real.
