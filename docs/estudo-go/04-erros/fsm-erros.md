# Erros e fallback na FSM

## O que você vai aprender

Explicar `error`, sentinelas, wrapping com `%w`, `errors.Is`, retorno de trace e fallback. Ao final, você deve conseguir distinguir o erro original do handler da decisão do motor de continuar ou abortar.

Leia antes [Modelo e cadeia de erros](cadeia-de-erros.md) se `error` e `%w` ainda forem novos. Esta página examina a **política da FSM**, não redefine o modelo de erros de Go.

## Onde isso aparece no projeto

O comportamento está em `pkg/fsm/fsm.go`; `pkg/fsm/fsm_test.go` contém os casos `TestFallbackKeepsPipelineAvailable` e `TestErrorWithoutFallbackAborts`. O [ADR 0005](../../adr/0005-fsm-with-deterministic-fallback.md) descreve a razão da FSM, mas o pipeline de fraude propriamente dito ainda não foi montado em `cmd/fraud`.

## O problema

Um handler pode falhar. Para o motor compartilhado, a pergunta é: há uma rota configurada para continuar, ou devemos devolver a falha ao chamador? Em ambos os casos, quem diagnostica a execução precisa saber qual etapa falhou. Quando não há fallback, a causa original deve sobreviver ao contexto adicional adicionado pelo motor.

## Modelo mental

Um valor `error` representa uma falha observável. Uma sentinela dá identidade estável a uma categoria; uma mensagem sozinha não dá. Wrapping acrescenta contexto e conserva a causa. A FSM registra cada tentativa em um trace antes de decidir o próximo passo. Fallback é uma política de roteamento configurada para um estado, não uma operação que apaga a falha.

```text
erro do handler (valor Go)
    ├── sem fallback → trace + erro com %w → chamador
    └── com fallback → trace mantém Err → executa outro estado
```

**Erro ≠ fallback.** O erro informa o que falhou; o fallback decide a rota de execução. O primeiro é um mecanismo da linguagem e biblioteca padrão, o segundo é uma decisão de design desta FSM. Marcar uma autorização como degradada seria uma decisão de negócio futura, fora de `pkg/fsm`.

## Sintaxe de Go e código real

Origem: `pkg/fsm/fsm.go`:

```go
var ErrNoTransition = errors.New("fsm: no transition registered for state")

handler, ok := machine.handlers[current]
if !ok {
	return trace, fmt.Errorf("%w: %q", ErrNoTransition, current)
}
```

`errors.New` cria a sentinela. O mapa pode não ter handler para `current`; `%w` embute a sentinela no novo erro, enquanto `%q` acrescenta o estado envolvido. Quem recebe o erro pode usar `errors.Is(err, fsm.ErrNoTransition)`. Comparar textos seria frágil. Comparar com `==` depois do wrapping falharia.

Origem: `pkg/fsm/fsm.go`:

```go
transition := Transition{
	From:     current,
	To:       next,
	Duration: time.Since(startedAt),
	Err:      err,
}

trace = append(trace, transition)

if err != nil {
	fallback, hasFallback := machine.fallbacks[current]
	if !hasFallback {
		return trace, fmt.Errorf("fsm: handler at %q: %w", current, err)
	}
	current = fallback
	continue
}
```

O trace é gravado antes da decisão. Com fallback, a execução salta para o estado configurado e o erro do handler permanece em `Transition.Err`; a função pode terminar com `nil` se alcançar um terminal depois. Sem fallback, `Run` devolve o trace e um erro que preserva a causa via `%w`. O `To` da transição de falha é o valor devolvido pelo handler, não o destino do fallback; no teste esse valor é `""`. Portanto, o trace atual registra a tentativa, e é preciso observar o próximo `From` para ver o desvio.

Origem: `pkg/fsm/fsm_test.go`:

```go
if !errors.Is(err, boom) {
	t.Fatalf("errors.Is(Run() error, boom) = false, error = %v", err)
}
```

O teste black-box usa a API pública e prova que a identidade de `boom` chega ao chamador mesmo após o wrapping. O teste de fallback verifica `trace[1].Err != nil` e que o último estado visitado é `rules_only`.

## Como funciona por dentro

`error` é uma interface. Um wrapper criado por `fmt.Errorf` com `%w` expõe a causa por `Unwrap`; `errors.Is` percorre a cadeia (e também pode respeitar métodos `Is` personalizados). `errors.As` e, no Go 1.26 do projeto, `errors.AsType` procuram um tipo de erro na cadeia; o código atual não define um erro tipado para a FSM. `errors.Join` combinaria causas independentes, mas aqui cada falha de handler tem uma única causa e não exige junção. Não há tradução de erros para gRPC ou HTTP no código Go atual; ela deve acontecer no boundary quando os adapters existirem. Veja [Modelo e cadeia](cadeia-de-erros.md) para a diferença entre essas operações.

## Por que foi feito assim

`pkg/` deve ser independente do domínio de pagamentos. O motor sabe que um handler falhou, mas não decide se uma autorização vira revisão manual. Essa decisão de negócio pertence ao futuro pipeline de `fraud`, conforme [AGENTS.md e o mapa](../mapa-do-projeto.md). O [ADR 0005](../../adr/0005-fsm-with-deterministic-fallback.md) propõe degradação explícita; o pacote atual fornece a rota e o trace, sem marcar um `Decision` como degradado.

## Alternativas

- Retornar imediatamente em qualquer erro simplificaria `Run`, mas impediria um fallback configurado.
- Ignorar o erro ao fazer fallback deixaria o chamador sem evidência da etapa degradada; o trace o conserva.
- Criar um erro tipado para cada estado aumentaria a superfície sem um segundo uso real. A sentinela é suficiente para a ausência de transição.

## Armadilhas

- Se o erro do handler for comparado com `==` após `fmt.Errorf`, a comparação com o valor original não reconhece o wrapper; use `errors.Is`.
- O retorno `nil` de `Run` após fallback não significa que nenhum handler falhou. Inspecione `Transition.Err`.
- Um handler que devolva `nil` e `next=""` não ativa fallback; o motor procurará um handler para `""` no próximo hop.
- O código não valida que o alvo do fallback tenha handler. Se não tiver, o próximo hop retorna `ErrNoTransition`.
- Um `ctx` cancelado é verificado no início de cada hop. Se um handler bloquear ignorando o contexto, o motor não o interrompe por conta própria; veja [Context](../07-context/index.md).

## Go idiomático

Use `fmt.Errorf("...: %w", err)` ao acrescentar contexto a uma falha que o chamador deve identificar. Use sentinela para uma categoria de erro que seja contrato público, não para cada frase de log. Teste identidade com `errors.Is`; teste tipo com `errors.As` ou `errors.AsType` quando existir erro tipado. A [seção Go moderno](../18-go-moderno/index.md) situa `AsType` na versão do projeto.

## Exercícios

- **Nível 1 — reconhecer:** localize os dois caminhos em `Run` que devolvem erro antes de chamar o handler.
- **Nível 2 — explicar:** por que o trace pode conter `Transition.Err != nil` quando `Run` devolve `nil`?
- **Nível 3 — modificar:** em branch de estudo, estenda o teste table-driven do happy path com uma verificação de `From` e `To`.
- **Nível 4 — diagnosticar:** configure fallback para um estado sem handler. Qual erro retorna? Quantas transições foram registradas?
- **Nível 5 — projetar:** onde ficaria a decisão de marcar uma autorização como “degradada”, sem fazer `pkg/fsm` conhecer pagamentos?

Execute `go test ./pkg/fsm` no Dev Container. Estes testes não requerem Postgres, Kafka nem serviços ativos.

## Checklist

- [ ] Explico o que `%w` conserva e por que `%v` não basta.
- [ ] Uso `errors.Is` para reconhecer sentinelas encapsuladas.
- [ ] Distingo erro do handler, erro de configuração e escolha de fallback.
- [ ] Sei ler o trace mesmo quando `Run` retorna `nil`.
- [ ] Sei que tradução para gRPC/HTTP ainda não está implementada aqui.

## Próximo passo

Veja [Generics](../05-generics/machine-generica.md) para entender por que `Machine[T]` aceita payloads diferentes sem carregar tipos de pagamento para `pkg/`. Depois, [Testes](../08-testes/testando-fsm.md) mostra como verificar esse contrato externamente. O futuro [módulo FSM](../11-fsm/index.md) tratará topologia e auditabilidade como arquitetura.
