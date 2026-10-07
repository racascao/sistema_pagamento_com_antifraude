# Como estudar

## Duas rotas

Na rota linear, siga [Fundamentos](01-fundamentos/index.md), [Interfaces](03-interfaces/index.md), [Generics](05-generics/index.md), [Erros](04-erros/index.md) e [Testes](08-testes/index.md). Na rota por problema, comece pelo [Mapa do projeto](mapa-do-projeto.md), encontre o arquivo que contém o comportamento e siga os links para os conceitos usados nele.

Cada capítulo começa com um problema do projeto, apresenta só a sintaxe necessária e termina com alternativas, armadilhas, exercícios e um checkpoint. Trechos identificados como **Origem** são retirados do código atual. **Exemplo mínimo** significa um exemplo didático que não existe no repositório; a seção **No payment-processor** mostra o vínculo com o código.

## Ambiente de estudo

Os comandos Go devem rodar no Dev Container do projeto. Para testar a FSM:

```bash
go test ./pkg/fsm
go build ./...
go vet ./...
```

Se estiver fora do Dev Container, é possível usar a imagem dele sem instalar Go no host:

```bash
docker compose -f .devcontainer/docker-compose.yml run --rm --no-deps app go test ./pkg/fsm
```

Para este site, `make docs-serve` inicia o MkDocs em Docker; `make docs-build` faz um build estrito. Esses comandos não precisam da stack de pagamentos. O [Runbook](../runbook.md) contém comandos operacionais da stack pretendida, muitos ainda dependem de serviços não implementados.

## Regra de leitura

Use esta ordem quando duas fontes divergirem: código atual, testes, `AGENTS.md`, [Arquitetura](../architecture.md), [ADRs](../adr/0001-monorepo-with-independent-deployments.md), [Runbook](../runbook.md), README e documentação oficial. Em particular, configuração de container ou uma tabela SQL não prova que exista um servidor Go atendendo requisições.

Registre dúvidas como hipótese verificável: “existe um `Score` implementado?” pode ser respondida procurando nos `.proto` e em `cmd/fraud`, não inferindo a partir de um ADR. Veja o [guia de rastreamento](conceito-para-codigo.md).
