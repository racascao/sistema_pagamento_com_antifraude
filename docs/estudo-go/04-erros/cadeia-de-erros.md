# Modelo e cadeia de erros

## O que você vai aprender

Partir de um retorno `(valor, error)`, reconhecer uma sentinela, adicionar contexto preservando a causa e escolher entre `errors.Is`, `errors.As` e `errors.AsType`. O fallback ficará para o [capítulo seguinte](fsm-erros.md).

## Onde isso aparece no projeto

Origem: `pkg/fsm/fsm.go`:

```go
var ErrNoTransition = errors.New("fsm: no transition registered for state")

handler, ok := machine.handlers[current]
if !ok {
	return trace, fmt.Errorf("%w: %q", ErrNoTransition, current)
}
```

Origem: `pkg/fsm/fsm_test.go`: `TestErrorWithoutFallbackAborts` verifica a identidade de um erro de handler. Ainda não há erros de domínio de pagamentos nem adapters HTTP/gRPC em Go.

## O problema

Se um estado não tem handler, `Run` precisa dizer **que categoria** de falha ocorreu e **em qual estado**. Um texto completo atende o diagnóstico humano, mas o chamador precisa decidir por identidade, mesmo que outra camada acrescente contexto.

## Modelo mental e sintaxe de Go

Uma função devolve resultado e `error`; o chamador decide o que fazer:

```text
função → (trace, error) → chamador verifica → devolve, recupera ou traduz
```

`error` é uma interface da biblioteca padrão com método `Error() string`. `errors.New` cria um valor que a satisfaz; quando não houve falha, retorna-se `nil`. `ErrNoTransition` é uma sentinela exportada: representa uma categoria reconhecível. O estado particular é detalhe contextual do wrapping, não uma nova sentinela para cada chave.

## Cadeia de erros

```text
ErrNoTransition (causa)
    ↓ fmt.Errorf("%w: %q", causa, estado)
erro de Run com contexto do estado
    ↓ eventual fmt.Errorf("...: %w", err) em camada futura
erro com mais contexto
    ↓ errors.Is(err, ErrNoTransition)
categoria reconhecida sem comparar frases
```

`%w` cria um wrapper que expõe a causa por `Unwrap`. `errors.Is` percorre a cadeia; também pode respeitar métodos `Is` específicos. `fmt.Errorf("...: %v", err)` preserva o **texto**, mas não a relação de causa: depois disso `errors.Is` não encontraria a sentinela. `err == ErrNoTransition` também não encontra a sentinela quando `err` é o wrapper. Compare mensagens apenas se o texto em si for parte explícita do contrato; para classificar falhas, textos variam com contexto e redação.

Origem: `pkg/fsm/fsm.go`:

```go
if !hasFallback {
	return trace, fmt.Errorf("fsm: handler at %q: %w", current, err)
}
```

Aqui a causa é o erro devolvido pelo handler. Origem: `pkg/fsm/fsm_test.go`:

```go
if !errors.Is(err, boom) {
	t.Fatalf("errors.Is(Run() error, boom) = false, error = %v", err)
}
```

O teste demonstra a propriedade observável: o chamador ainda reconhece `boom` após `Run` acrescentar o estado.

## `errors.As`, `errors.AsType` e `errors.Join`

`errors.Is` responde “esta causa específica está na cadeia?”. `errors.As` responde “existe na cadeia um erro atribuível a este **tipo**?” e escreve o resultado em um ponteiro fornecido pelo chamador. `errors.AsType[E]` (disponível desde Go 1.26) devolve `(E, bool)` sem parâmetro de saída; a versão `go 1.26.4` do projeto permite seu uso, mas o código atual não o usa. [Documentação oficial de Go 1.26](https://go.dev/doc/go1.26) descreve essa API.

**Exemplo mínimo** (não há erro tipado próprio na FSM):

```go
var pathErr *os.PathError
if errors.As(err, &pathErr) {
	// consultar pathErr.Path
}

pathErr, ok := errors.AsType[*os.PathError](err)
```

**No payment-processor:** o caso presente é `ErrNoTransition`, para o qual `errors.Is` é a ferramenta certa. A FSM não expõe `*os.PathError`; o exemplo acima só contrasta busca por tipo e por identidade. `errors.Join` junta causas independentes em uma árvore de erros reconhecível por `Is`/`As`; um único handler falha por hop, então `Run` não precisa juntar causas.

## Quatro níveis que não devem ser confundidos

| Categoria | Exemplo neste checkout | Quem decide a tradução? |
|---|---|---|
| Erro de mecanismo | `fsm.ErrNoTransition` ou limite de hops em `Run` | Chamador do motor |
| Erro de domínio | Ainda não há sentinela de pagamentos implementada | Futuro domínio/usecase |
| Erro de infraestrutura | Ainda não há adapter Postgres/Kafka/gRPC com wrapping | Futuro adapter de infraestrutura |
| Erro de transporte | Ainda não há handler HTTP/gRPC que mapeie erro | Futuro adapter de transporte |

É regra de `AGENTS.md` preservar causas de infraestrutura com `%w` e reconhecer sentinelas de negócio com `errors.Is`. Essa política arquitetural não transforma `ErrNoTransition` em erro de negócio: ele pertence ao motor em `pkg/`.

## Por que foi feito assim, alternativas e armadilhas

Retornar apenas uma string perderia identidade; criar uma sentinela por estado multiplicaria contratos desnecessários. Um erro tipado seria útil se o chamador precisasse extrair campos estruturados, mas esse segundo uso não existe aqui. Um `error` pode conter um ponteiro tipado `nil` e ainda ser não nulo; [Interfaces](../03-interfaces/interfaces-na-fsm.md) explica o motivo. Wrapping correto não deve expor ao cliente externo detalhes internos indiscriminadamente: o mapeamento na borda ainda é trabalho futuro.

## Exercícios

- **Nível 1 — reconhecer:** localize `ErrNoTransition` e os dois usos de `%w` em `Run`.
- **Nível 2 — explicar:** por que `err == fsm.ErrNoTransition` não reconhece o erro devolvido para um estado sem handler?
- **Nível 3 — modificar:** em um rascunho, acrescente um wrapping externo a `Run` com `%w` e escreva uma asserção `errors.Is`.
- **Nível 4 — diagnosticar:** troque mentalmente `%w` por `%v` no retorno do handler. Qual teste deixaria de provar a identidade de `boom`?
- **Nível 5 — projetar:** quando surgir um erro tipado de infraestrutura com campos úteis, onde você o reconheceria com `As` e que informação evitaria expor ao cliente?

## Checklist

- [ ] Distingo valor de erro de texto de erro.
- [ ] Sei por que `%w` preserva a cadeia e `%v` não.
- [ ] Uso `errors.Is` para identidade e `As`/`AsType` para tipo.
- [ ] Sei que `errors.Join` não é necessário para esta execução da FSM.

## Próximo passo

Leia [Erros e fallback na FSM](fsm-erros.md) para ver como a política da máquina usa o erro sem torná-lo invisível; [Testes](../08-testes/testando-fsm.md) mostra como observar essa diferença.
