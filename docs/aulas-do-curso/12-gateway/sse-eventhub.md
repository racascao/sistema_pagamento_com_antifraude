# Streaming com SSE e o EventHub

## Onde esta aula entra no curso

Módulo **12 — Gateway**, aula **03**. Depois de HTTP na borda, Kafka e concorrência, a aula conecta eventos assíncronos a uma interface de operador que precisa ver pagamentos e revisões ao vivo. Pré-requisitos: handlers HTTP, channels, `select` e cancelamento.

!!! info "Arquitetura-alvo / aula futura"
    `internal/gateway/infra/eventhub.go` e os handlers SSE citados no deck **não existem** neste checkout. Há ADRs, contratos, configuração de broker e um console estático, mas nenhum gateway Go servindo um stream SSE. Os trechos de EventHub abaixo descrevem o desenho da aula, não comportamento executável atual.

## O problema que motiva a aula

Um console que consulta “há novidade?” a cada segundo desperdiça chamadas quando nada mudou e pode atrasar a notícia importante até a próxima consulta. WebSocket fornece comunicação bidirecional, mas o console só precisa **receber** eventos. SSE usa uma resposta HTTP mantida aberta para entregar eventos do servidor ao navegador. Ainda falta resolver quem lê Kafka e como distribuir uma mensagem para muitas conexões sem criar um consumer por aba.

## Modelo mental

O EventHub proposto faz fan-out **dentro de um processo gateway**. Uma leitura dos tópicos de pagamentos e revisões alimenta dois grupos de assinantes: os de um `payment_id` e os do feed global. Cada conexão SSE recebe um channel de eventos; o handler escreve no formato de event stream e faz flush da resposta HTTP.

```text
Kafka (payments / reviews) → EventHub desta réplica
                           ├─ assinantes por payment_id → SSE do caso
                           └─ assinantes globais       → SSE do feed
```

“Um consumer por tópico” significa evitar um consumer **por conexão**. Como o hub e seus assinantes são locais a cada réplica, o desenho de múltiplas réplicas precisa garantir que **cada réplica receba os eventos** necessários aos seus próprios clientes. Colocar todas no mesmo consumer group que particiona mensagens entre réplicas, sem fan-out adicional, deixaria algumas conexões sem eventos. O plano de consumo e entrega por réplica precisa ser validado na implementação futura.

## Conceitos apresentados

- **SSE / `EventSource`**: fluxo unidirecional sobre HTTP. O corpo usa `text/event-stream`; o navegador pode restabelecer uma conexão interrompida. Reconnect de transporte **não é replay garantido** dos eventos perdidos.
- **Polling versus push**: SSE evita perguntas vazias repetidas, mas mantém conexões abertas e exige cuidado com proxies, timeouts, autenticação e limpeza de recursos.
- **Assinaturas por `payment_id`**: conectam a tela de detalhe de um caso a eventos daquele pagamento. Assinaturas globais alimentam o feed.
- **Channels e `select` com `default`**: no exemplo da aula, o hub tenta enviar ao channel do assinante sem bloquear o consumidor central. Se o buffer estiver cheio, descarta o evento para aquele assinante.
- **Slow consumer**: descarte protege os demais clientes, mas a tela lenta pode perder eventos. O feed é observacional; uma leitura REST de estado ou histórico é necessária quando completude importa.
- **Cancelamento e desconexão**: o handler deve cancelar sua assinatura ao encerrar a conexão. Fechar um channel uma única vez e removê-lo dos maps evita envio a assinante morto.

## O que o professor está construindo

O gateway será o tradutor entre broker e navegador. O browser não consome Kafka diretamente; o gateway observa tópicos, filtra pelo identificador e entrega eventos SSE. Métricas de operação continuam em Prometheus/Grafana, não no feed do console. Essa divisão de responsabilidades é parte da decisão arquitetural, não uma consequência automática do protocolo SSE.

## Código apresentado na aula

O slide esboça uma estrutura como esta, **arquitetura futura**:

```go
type EventHub struct {
    subs   map[string][]chan Event // por payment_id
    global []chan Event            // feed inteiro
}
```

Na versão da aula, um `dispatch` extrai `payment_id` do payload, percorre os dois grupos de assinantes e usa `select { case ch <- event: default: }`. Esse `default` evita que um cliente lento pare o consumer de Kafka, mas **não** confirma entrega ao navegador. A definição acima é esquemática: os tipos e campos exatos serão decididos e testados quando `internal/gateway/infra/eventhub.go` for implementado. Não há símbolo atual para citar como API pronta.

## Como isso aparece no projeto hoje

| Situação | Evidência | Limite |
|---|---|---|
| **PARCIAL** | ADRs 0003 e 0009, contratos `.proto`, configuração de Redpanda | Decisão e infraestrutura de apoio; não há fluxo Kafka → Go → browser. |
| **PLANEJADO** | `internal/gateway/infra/eventhub.go` e handler HTTP/SSE | Arquivos ausentes; `cmd/gateway/main.go` ainda é stub. |
| **PLANEJADO** | Endpoints `/v1/events/stream` e `/v1/reviews/{id}/stream` da arquitetura | Nenhum listener HTTP Go os expõe hoje. |

## Padrões de projeto e arquitetura

O EventHub é **fan-out pub/sub em processo** sobre um stream Kafka, com subscribers efêmeros ligados a conexões HTTP. Isso não é um broker durável nem um padrão GoF aplicado literalmente. A separação entre evento persistido, projeção de leitura e notificação ao vivo é importante: SSE sinaliza mudança, mas não vira fonte de verdade transacional.

## Trade-offs

| Ganho | Custo | Por que aceitar aqui |
|---|---|---|
| Push unidirecional simples para o console | Conexões longas e política de reconexão | O navegador só precisa receber atualizações. |
| Um loop consumidor alimenta várias abas | Estado de assinantes local à réplica | Evita consumer por aba; requer fan-out por réplica. |
| `select` não bloqueante isola cliente lento | Perda possível de eventos | O feed é observacional, com leitura de estado por API quando necessária. |

## Relação com os ADRs

O [ADR 0003](../../adr/0003-grpc-inside-http-at-the-edge.md) decide HTTP/SSE na borda e gRPC internamente. O [ADR 0009](../../adr/0009-metrics-in-grafana-workflow-in-console.md) decide que workflow ao vivo fica no console via hub, enquanto métricas agregadas ficam em Grafana. O slide é uma explicação dessa direção; eventuais simplificações do exemplo não alteram os ADRs.

## Aprofunde no tutorial

Leia [12. HTTP e SSE](../../estudo-go/10-http-sse/index.md), [8. Concorrência](../../estudo-go/06-concorrencia/index.md), [14. Kafka / Redpanda](../../estudo-go/14-kafka/index.md) e [9. Context](../../estudo-go/07-context/index.md).

## Artigos do professor relacionados

O [panorama do curso](../../artigos-completos/pt/golang-avancado-curso-udemy.md) situa o console, Kafka e SSE no projeto completo. Ele é contexto pedagógico, não evidência de EventHub implementado.

## Documentação oficial

O [HTML Standard: Server-Sent Events](https://html.spec.whatwg.org/multipage/server-sent-events.html) define `EventSource`, reconexão e o formato `text/event-stream`. Em Go, [`http.Flusher`](https://pkg.go.dev/net/http#Flusher) permite enviar buffers ao cliente; a [especificação de `select`](https://go.dev/ref/spec#Select_statements) explica o `default` não bloqueante.

## Perguntas para revisão

1. Por que SSE se encaixa melhor que WebSocket neste fluxo unidirecional?
2. Qual é a diferença entre reconnect e replay de eventos?
3. Por que não criar um consumer Kafka por aba do navegador?
4. O que acontece com um assinante cujo channel está cheio?
5. Como uma réplica gateway diferente continuaria recebendo eventos para seus próprios clientes?
6. Qual fonte consultar quando o operador precisa de estado completo, não só de notificação ao vivo?
7. O que deve acontecer com a assinatura quando o browser desconecta?

## Checklist

- [ ] Distingo stream SSE de API transacional de consulta.
- [ ] Sei explicar os dois grupos de assinantes e o descarte por `default`.
- [ ] Não chamo o EventHub do slide de código atual.
- [ ] Consigo descrever o risco de múltiplas réplicas e a ausência de replay.
