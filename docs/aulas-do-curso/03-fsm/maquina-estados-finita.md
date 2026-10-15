# Máquina de Estados Finita

## Onde esta aula entra no curso

Módulo **03 — pkg/fsm**, aula **01 — teoria**. Depois de [Generics em Go](../01-go-na-pratica/generics-em-go.md), a aula usa um mecanismo genérico para dar nome e observabilidade às etapas de uma decisão de fraude. Ajuda conhecer funções, maps, `context.Context` e `error`; o [tutorial de FSM](../../estudo-go/11-fsm/index.md) aprofunda a leitura do código.

!!! warning "Mecanismo implementado, pipeline parcial"
    `pkg/fsm/fsm.go` e testes existem. O pipeline `enrich → fast_rules → ml_score → ...` que a aula usa para motivar o motor ainda não está configurado em `internal/fraud/usecase/pipeline.go`: esse arquivo não existe. As regras isoladas em `internal/fraud/domain/` não equivalem a uma pipeline de serviço.

## O problema que motiva a aula

Uma autorização de fraude precisa passar por enriquecimento, regras rápidas, modelo e finalização. Em chamadas aninhadas ou numa sequência de `if`s, é fácil perder de vista quais saltos são legais, quanto custou cada etapa e o que acontece se o modelo falhar. O problema não é a sintaxe do `if`, mas a política de transição escondida no fluxo de controle.

## Modelo mental

Uma FSM tem um conjunto finito de **estados** nomeados. Cada estado não terminal possui um **handler** que recebe os dados da execução e devolve o próximo estado. O motor mantém o estado atual e registra cada salto. Estados **terminais** encerram a execução; um **fallback** é uma rota declarada para erro de um handler específico.

```text
estado atual → handler(ctx, dados) → próximo estado
                    │
                    └── erro → trace com erro → fallback ou aborto
```

No projeto, `Machine[Data]` guarda a **topologia compartilhada**; o payload `*Data` guarda o **estado mutável de cada execução**. A máquina pode ser construída uma vez e reutilizada, desde que sua configuração não seja alterada enquanto outras goroutines a executam e os dados de cada `Run` sejam independentes.

## Conceitos apresentados

- `State` é um identificador textual, não a lógica de negócio.
- `Handler[Data]` é uma função `func(context.Context, *Data) (State, error)`; ela executa uma etapa e escolhe o próximo nó.
- `Terminal(...)` registra estados de saída, que dispensam handler próprio quando alcançados como `next`.
- `Transition` registra `From`, `To`, `Duration` e `Err` para cada handler chamado. O trace é evidência da execução, não um substituto para métricas agregadas.
- `WithMaxHops[Data](n)` limita o número de saltos; o padrão de `New` é 32. Um ciclo ou caminho sem terminal produz erro ao exceder o limite.
- `FallbackTo(estado, destino)` só entra quando o handler daquele estado retorna erro. Sem fallback registrado, `Run` aborta e devolve o erro com contexto.

O `Run` também checa `ctx.Err()` antes de cada handler. Isso impede iniciar o próximo salto com um contexto já cancelado, mas um handler que ignore o contexto pode continuar além do prazo; cancelamento em Go é cooperativo.

## O que o professor está construindo

Primeiro, um motor que desconhece fraude; depois, uma composição de handlers nomeados para o pipeline. A decisão de marcar revisão manual em falha do modelo é **política de domínio** a ser feita pelo handler ou pelo caso de uso, não uma propriedade automática de `FallbackTo`.

## Código apresentado na aula

Trechos **atuais** de `pkg/fsm/fsm.go`, reduzidos ao contrato central:

```go
type Handler[Data any] func(context.Context, *Data) (State, error)

type Transition struct {
    From, To State
    Duration time.Duration
    Err error
}

machine := fsm.New[payload]("start").
    Handle("start", startHandler).
    Terminal("done")
```

O último bloco é **exemplo didático de composição**, não declaração existente no código de produção. Os métodos `New`, `Handle`, `Terminal`, `FallbackTo` e `Run` estão implementados; os testes exercitam caminho feliz, fallback e erro sem fallback.

Há uma nuance útil para quem investiga traces: quando um handler falha, `Transition.To` preserva o `next` que o handler retornou, enquanto a máquina altera internamente `current` para o fallback. Assim, o trace registra erro e retorno original; o destino de fallback é inferido da configuração e do próximo salto, não reescrito naquele registro.

## Como isso aparece no projeto hoje

| Situação | Evidência | Limite |
|---|---|---|
| **IMPLEMENTADO** | `pkg/fsm/fsm.go` e `pkg/fsm/fsm_test.go` | Máquina, trace, contexto, limite e fallback genéricos. |
| **PARCIAL** | `internal/fraud/domain/features.go` e `rules.go` | Domínio de fraude ainda sem orquestração de estados. |
| **PLANEJADO** | `internal/fraud/usecase/pipeline.go` do slide | Arquivo e ligação ao serviço não existem. |

## Padrões de projeto e arquitetura

Isto é uma **Finite State Machine** explícita: o motor consulta um map de handlers e recebe nomes de próximo estado. Não é automaticamente o padrão GoF **State**, que normalmente representa comportamentos por objetos de estado intercambiáveis. Também não é uma estratégia de tolerância a falhas completa; a FSM só oferece o ponto de escape e o registro do erro.

## Trade-offs

| Ganho | Custo | Por que aceitar aqui |
|---|---|---|
| Topologia legível e fallback declarado | Mais indireção que uma função linear | Há ramificações e modos degradados a auditar. |
| Trace por salto com duração e erro | Alocação de slice e custo de medição | Observabilidade do caminho de decisão é requisito do ADR. |
| Limite de hops | Um caminho legítimo muito longo pode ser cortado | Preferível a um loop sem limite no caminho síncrono. |

## Relação com os ADRs

O [ADR 0005](../../adr/0005-fsm-with-deterministic-fallback.md) decide que `ml_score` deve cair em `finalize` e que a tentativa seja marcada como degradada para revisão manual antes de retornar erro. O `pkg/fsm` implementa o mecanismo de fallback, **não** a marcação de negócio. A integração futura deve convergir para o ADR, não alterar o ADR para caber no código incompleto.

## Aprofunde no tutorial

Leia [7. FSM](../../estudo-go/11-fsm/index.md), [Interfaces na FSM](../../estudo-go/03-interfaces/interfaces-na-fsm.md), [Erros e fallback](../../estudo-go/04-erros/fsm-erros.md), [Lendo a máquina genérica](../../estudo-go/05-generics/machine-generica.md) e [Testando a FSM](../../estudo-go/08-testes/testando-fsm.md). Cada capítulo aprofunda apenas uma dimensão da máquina.

## Artigos do professor relacionados

[Erros em Go: `errors.Is`, `errors.As` e wrapping](../../artigos-completos/pt/go-erros-errors-is-as-wrapping-sentinel.md) ajuda a entender por que `Run` envolve o erro do handler com `%w` e preserva a causa. O artigo não comprova o pipeline de fraude.

## Documentação oficial

As garantias de cancelamento e `Err` estão em [`context`](https://pkg.go.dev/context); a inspeção de erros envolvidos está em [`errors`](https://pkg.go.dev/errors). Consulte-as quando o tratamento de timeout ou sentinel importar.

## Perguntas para revisão

1. Por que estado e handler são coisas diferentes?
2. O que acontece se o próximo estado não for terminal e não tiver handler?
3. Onde o erro original fica preservado quando há fallback?
4. Quem marca a decisão como degradada: `pkg/fsm` ou o caso de uso?
5. O que `maxHops` protege e o que ele não garante?
6. Por que essa implementação não é necessariamente o GoF State Pattern?
7. O que acontece se um handler não cooperar com o contexto cancelado?

## Checklist

- [ ] Consigo traçar um caminho feliz e um caminho com fallback.
- [ ] Distingo mecanismo genérico de política antifraude.
- [ ] Verifiquei o estado atual em código e testes, sem assumir que o pipeline existe.
- [ ] Sei onde localizar duração, erro e próximo estado no trace.
