# Do conceito ao código real

## Um roteiro de investigação

Comece pela pergunta: “o que o Go executa hoje?” Para a FSM, procure `type Machine` e `func Run` em `pkg/fsm/fsm.go`; confirme o comportamento em `pkg/fsm/fsm_test.go`. Só então leia o [ADR da FSM](../adr/0005-fsm-with-deterministic-fallback.md) para entender a motivação. O ADR descreve um pipeline futuro, enquanto o pacote atual fornece o mecanismo reutilizável.

## Comandos úteis

No terminal do Dev Container, na raiz do repositório:

```bash
rg --files cmd pkg migrations proto
rg -n '^(type|func|var|const) ' pkg/fsm
rg -n '^func (Test|Benchmark|Fuzz)' --glob '*_test.go' .
go test ./pkg/fsm
```

O primeiro comando encontra arquivos; o segundo localiza declarações; o terceiro diferencia testes e benchmarks existentes de promessas documentais. Não aparecer um `BenchmarkScore` é evidência de que o número citado no [ADR de inferência](../adr/0004-native-tree-inference-in-go.md) não foi medido neste checkout.

## Exemplo: seguir um erro

1. Em `pkg/fsm/fsm.go`, encontre `ErrNoTransition` e o `fmt.Errorf` que usa `%w`.
2. Em `pkg/fsm/fsm_test.go`, encontre `TestErrorWithoutFallbackAborts` e a verificação com `errors.Is`.
3. Leia [Erros e fallback na FSM](04-erros/fsm-erros.md) para entender por que a causa continua identificável.
4. Se quiser seguir a arquitetura futura, compare com a [política de falhas](../architecture.md), distinguindo o que está implementado da intenção.

Também vale consultar `go doc` da biblioteca padrão dentro do Dev Container, por exemplo `go doc errors.Is`. Documentação externa ajuda a entender semântica da linguagem; o código e os testes determinam o comportamento deste projeto.
