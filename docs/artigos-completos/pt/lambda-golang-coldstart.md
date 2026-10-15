---
title: "Por que o Cold Start do Go no AWS Lambda Ainda é Subestimado"
source: "https://huncoding.com/lambda-golang-coldstart/"
author: "otavio_celestino"
language: "pt-BR"
date: "2025-10-20"
tags: []
---

# Por que o Cold Start do Go no AWS Lambda Ainda é Subestimado

Postado em  20/10/2025    Atualizado  01/10/2026  

[![Preview Image](../assets/images/2025-10-20-lambda-golang-coldstart-6de19faf1ed6.png)](../assets/images/2025-10-20-lambda-golang-coldstart-6de19faf1ed6.png)

Por  *[Otavio Celestino dos Santos](https://github.com/HunCoding)*  

7 min

E aí, pessoal!

Esse post é um **deep dive** sobre um mito muito comum no ecossistema Go: **“Go não tem cold start”**.

Spoiler: *Go costuma ser mais rápido que Node/Python em muitos cenários, mas o cold start do Go **existe**, varia bastante e tem causas técnicas que muita gente ignora.*

Vou mostrar dados reais, explicar o porquê e terminar com recomendações práticas que você pode aplicar hoje no seu pipeline.

## **Sumário**

- **Observação central:** Go tende a ter *init durations* menores que Node.js em funções simples, mas ainda sofre cold starts que podem ser relevantes para APIs sensíveis a latência. Evidências publicadas mostram `Init Duration` típicos de ~**40 ms** para Go (128MB) em benchmarks públicos, contra >100ms para Node em cenários similares.

  - **Causas principais:** tamanho do artefato (zip/image), dependências, forma de empacotar (zip vs container), arquitetura (x86 vs ARM/Graviton), e inicialização do runtime + código de init.

    - **Ferramentas/mitigações reais:** reduzir tamanho do binário, `GOOS=linux GOARCH=arm64` com Graviton, imagens mínimas (scratch/distroless), `Provisioned Concurrency`, e instrumentação para medir `Init Duration` via CloudWatch Logs/X-Ray.

---

## **O que é o “Init Duration” (o que realmente medimos)**

Quando falamos de *cold start* no AWS Lambda, o número que aparece nas REPORT logs como **Init Duration** é a métrica de interesse: ela representa o tempo gasto na **fase de inicialização** (criação do container, carregamento do runtime, download/extração do código e resolução de dependências) antes da sua função começar a executar.

Em produção, essa é a latência extra apresentada ao usuário final quando a invocação aconteceu em um ambiente recém-criado.

> **Insight Importante**
>
> Muitos desenvolvedores medem apenas o tempo de resposta da API, mas isso inclui tanto o Init Duration quanto o tempo de execução. Para otimizar cold starts, precisamos focar especificamente no Init Duration.

---

## **Dados Reais: O que os Benchmarks Mostram**

### **Comparativo Go / Node / Rust (Benchmark 2024)**

Um benchmark reproduzível comparando funções simples (parse JSON + resposta) mostrou resultados interessantes:

| Runtime | Avg Exec (ms) | Avg Init (ms) |
| --- | --- | --- |
| **Rust** | ~1.1 ms | ~20–25 ms |
| **Go** | ~1.3 ms | ~35–50 ms |
| **Java** | ~2–5 ms | ~200–1000+ ms |
| **Node.js** | ~20 ms | ~120–200+ ms |
| **Python** | ~5–10 ms | ~100–300+ ms |

## Principais descobertas (com base na nova tabela)

1. **Rust lidera com menor cold start absoluto** — nos testes conhecidos, é o runtime que mais frequentemente apresenta *Init Duration* abaixo de 30 ms.

   - **Go mantém vantagem consistente sobre runtimes interpretados** — mesmo não sendo “zero”, o cold start do Go tende a ficar na casa de poucas dezenas de ms, abaixo de Python/Node/Java em cenários equivalentes.

     - **Java é o pior em cold start**, mesmo quando entrega execuções muito rápidas depois de iniciado. A JVM custa caro no bootstrap e pode facilmente exceder 500–1000 ms de init em cenários reais, por isso SnapStart/Provisioned Concurrency são praticamente mandatórios quando latência importa.

       - **Node e Python sofrem por duas razões combinadas**: interpretador + peso típico de dependências. Em sistemas serverless com invocações frias, frequentemente apresentam init na casa das centenas de ms.

         - **A diferença não é acadêmica** — se sua API depende de resposta <100ms no P99/P999, um cold start de 150–400ms é o suficiente para quebrar SLA mesmo com exec rápido.

### **Tese “Size is (almost) all that matters”**

Experimentos que varreram funções com tamanhos de 1 KB até dezenas de MB mostram que **o tamanho do artefato impacta linearmente** o tempo de cold start. Node.js pode ir de ~171 ms a vários segundos conforme o pacote cresce.

> **Conclusão dos Dados**
>
> Reduzir o tamanho do artefato é uma das alavancas mais efetivas para cortar init durations.

---

## **Por que Ainda Há Cold Start em Go? (Causas Técnicas)**

- ## Download / Unpack do Artefato

  - Mais bytes = mais tempo na INIT phase- Binários Go grandes (dependências, assets embutidos, debug info) aumentam o tempo- **Correlação forte** entre tamanho e init duration- ## Runtime Initialization

    - O runtime do Lambda carrega ambiente, handlers- Para custom runtimes e container images pode haver overhead extra- Mesmo binários compilados precisam executar inicializadores globais- ## Código de Inicialização do App

      - Lógica em `init()` ou variáveis globais- Conexões DB, carregamento de configs, clients SDK- Executado durante INIT e empurra o tempo para cima- ## Formato de Empacotamento

        - Container images grandes (ECR pull) custam mais que zip pequeno- Imagens otimizadas (scratch/distroless + multi-stage) reduzem latência- ## Arquitetura de CPU (x86 vs ARM/Graviton)

          - Migrar para ARM (Graviton2/Graviton3) reduz custo e melhora work/$- Em alguns casos de container images grandes, o pull pode aumentar init- **Testes AWS mostraram ganhos médios com Graviton**

---

## **Metodologia de Medição (Reprodutível)**

> **Princípio Fundamental**
>
> Medir *Init Duration* (CloudWatch REPORT) — não apenas tempo de resposta da API. Use CloudWatch Logs Insights / X-Ray para separar INIT de EXECUTION.

### **Deploy Mínimo (Exemplo Prático)**

**Handler simples (main.go):**


```go
package main

import (
  "context"
  "github.com/aws/aws-lambda-go/lambda"
)

func Handler(ctx context.Context, ev map[string]interface{}) (map[string]string, error) {
  return map[string]string{"msg":"hello"}, nil
}

func main() { lambda.Start(Handler) }
```


**Build (zip / runtime gerenciado):**


```bash
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o bootstrap main.go
zip function.zip bootstrap
# deploy via AWS CLI / SAM / Terraform
```


**Build para ARM (Graviton) container image (multi-stage):**


```dockerfile
# builder
FROM golang:1.21-alpine AS build
WORKDIR /src
COPY . .
RUN GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -ldflags="-s -w" -o /out/bootstrap main.go

# final
FROM public.ecr.aws/lambda/provided:al2
COPY --from=build /out/bootstrap /var/task/bootstrap
CMD [ "bootstrap" ]
```


> **Dica Importante**
>
> `-ldflags "-s -w"` reduz o binário (remove símbolos de debug) e costuma cortar alguns KBs — sempre útil para cold starts.

### **Forçar Cold Starts para Teste**

1. Faça deploy da versão- Aguarde 10+ minutos (ou faça `UpdateFunctionConfiguration` para forçar reciclar)- Execute `aws lambda invoke --function-name myfunc /dev/null` e verifique logs- Repita 10x com espera para forçar cold starts

### **Query CloudWatch Logs Insights**

Cole essa query no CloudWatch Logs Insights no log group da função:


```sql
fields @timestamp, @message
| filter @message like /REPORT/
| parse @message /Init Duration: (?<init>[\d\.]+) ms/
| stats avg(toNumber(init)) as avgInit, max(toNumber(init)) as maxInit, count() as invocations by bin(1h)
| sort avgInit desc
```


Isso te dá média / máximo de `Init Duration` — exatamente o que queremos comparar.

---

## **Matriz de Experimentos (Recomendada)**

Execute varredura cruzando:

- **Memória**: 128, 256, 512, 1024 MB- **Package**: zip (runtime) vs container image (distroless)- **Arquitetura**: x86\_64 vs arm64 (Graviton)- **Init Code**: trivial vs `init()` que conecta a um DB (simular delay)- **Provisioned**: on/off

**Métrica principal:** Init Duration  
 **Métricas secundárias:** Exec Duration, Max Memory Used, cost per 1M requests

> **Dica Avançada**
>
> Use o **AWS Lambda Power Tuning** para automatizar varredura de memory vs duration/cost.

---

## **Resultados Típicos (O que Esperar)**

Com base em benchmarks públicos e experiência prática:

- **Go (zip) com binário enxuto: Init ≈ 20–70 ms** em muitas regiões com memória baixa (128–256 MB) para funções triviais- **Node.js** em situações equivalentes costuma apresentar **init >100 ms** em muitos setups- **Impacto do tamanho**: aumentar a “code size” de KB → MB pode ampliar init durations em centenas de ms a segundos- **ARM/Graviton**: geralmente traz **melhora em performance e custo**, mas é necessário validar caso a caso

---

## **Mitigações Práticas (O que Realmente Funciona)**

- ## Torne o Binário Menor

  - `-ldflags "-s -w"`, strip symbols, remova assets embutidos- Minimize dependências- Prefira layer/shared libs apenas quando reduzir o total transferido- ## Evite Trabalho Pesado em `init()`

    - Adie conexões (lazy init) — abra conexão sob demanda na primeira requisição- Se precisar pré-iniciar, use **Provisioned Concurrency** para manter ambientes prontos- ## Escolha ARM/Graviton Quando Fizer Sentido

      - Em muitos testes ARM reduz custo e melhora work/$- Migração geralmente vale a pena, mas valide com seus workloads- ## Use Imagens Mínimas para Container Images

        - Multi-stage build → distroless/scratch- Minimize camadas e conteúdo (remova apt, docs, etc.)- Pull time + image size afetam cold start- ## Provisioned Concurrency / SnapStart

          - `Provisioned Concurrency` elimina cold start observável para invocações cobertas- SnapStart melhora casos de inicializações longas, mas **não** é suportado para todos os runtimes- ## Monitorar e Alertar

            - Alerta em SLO para p95/p99 de `Init Duration`- Instrumentar com OpenTelemetry/X-Ray para identificar causas específicas

---

## **Checklist para Produção**

- Build com `-ldflags "-s -w"` e `CGO_ENABLED=0`- Testar versão ARM (`GOARCH=arm64`) e x86; validar custo/perf- Remover dependências não usadas; revisar vendor- Mover assets >1KB para S3/Layers quando fizer sentido- Garantir lazy init de DB/clients- Adicionar CloudWatch Logs Insights query no runbook- Se API é sensível a latência interativa, configurar Provisioned Concurrency

---

## Referências

- **[AWS — Understanding and Remediating Cold Starts](https://aws.amazon.com/blogs/compute/understanding-and-remediating-cold-starts-an-aws-lambda-perspective/)** — explicação oficial das fases, SnapStart, Provisioned Concurrency- **[Size is (almost) all that matters for optimizing AWS Lambda cold starts](https://medium.com/%40adtanasa/size-is-almost-all-that-matters-for-optimizing-aws-lambda-cold-starts-cad54f65cbb)** — experimento extensivo sobre impacto do tamanho- **[Benchmark: Go / Node / Rust comparison](https://nebjak.dev/blog/benchmarking-aws-lambda-with-node-js-go-and-rust/)** — mostra `Init Duration` reais para funções simples- **[lambda-perf (dashboard público)](https://maxday.github.io/lambda-perf/)** — painel com runs de cold start por runtime

[Go](https://huncoding.com/categories/go/), [Serverless](https://huncoding.com/categories/serverless/), [Performance](https://huncoding.com/categories/performance/), [DevOps](https://huncoding.com/categories/devops/), [AWS](https://huncoding.com/categories/aws/)

[go](https://huncoding.com/tags/go/) [aws](https://huncoding.com/tags/aws/) [lambda](https://huncoding.com/tags/lambda/) [cold-start](https://huncoding.com/tags/cold-start/) [performance](https://huncoding.com/tags/performance/) [observability](https://huncoding.com/tags/observability/) [graviton](https://huncoding.com/tags/graviton/) [provisioned-concurrency](https://huncoding.com/tags/provisioned-concurrency/) [benchmarking](https://huncoding.com/tags/benchmarking/)

[Me compre um café ☕](https://ko-fi.com/huncoding)


---
Fonte: [https://huncoding.com/lambda-golang-coldstart/](https://huncoding.com/lambda-golang-coldstart/)
