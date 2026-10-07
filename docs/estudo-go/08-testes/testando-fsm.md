# Testando a FSM

## O que você vai aprender

Ler `*_test.go` e `testing.T`, organizar casos table-driven e subtests, testar erros por identidade, avaliar determinismo e reconhecer lacunas de cobertura. A FSM fornece testes reais; não há benchmark Go nem integração de serviços neste checkout.

## Onde isso aparece no projeto

`pkg/fsm/fsm_test.go` usa `package fsm_test`: é um teste **black-box**, que importa `github.com/racascao/payment-processor-course/pkg/fsm` e só acessa sua API exportada. Esse limite é útil: se o teste precisar ler `machine.handlers` diretamente, talvez esteja testando estrutura interna em vez de comportamento.

## O problema

O motor deve chegar ao terminal, preservar erro de handler, manter a execução após fallback e abortar sem fallback. Um teste precisa observar essas promessas pela API pública sem depender da duração exata dos handlers nem de infraestrutura externa.

## Modelo mental

Um teste organiza **preparação → execução → verificação**. `TestXxx(t *testing.T)` é descoberto pelo comando `go test`; `t.Fatalf` marca falha e encerra o subteste atual. Uma tabela separa **caso → entrada → execução → expectativa**, facilitando novos cenários quando o fluxo é o mesmo. Subtests nomeados com `t.Run` isolam a falha de cada caso.

## No payment-processor: tabela e subtest

Origem: `pkg/fsm/fsm_test.go`:

```go
tests := []struct {
	name      string
	wantTrace int
	wantScore float64
}{
	{name: "happy path", wantTrace: 2, wantScore: 0.9},
}

for _, tt := range tests {
	t.Run(tt.name, func(t *testing.T) {
		machine := fsm.New[payload]("start").
```

A tabela atual tem **um caso**, não uma matriz ampla. `wantTrace` e `wantScore` são expectativas; o teste cria a máquina, roda `Run(context.Background(), &p)` e compara resultado. Com `t.Run`, a saída identifica `TestRun/happy_path`. Como `go.mod` declara Go 1.26.4, a variável `tt` declarada pelo `range` é distinta por iteração; ainda assim, só use `t.Parallel` depois de garantir que cada caso possua estado próprio e nenhum mapa de configuração seja alterado concorrentemente.

Uma tabela é útil quando casos diferem em entradas/expectativas mas compartilham montagem e asserções. Os testes de fallback e erro sem fallback montam topologias diferentes; mantê-los separados é mais legível do que colocar callbacks e políticas em uma tabela genérica prematura. Essa escolha segue `AGENTS.md` sem transformar “table-driven por padrão” em regra cega.

## Testes de erro e de fallback

Origem: `pkg/fsm/fsm_test.go`:

```go
if !errors.Is(err, boom) {
	t.Fatalf("errors.Is(Run() error, boom) = false, error = %v", err)
}
```

`TestErrorWithoutFallbackAborts` verifica que `Run` devolve o erro original mesmo após `fmt.Errorf(...%w...)`. Comparar `err.Error()` com uma frase seria frágil: o motor adiciona o estado, e uma mudança de redação não deve quebrar o contrato de identidade. Testar texto é legítimo quando o texto é o próprio contrato de saída, como uma mensagem apresentada ao usuário; não é o caso desta sentinela. Veja [Cadeia de erros](../04-erros/cadeia-de-erros.md).

`TestFallbackKeepsPipelineAvailable` configura `FallbackTo("ml", "rules_only")`, verifica ausência de erro final, último estado visitado e `trace[1].Err != nil`. Isso demonstra que fallback continua a execução sem apagar a falha registrada. O teste atual não usa `errors.Is(trace[1].Err, dependencyDown)` nem confere cada `From`/`To`; essas verificações são boas extensões didáticas, não propriedades já testadas. [Erros e fallback](../04-erros/fsm-erros.md) explica a diferença entre erro e política.

## Testando um mecanismo genérico

Os três testes instanciam `fsm.New[payload]`. `payload` tem `visited []string` e `score float64`; esse slice o torna não comparável. Isso é evidência de que a constraint `any` funciona para o tipo usado e de que `T comparable` seria restritiva demais. As alterações do handler em `*payload` são observadas após `Run`, preservando a relação estática entre máquina, handler e dado. Não há teste com um segundo payload; não declare cobertura de outros tipos sem criá-la por uma necessidade real. A [página de Generics](../05-generics/machine-generica.md) mostra um erro de tipo detectado no build sem adicionar código inválido ao projeto.

O teste evita afirmar um valor para `Transition.Duration`: o tempo de relógio varia. Ele verifica contagem de hops e efeitos no payload, que são determinísticos neste cenário. `ctx.Err()` e limite de hops têm caminhos de código, mas ainda não têm casos próprios nos testes existentes.

## Helpers, limpeza e fakes

O helper real `record(p *payload, name string)` só altera o payload; ele não recebe `*testing.T`, portanto não chama `t.Helper()`. Se surgirem asserções repetidas, um helper que recebe `t` deve iniciar com `t.Helper()` para que a falha aponte para a chamada do teste. **Exemplo mínimo**, não presente no repositório:

```go
func requireTraceLen(t *testing.T, trace []fsm.Transition, want int) {
	t.Helper()
	if len(trace) != want {
		t.Fatalf("len(trace) = %d, want %d", len(trace), want)
	}
}
```

**No payment-processor:** o teste atual repete pouco; não há motivo para adicionar esse helper ao código só por estilo. `t.Cleanup` registra limpeza após o teste/subteste, útil quando um teste cria recurso; a FSM em memória não abre arquivos nem conexões, portanto os testes atuais não precisam dele. Quando um futuro consumidor depender de uma interface pequena, um fake que implemente apenas essa porta poderá controlar retorno e erro; não há fake em `fsm_test.go` hoje. Veja [Interfaces](../03-interfaces/interfaces-na-fsm.md).

## Race detector e tooling

No Dev Container, na raiz do repositório:

```bash
go test ./pkg/fsm
go test -race ./...
go build ./...
go vet ./...
```

O race detector encontra acessos concorrentes conflitantes **que ocorrerem durante o teste**. Uma execução sem alerta não prova ausência de races em caminhos não exercitados nem prova correção de toda sincronização. A FSM lê mapas de configuração; configurar `Handle` enquanto outra goroutine chama `Run` é cenário que exigiria coordenação externa e não é coberto pelos testes atuais. `go vet` analisa padrões suspeitos estaticamente; não substitui testes. `gofmt` formata código Go, não valida comportamento.

Não há `BenchmarkXxx` no repositório. Quando existir um benchmark real, o [módulo Performance](../17-performance/index.md) explicará `b.N`, `ns/op` e `allocs/op` com medições reproduzíveis, sem inventar números agora.

## Alternativas e armadilhas

- Um teste que inspeciona mapas privados da máquina pode passar mesmo que `Run` se comporte incorretamente; observe a API pública.
- `time.Sleep` e igualdade exata de `Duration` tornariam o teste sensível ao agendador.
- Um fake enorme que implementa métodos não consumidos sinaliza uma interface grande demais.
- Usar `t.Parallel` sem isolar payloads e configuração pode criar races que não existem no uso sequencial.
- `errors.Is` é adequado para identidade; `errors.As`/`AsType` são para tipo de erro, quando houver um erro tipado.

## Exercícios

- **Nível 1 — reconhecer:** localize `TestRun`, `TestFallbackKeepsPipelineAvailable` e `TestErrorWithoutFallbackAborts`; indique a propriedade de cada um.
- **Nível 2 — explicar:** por que o teste de erro usa `errors.Is`, e por que `trace[1].Err != nil` não prova sozinho qual foi a causa?
- **Nível 3 — modificar:** acrescente ao `TestRun` um caso table-driven com outro `wantScore`, mantendo montagem e asserções compartilhadas.
- **Nível 4 — diagnosticar:** se `Run` passasse a usar `%v` no erro do handler, qual teste falharia? Se removesse o registro no trace durante fallback, qual outro teste falharia?
- **Nível 5 — projetar:** desenhe casos para contexto cancelado, handler ausente e limite de hops. Escolha entre tabela e testes separados e justifique o que cada asserção deve observar.

## Checklist

- [ ] Sei escrever um teste table-driven e usar `t.Run`.
- [ ] Sei quando `t.Helper` e `t.Cleanup` ajudam e por que não aparecem aqui.
- [ ] Sei testar uma sentinela encapsulada com `errors.Is`.
- [ ] Sei explicar o propósito e o limite do race detector.
- [ ] Distingo o que os testes existentes provam do que ainda falta testar.

## Próximo passo

Releia [Generics](../05-generics/machine-generica.md) para relacionar a instância `Machine[payload]` à segurança em compilação. O futuro [módulo FSM](../11-fsm/index.md) tratará a topologia dos estados e a auditabilidade do trace.
