# Generics em Go

## Onde esta aula entra no curso

Módulo **01 — Go na Prática**, aula **01**. Pré-requisitos: funções, tipos, slices, maps e interfaces simples. A aula abre o percurso porque três mecanismos reutilizáveis que virão depois — FSM, cache e batcher — preservam tipos sem conhecer pagamentos ou fraude.

!!! success "Implementado no checkout atual"
    [`pkg/fsm/fsm.go`](../../estudo-go/05-generics/machine-generica.md), `pkg/memcache/memcache.go` e `pkg/batch/batch.go` declaram tipos genéricos reais. A montagem do pipeline de fraude mostrada em alguns exemplos do deck ainda não existe.

## O problema que motiva a aula

Imagine um cache de `int` para contadores e outro de `string` para geolocalização. Copiar duas implementações de expiração e sincronização só para mudar o tipo do valor duplica bugs. Trocar tudo por `any` em campos e retornos evita a cópia, mas exige *type assertions* na borda; uma assertion incorreta pode causar `panic` em execução. O parâmetro de tipo deixa o algoritmo único e preserva a checagem estática do valor.

## Modelo mental

Uma função ou tipo genérico é uma receita que declara quais tipos o chamador pode fornecer. A *constraint* delimita as operações que o corpo da receita pode usar. Ao instanciar `Cache[int]`, a API de `Get` continua devolvendo `int`; ao instanciar `Cache[string]`, devolve `string`. `any` dentro de `[V any]` é uma constraint ampla, não um convite a armazenar tudo como `any` e fazer assertions depois.

```go
type Caixa[T any] struct{ valor T }

func (c Caixa[T]) Get() T { return c.valor }
```

Este é um **exemplo mínimo**, não código do repositório. Os colchetes declaram `T`; o `T` em campo e retorno mantém a relação de tipos até o chamador.

## Conceitos apresentados

- **Parâmetro de tipo**: `T` em `func Min[T ...]` ou `type Cache[V any]` representa um tipo escolhido na instanciação, não um valor.
- **Constraint**: `any` aceita qualquer tipo; `comparable` permite chaves de map e comparações de igualdade, mas não ordenação. Uma union como `~int | ~int64` é um *type set* útil quando o corpo precisa de operadores numéricos.
- **`~`**: inclui tipos definidos cujo tipo subjacente é o indicado. Assim, `type Centavos int64` satisfaz `~int64`, mas não o termo exato `int64`.
- **Inferência**: o compilador pode omitir argumentos de tipo quando os argumentos da função os revelam. Se `T` aparece apenas no retorno, como em `New[T](...)` de alguns packages, o chamador normalmente precisa escrever `[T]`.
- **Interfaces versus generics**: uma interface modela comportamento por métodos; generics servem quando a estrutura ou o algoritmo é o mesmo para tipos distintos. Não substituir uma porta de domínio por parâmetro de tipo só porque é possível.

O `Min[T constraints.Ordered]` do slide usa `golang.org/x/exp/constraints` como exemplo histórico. Na baseline declarada em `go.mod` (**Go 1.26.4**), a stdlib já oferece [`cmp.Ordered`](https://pkg.go.dev/cmp#Ordered) para esse caso; não é necessária uma nova dependência `x/exp`. `cmp.Ordered` também não é usado pelos três mecanismos do projeto, que só precisam de `any`. A [especificação de Go](https://go.dev/ref/spec#Interface_types) define com precisão type sets, `comparable` e `~`.

## O que o professor está construindo

O objetivo não é uma biblioteca genérica abstrata. É ter um motor de estados que receba qualquer payload, um cache cujo valor tenha tipo conhecido e um agrupador com tipos de entrada e saída independentes. A mesma API serve ao caso de uso sem que `pkg/` importe o domínio de pagamentos.

## Código apresentado na aula

Trechos **atuais** (assinaturas resumidas dos arquivos citados):

```go
type Handler[Data any] func(context.Context, *Data) (State, error)
type Machine[Data any] struct { /* configuração da máquina */ }
type Cache[V any] struct { /* shards e TTL */ }
type Batcher[In any, Out any] struct { /* fila e flusher */ }
```

`Data` é o payload que atravessa os estados; `V` é o valor armazenado, enquanto a chave do cache continua `string`; `In` e `Out` separam os formatos submetido e devolvido. O uso de `fsm.New[scoringData](...)` num `internal/fraud/usecase/pipeline.go` é **código da aula / arquitetura futura**: esse arquivo não existe no checkout.

## Como isso aparece no projeto hoje

| Situação | Evidência | Limite |
|---|---|---|
| **IMPLEMENTADO** | `pkg/fsm/fsm.go`, `pkg/memcache/memcache.go`, `pkg/batch/batch.go` e seus testes | Os motores são independentes do domínio. |
| **PARCIAL** | `internal/fraud/domain/` contém features e regras | Ainda não compõe os motores num pipeline. |
| **PLANEJADO** | Chamada genérica ao scorer e ao pipeline mostrada no slide | `internal/fraud/usecase/pipeline.go` não existe. |

Não há benchmark no deck que prove que generics tornem esse código mais rápido do que uma interface em toda situação. Aqui a vantagem verificável é a API tipada e a reutilização do mecanismo.

## Padrões de projeto e arquitetura

Os três packages exemplificam **separação entre mecanismo e política**: controlam transições, TTL e janelas, mas não decidem o significado de um pagamento. Essa é uma escolha de desenho, não um padrão GoF automático. Portas de serviço continuam sendo interfaces pequenas quando representam comportamento variável de infraestrutura.

## Trade-offs

| Ganho | Custo | Por que aceitar aqui |
|---|---|---|
| Menos duplicação e tipos preservados no chamador | Assinaturas e mensagens de compilação podem ficar mais complexas | Os três motores têm reutilização genuína entre tipos. |
| Sem assertions na API do valor | Constraints complexas podem acoplar demais os chamadores | Os motores atuais usam `any` e deixam política fora de `pkg/`. |

## Relação com os ADRs

Não há ADR que determine a sintaxe de generics. O [ADR 0005](../../adr/0005-fsm-with-deterministic-fallback.md) decide o fluxo de fallback da FSM; generics são o mecanismo para expressá-la independentemente do payload. O [ADR 0008](../../adr/0008-in-process-caches-over-redis.md) decide cache local, não o tipo concreto armazenado.

## Aprofunde no tutorial

Comece por [5. Generics](../../estudo-go/05-generics/index.md), depois [Lendo a máquina genérica](../../estudo-go/05-generics/machine-generica.md). Para distinguir interfaces de parâmetros de tipo, veja [Interfaces](../../estudo-go/03-interfaces/index.md). A [FSM](../03-fsm/maquina-estados-finita.md) e o [batcher](../05-batching/dynamic-batching.md) retomam esses tipos no contexto da aula.

## Artigos do professor relacionados

[Go Idiomático](../../artigos-completos/pt/go-idiomatic-code.md) complementa o cuidado com assertions e APIs legíveis. É leitura pedagógica; a sintaxe e o comportamento de generics vêm da documentação oficial, e o estado do projeto vem dos arquivos e testes.

## Documentação oficial

Consulte o [tutorial de generics](https://go.dev/doc/tutorial/generics), a [especificação](https://go.dev/ref/spec#Type_parameter_declarations) e [When To Use Generics](https://go.dev/blog/when-generics) para decidir quando a abstração ajuda.

## Perguntas para revisão

1. Por que um `Cache` que devolve `any` desloca o erro para runtime?
2. Qual operação exige `comparable`, e por que `any` não basta para a chave de um map genérico?
3. O que `~int64` aceita que `int64` sozinho não aceita?
4. Por que `Batcher[In, Out]` tem dois parâmetros de tipo?
5. Quando o compilador pode inferir `T`, e por que `New[T]` pode exigir argumento explícito?
6. Qual problema de arquitetura surge se `pkg/fsm` importar tipos de `fraud`?

## Checklist

- [ ] Identifico parâmetro de tipo, constraint e tipo concreto na chamada.
- [ ] Distingo `any` como constraint de um campo armazenado como `any`.
- [ ] Verifiquei as três declarações genéricas reais no checkout.
- [ ] Não confundo exemplo de integração futura com código de produção atual.
