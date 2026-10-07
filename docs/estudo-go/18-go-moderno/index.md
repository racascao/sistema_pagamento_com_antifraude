# Go moderno

**Estado:** referência de versões para os temas desta fase; capítulo amplo ainda planejado. Veja o [roadmap](../roadmap.md).

## Onde isso aparece no projeto

O `go.mod` declara `go 1.26.4`, o Dev Container usa imagem `1.26-bookworm`, o build de serviços usa `1.26-alpine`, enquanto o README ainda diz Go 1.24+. A declaração do módulo é a referência efetiva para compilar este checkout; não use o requisito mais antigo do README para justificar uma API.

Fontes: `go.mod`, `.devcontainer/Dockerfile`, `deploy/docker/Dockerfile`, `README.md`.

## O que você vai aprender

Classificar recurso como usado, disponível ou posterior à versão declarada, sem alterar `go.mod` por motivos didáticos.

| Recurso | Introduzido | Situação neste checkout |
|---|---|---|
| Type parameters em tipos/funções | Go 1.18 | **Usado** em `Machine[T]`, `Handler[T]`, `New[T]` e `Cache[V]` |
| `slices`, `maps`, `cmp` | Go 1.21 | **Disponíveis**, sem uso no código atual; [Generics](../05-generics/machine-generica.md) mostra exemplos mínimos |
| `errors.AsType` | Go 1.26 | **Disponível**, sem uso; [Erros](../04-erros/cadeia-de-erros.md) distingue de `As` |
| `t.Run`, `t.Helper`, `t.Cleanup` | Versões anteriores à mínima | `t.Run` é **usado**; os outros estão disponíveis e não são necessários aos testes atuais |
| `testing.T.ArtifactDir` | Go 1.26 | **Disponível**, sem uso nem artefatos de teste atuais |
| Métodos concretos com parâmetros de tipo adicionais | Go 1.27 | **Posterior à versão declarada**; `Run` usa o `T` do receiver e não declara outro parâmetro |

As versões acima foram conferidas nas [notas do Go 1.21](https://go.dev/doc/go1.21), [Go 1.26](https://go.dev/doc/go1.26), [explicação oficial de métodos genéricos em Go 1.27](https://go.dev/blog/generic-methods) e [tutorial oficial de generics](https://go.dev/doc/tutorial/generics). A implementação concreta dos pacotes `slices` e `maps` continua a evoluir; verifique `go doc` no Dev Container para a API disponível ali. Recursos como iteradores, `WaitGroup.Go` e `testing/synctest` ficam para o capítulo amplo futuro, quando houver exemplos relevantes no projeto.

## Checkpoint desta etapa

- [ ] Distingo recurso usado de recurso apenas disponível.
- [ ] Sei que `errors.AsType` compila na versão do módulo e método com parâmetro adicional exigiria Go 1.27.
- [ ] Não confundo `func (m *Machine[T]) Run(...)` com método que declara novo parâmetro de tipo.

[Voltar ao mapa do projeto](../mapa-do-projeto.md).
