# Protobuf e gRPC

**Estado:** Planejado. Veja o [roadmap](../roadmap.md) para a sequência e os pré-requisitos.

## Onde isso aparece no projeto

Os dois arquivos `.proto` declaram serviços, mas não definem RPCs. `go.mod` já lista as bibliotecas gRPC e Protobuf; nenhum servidor ou cliente Go foi implementado.

Fontes: `proto/fraud/v1/fraud.proto`, `proto/ledger/v1/ledger.proto`, [ADR 0003](../../adr/0003-grpc-inside-http-at-the-edge.md).

## O que você vai aprender

Separar schema Protobuf de transporte gRPC; entender evolução de field numbers e código gerado quando houver messages.

## Checkpoint desta etapa

- [ ] Consigo localizar as fontes mencionadas no checkout.
- [ ] Sei separar o comportamento implementado da intenção descrita nos ADRs.
- [ ] Sei qual conceito precisa estar claro antes do capítulo completo.

[Voltar ao mapa do projeto](../mapa-do-projeto.md).

