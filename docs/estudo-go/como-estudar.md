# Como estudar

## Duas rotas

Na rota linear, siga [Fundamentos](01-fundamentos/index.md), [Interfaces](03-interfaces/index.md), [Generics](05-generics/index.md), [Erros](04-erros/index.md) e [Testes](08-testes/index.md). Na rota por problema, comece pelo [Mapa do projeto](mapa-do-projeto.md), encontre o arquivo que contém o comportamento e siga os links para os conceitos usados nele.

Cada capítulo começa com um problema do projeto, apresenta só a sintaxe necessária e termina com alternativas, armadilhas, exercícios e um checkpoint. Trechos identificados como **Origem** são retirados do código atual. **Exemplo mínimo** significa um exemplo didático que não existe no repositório; a seção **No payment-processor** mostra o vínculo com o código.

As [Aulas do curso](../aulas-do-curso/index.md) seguem a sequência original do professor; este tutorial reorganiza conceitos para aprendizado progressivo. Uma rota útil é: **aula → tutorial → código e testes reais → artigos selecionados → documentação oficial quando houver dúvida normativa**. Os [ADRs](../adr/0001-monorepo-with-independent-deployments.md) são decisões arquiteturais obrigatórias, não leitura opcional: slide ou código divergente não os substitui.

Para aprofundar um tema, siga: código real → tutorial MkDocs → [referência do professor](referencias-do-professor.md) relacionada → documentação oficial, quando for necessário confirmar uma API ou comportamento atual → exercício. O catálogo da página ajuda a escolher apenas os artigos pertinentes.

## Ambiente de estudo

Os comandos Go devem rodar no Dev Container do projeto. Para testar a FSM:

```bash
go test ./pkg/fsm ./pkg/memcache ./pkg/batch
go build ./...
go vet ./...
```

Se estiver fora do Dev Container, é possível usar a imagem dele sem instalar Go no host:

```bash
docker compose -f .devcontainer/docker-compose.yml run --rm --no-deps app go test ./pkg/fsm ./pkg/memcache ./pkg/batch
```

Para este site, `make docs-serve` inicia o MkDocs em Docker; `make docs-build` faz um build estrito. Esses comandos não precisam da stack de pagamentos. O [Runbook](../runbook.md) contém comandos operacionais da stack pretendida, muitos ainda dependem de serviços não implementados.

## Regra de leitura

Faça perguntas diferentes a fontes diferentes: código e testes mostram o estado implementado; `AGENTS.md` orienta o trabalho; [ADRs](../adr/0001-monorepo-with-independent-deployments.md) fixam decisões; [Arquitetura](../architecture.md) e [visão](../visao-do-projeto.md) descrevem o destino; documentação oficial confirma contratos de Go e APIs. Em particular, configuração de container ou uma tabela SQL não prova que exista um servidor Go atendendo requisições.

Registre dúvidas como hipótese verificável: “existe um `Score` implementado?” pode ser respondida procurando nos `.proto` e em `cmd/fraud`, não inferindo a partir de um ADR. Veja o [guia de rastreamento](conceito-para-codigo.md).
