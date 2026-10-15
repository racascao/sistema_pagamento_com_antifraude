---
title: "Golang Avançado: construindo um processador de pagamentos de verdade"
source: "https://huncoding.com/golang-avancado-curso-udemy/"
author: "otavio_celestino"
language: "pt-br"
date: "2026-10-01"
tags: []
---

# Golang Avançado: construindo um processador de pagamentos de verdade

Disponível em:   [English](https://huncoding.com/golang-advanced-course-udemy-en/)

Postado em  01/10/2026    Atualizado  01/10/2026  

[![Preview Image](../assets/images/2026-10-01-golang-avancado-curso-e97bbc3354ab.png)](../assets/images/2026-10-01-golang-avancado-curso-e97bbc3354ab.png)

Por  *[Otavio Celestino dos Santos](https://github.com/HunCoding)*  

7 min

E aí, pessoal!

Nos últimos meses montei um curso sobre como construir um processador de pagamentos em Go. Não um exemplo simplificado: um sistema com quatro microsserviços, decisões de arquitetura documentadas em ADRs e deploy completo no GKE.

O resultado está na Udemy: [GoLang Avançado: Microsserviços, gRPC, Kafka e IA Antifraude](https://www.udemy.com/course/golang-avancado-microsservicos-grpc-kafka-ia-antifraude/?referralCode=5D3D655AEF5FF5BE7830).

Vou detalhar o que está lá dentro.

---

## O sistema completo

Cinco componentes, cada um com uma responsabilidade clara:

Payment Processor — visão geral  cliente HTTP  console :3001   gateway HTTP + SSE rate limiting gRPC client :8080  gRPC gRPC   ledger dupla entrada idempotência Postgres 16 outbox → Kafka :9001    fraud árvore de decisão ~8ns por score FSM + fallback cache semântico :9002    Kafka Redpanda    investigator agente Claude MCP server pgvector RAG Slack + email Kafka consumer    Postgres 16 + pgvector  Prometheus + Grafana · GKE (Cloud SQL · Managed Kafka · Managed Prometheus)

---

## Detecção de fraude nativa em Go

O serviço de fraude roda no caminho síncrono de autorização com um budget de cerca de 15ms. O setup usual é um sidecar Python ou um servidor de inferência separado: mais um hop de rede, mais um runtime pra operar, mais uma serialização por chamada.

Gradient boosted trees (o modelo padrão pra dados tabulares de fraude) se reduzem, em inferência, a comparações e somas. Não tem nada que exija um runtime de ML.

O curso implementa a inferência diretamente em Go. O modelo é exportado como um arquivo JSON de arrays planos de nós, validado no startup, e percorrido diretamente. O scorer não aloca nada no hot path e senta atrás de um dynamic batcher genérico. O benchmark registrou ~8 nanosegundos por score com zero alocações.

---

## FSM com fallback determinístico

O pipeline de fraude tem cinco estados, cada um com um handler nomeado:

Pipeline de fraude — estados FSM   enrich geo + velocity    fast\_rules blocklist · caps    ml\_score árvore ~8ns    semantic\_tie pgvector cache    finalize approve / deny  fallback: degraded → manual review cada transição gravada com duração e erro · loops estruturalmente impossíveis

O ponto chave do fallback: se o `ml_score` falha ou estoura o budget, o sistema não trava a autorização. O handler marca a decisão como `degraded`, roteia para revisão manual e segue. Disponibilidade ganha sobre cobertura do modelo, e a degradação aparece na resposta em vez de ser silenciosa.

---

## Dynamic batcher genérico

O scorer de árvore fica atrás de um batcher que acumula requisições por uma janela de tempo curta antes de processar em lote. A implementação usa generics:


```go
// o batcher é parametrizado nos tipos de request e response
type Batcher[Req, Resp any] struct {
    window  time.Duration
    process func([]Req) []Resp
    // ...
}

func (b *Batcher[Req, Resp]) Submit(ctx context.Context, req Req) (Resp, error) {
    // agrupa chamadas concorrentes e despacha em lote
}
```


O mesmo `Batcher` serve o scorer de fraude, chamadas de embedding e qualquer outro hot path que precise de batching, sem duplicar a lógica de janelamento.

---

## MCP do zero em Go

O `investigator` expõe três ferramentas de investigação:

| Ferramenta | O que faz |
| --- | --- |
| `get_account_history` | histórico de pagamentos da conta |
| `geo_lookup` | geolocalização de IP (ipapi.co ou static) |
| `search_fraud_patterns` | similarity search via pgvector/cosine |

O servidor MCP foi implementado diretamente sobre `encoding/json` e `stdio`, sem SDK e sem dependências externas. O protocolo inteiro (JSON-RPC 2.0, handshake de `initialize`, listagem de ferramentas, semântica de `tool_call`) é código do curso.

O mesmo registry de ferramentas serve dois frontends: o stdio MCP para clientes externos (qualquer cliente MCP pode se conectar com `go run ./cmd/investigator --mcp`) e chamadas in-process para os advisors de investigação.

Por padrão, o investigator roda um advisor baseado em regras. Quando `ANTHROPIC_API_KEY` está configurada, o mesmo registry de ferramentas é passado para um agente Claude — sem mudar uma linha no registro de ferramentas.

---

## Outbox: consistência sem two-phase commit

O padrão de publicação de eventos é um ponto onde muitos sistemas têm bugs silenciosos. A sequência problemática:


```plaintext
1. BEGIN
2. INSERT payment
3. COMMIT
4. processo morre aqui
5. publish to Kafka  ← nunca acontece
```


O outbox resolve escrevendo o evento na mesma transação do pagamento:


```plaintext
1. BEGIN
2. INSERT payment
3. INSERT outbox_events (mesmo tx)
4. COMMIT
                     ← se morrer aqui, o relay recupera na próxima poll
5. relay: SELECT unpublished FROM outbox_events
6. publish to Kafka
7. UPDATE outbox_events SET published=true
```


O relay consulta a cada 200ms, publica e marca como publicado depois do ACK do broker. Delivery at-least-once, consumidores idempotentes keyed por `payment_id`.

---

## Cache sem Redis

Velocidade e cache semântico ficam in-process, sem Redis. Duas razões documentadas no ADR:

1. Um round-trip de rede no hot path de autorização custa mais do que o cache economiza- Redis fica indisponível, autorização degrada

A implementação usa tipos com sharding manual:


```go
// velocity: sharded TTL map para contagem de tentativas por cartão
type VelocityCounter[K comparable] struct {
    shards [N]shard[K]
}

// cache semântico: rolling window de vetores de embedding
type SemanticCache struct {
    embeddings []embeddingEntry
    mu         sync.RWMutex
}
```


Com múltiplas réplicas do serviço de fraude, cada uma tem estado independente. O balanceamento de carga via hash de fingerprint do cartão no gRPC client suaviza isso.

---

## pgvector: similarity search no Postgres

O investigator busca casos históricos similares para contextualizar a investigação. A decisão foi usar pgvector no mesmo Postgres que o ledger já usa (ADR 0002), em vez de subir um banco vetorial separado.


```sql
-- busca os 5 casos mais similares por cosine distance
SELECT id, description, decision
FROM fraud_patterns
ORDER BY embedding <=> $1  -- cosine distance operator
LIMIT 5;
```


O índice é IVFFlat para busca aproximada. O port `PatternStore` isola a implementação, então trocar por Qdrant é mudar um adapter.

---

## Observabilidade

Cada serviço expõe `/metrics` no formato Prometheus. O Grafana tem um dashboard provisionado como código no repositório — os mesmos manifestos rodam no `docker-compose`, no kind e no cluster do GCP.

O console do operador (`localhost:3001`) é uma interface web pré-construída que mostra o feed ao vivo de pagamentos e casos de revisão. Ele se conecta via SSE ao gateway e degrada progressivamente: cada painel mostra um estado bloqueado com o nome do módulo do curso que o desbloqueia.


```bash
make dashboards   # abre Grafana e Prometheus
make demo-feed    # stream global de pagamentos e revisões
```


---

## Integrações opcionais

Tudo roda offline por padrão. As integrações ativam por variável de ambiente:

ANTHROPIC\_API\_KEY: agente Claude no investigator

STRIPE\_API\_KEY: cobranças reais no test mode

SLACK\_WEBHOOK\_URL: relatórios de investigação no Slack

RESEND\_API\_KEY: relatórios por email

GEO\_PROVIDER=ipapi: geolocalização real via ipapi.co

Sem nenhuma dessas chaves, o sistema funciona completo com o advisor baseado em regras, geo estático e sem notificações externas.

---

## Deploy no GKE

O Terraform provisiona dois node pools no GKE: um pool padrão e um pool dedicado para o serviço de fraude, com taint e autoscaling de 1 a 8 réplicas em instâncias ARM. O banco usa Cloud SQL for PostgreSQL 16 com IP privado e pgvector nativo.


```bash
make up           # stack local completo com docker-compose
# --- depois de cobrir o módulo de infra ---
terraform init && terraform apply   # GKE + Cloud SQL + Managed Kafka
kubectl apply -k deploy/k8s/overlays/gcp
```


---

## ADRs

Cada decisão técnica do sistema tem um ADR documentando contexto, decisão e consequências (positivas e negativas). São 11 ADRs no repositório, cobrindo desde a escolha do Postgres como banco único até o console como walking skeleton.

---

## O que você vai construir

concorrência

#### Go avançado

Generics, goroutines, channels, sync.RWMutex, context, erros idiomáticos, dynamic batcher parametrizado por tipo.

fraude

#### Inferência nativa

Árvore de decisão em Go, ~8ns por score, zero alocações no hot path. Sem sidecar Python.

arquitetura

#### FSM auditável

Pipeline de fraude modelado como FSM explícita. Fallback determinístico, trace por transição, loops impossíveis.

protocolo

#### Protocol Buffers e gRPC

Contratos entre serviços do zero. HTTP, SSE e gRPC num único gateway. SSE para o console do operador.

eventos

#### Kafka e Outbox

Consistência entre Postgres e Kafka com outbox, idempotência por payment\_id, dupla entrada contábil.

ia

#### MCP do zero

Servidor MCP em JSON-RPC 2.0 sobre stdio. Agente Claude ou advisor baseado em regras — mesmo registry.

banco

#### pgvector

Similarity search no mesmo Postgres do ledger. IVFFlat index, cosine distance, port para trocar por Qdrant.

infra

#### GKE + Terraform

Deploy em Kubernetes na GCP. Dois node pools, Cloud SQL, Managed Kafka, Grafana provisionado como código.

---

Tem um vídeo de apresentação se quiser ver o sistema antes de entrar: [apresentação no YouTube](https://www.youtube.com/watch?v=X02C-HN58ko&t=5s).

Link direto para o curso: [GoLang Avançado: Microsserviços, gRPC, Kafka e IA Antifraude](https://www.udemy.com/course/golang-avancado-microsservicos-grpc-kafka-ia-antifraude/?referralCode=5D3D655AEF5FF5BE7830).

Até o próximo post!

[Go](https://huncoding.com/categories/go/), [Curso](https://huncoding.com/categories/curso/)

[go](https://huncoding.com/tags/go/) [golang](https://huncoding.com/tags/golang/) [microsservicos](https://huncoding.com/tags/microsservicos/) [grpc](https://huncoding.com/tags/grpc/) [kafka](https://huncoding.com/tags/kafka/) [ia](https://huncoding.com/tags/ia/) [antifraude](https://huncoding.com/tags/antifraude/) [gcp](https://huncoding.com/tags/gcp/) [kubernetes](https://huncoding.com/tags/kubernetes/) [fsm](https://huncoding.com/tags/fsm/) [mcp](https://huncoding.com/tags/mcp/) [pgvector](https://huncoding.com/tags/pgvector/) [curso](https://huncoding.com/tags/curso/) [udemy](https://huncoding.com/tags/udemy/)

[Me compre um café ☕](https://ko-fi.com/huncoding)


---
Fonte: [https://huncoding.com/golang-avancado-curso-udemy/](https://huncoding.com/golang-avancado-curso-udemy/)
