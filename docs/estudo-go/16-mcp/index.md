# MCP

**Estado:** Planejado. Veja o [roadmap](../roadmap.md) para a sequência e os pré-requisitos.

## Onde isso aparece no projeto

`pkg/mcp/mcp.go` declara apenas `package mcp`; o servidor JSON-RPC, registry e tools do investigator são intenção documentada.

Fontes: `pkg/mcp/mcp.go`, `cmd/investigator/main.go`, [ADR 0007](../../adr/0007-mcp-from-scratch.md).

## O que você vai aprender

Distinguir protocolo de lógica das ferramentas; acompanhar framing, initialize e tool calls quando existirem.

## Checkpoint desta etapa

- [ ] Consigo localizar as fontes mencionadas no checkout.
- [ ] Sei separar o comportamento implementado da intenção descrita nos ADRs.
- [ ] Sei qual conceito precisa estar claro antes do capítulo completo.

[Voltar ao mapa do projeto](../mapa-do-projeto.md).

