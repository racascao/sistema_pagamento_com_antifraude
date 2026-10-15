# Referências do professor

Esta seleção reúne 37 artigos de **Otavio Celestino dos Santos (HunCoding)** preservados em `docs/artigos-completos/pt/`. Eles oferecem modelos mentais, exemplos e alternativas para acompanhar o curso; os textos originais não foram reescritos aqui. O [catálogo estruturado](referencias-do-professor.yaml) registra ID, data, módulos, vínculo com o projeto e ressalvas de cada artigo.

## Como usar estas referências

**A** complementa código existente, **B** prepara uma parte da arquitetura-alvo e **C** amplia o horizonte do curso. A letra não mede qualidade. Comece pelo código e pelos testes, leia o tutorial MkDocs, selecione um artigo relacionado e confira a documentação oficial quando precisar afirmar comportamento normativo ou atual. Propostas, preços, versões de bibliotecas e benchmarks requerem verificação própria.

| Pergunta | Fonte |
|---|---|
| Estado implementado | código e testes |
| Regras de desenvolvimento | `AGENTS.md` |
| Direção | [Visão do projeto](../visao-do-projeto.md) |
| Desenho técnico e decisões | [Arquitetura](../architecture.md) e [ADRs](../adr/0001-monorepo-with-independent-deployments.md) |
| Go e stdlib normativos | documentação oficial do Go |
| Explicação pedagógica | artigos desta página |
| Progresso do material | [Roadmap](roadmap.md) |

Para novos tutoriais: assunto → catálogo YAML → artigos relacionados → código real → fontes oficiais, quando necessárias → tutorial e exercício. Um artigo que descreve MVC, Redis-like, Genkit, OpenTelemetry ou Terraform ajuda a avaliar alternativas; sua presença aqui não autoriza novas dependências ou mudanças arquiteturais.

## Fundamentos, estilo e arquitetura

- **[Como Escrever Código Go Idiomático](../artigos-completos/pt/go-idiomatic-code.md)** — erros explícitos, `defer`, nomes, composição e `sync`; útil ao ler os três mecanismos existentes. **A · Fundamentos, Erros, Interfaces.** [Original](https://huncoding.com/go-idiomatic-code/).
- **[Por que Engenheiros Sênior Estão Abandonando MVC em Go](../artigos-completos/pt/mvc-go-problemas-arquitetura-moderna.md)** — compara MVC com portas e adapters e discute custo de migração. **B · Interfaces e arquitetura, Modelagem.** [Original](https://huncoding.com/mvc-go-problemas-arquitetura-moderna/).
- **[Por que o Google diz que Go é ideal para desenvolvimento assistido por IA](../artigos-completos/pt/go-ideal-para-ia-engenharia-software.md)** — opinião sobre legibilidade, tipagem e ferramentas no ciclo de desenvolvimento. **C · Ecossistema Go, IA.** [Original](https://huncoding.com/go-ideal-para-ia-engenharia-software/).

## Erros, generics e Go moderno

- **[Erros em Go: errors.Is, errors.As e wrapping](../artigos-completos/pt/go-erros-errors-is-as-wrapping-sentinel.md)** — complementa sentinelas e `%w` usados na FSM e no batcher. **A · Erros, FSM, Testes.** [Original](https://huncoding.com/go-erros-errors-is-as-wrapping-sentinel/).
- **[Go 1.26: novidades da linguagem e runtime](../artigos-completos/pt/go-1-26-novidades.md)** — contextualiza a versão declarada no `go.mod`; confira release notes para comportamento normativo. **A · Go moderno, Performance.** [Original](https://huncoding.com/go-1-26-novidades/).
- **[Go Iterators: Range Over Functions](../artigos-completos/pt/go-iterators-range-over-functions.md)** — explica `iter.Seq`, `Seq2` e iteração sobre funções sem impor refatoração ao projeto. **C · Go moderno, Generics.** [Original](https://huncoding.com/go-iterators-range-over-functions/).
- **[Proposta de coleções genéricas para Go 1.28](../artigos-completos/pt/go-colecoes-genericas-stdlib.md)** — discute Set, mapas ordenados e heap genérico propostos; os exemplos não são API confirmada. **C · Go moderno, Generics.** [Original](https://huncoding.com/go-colecoes-genericas-stdlib/).
- **[Go e lambdas: discussão da issue #21498](../artigos-completos/pt/go-lambdas-short-function-literals-proposta.md)** — separa funções literais atuais de uma proposta sintática. **C · Go moderno.** [Original](https://huncoding.com/go-lambdas-short-function-literals-proposta/).

## Concorrência, Context e testes

- **[Concorrência vs Paralelismo em Go](../artigos-completos/pt/concorrencia-vs-paralelismo-go-mitos-performance.md)** — scheduler e custo de paralelismo como complemento ao batcher e ao cache. **A · Concorrência, Performance.** [Original](https://huncoding.com/concorrencia-vs-paralelismo-go-mitos-performance/).
- **[A Maioria dos Serviços em Go Não Precisa Ser Concorrente](../artigos-completos/pt/go-concorrencia-prematura-problemas.md)** — tese e medições que ajudam a questionar concorrência prematura; números dependem do workload. **A · Concorrência, Performance.** [Original](https://huncoding.com/go-concorrencia-prematura-problemas/).
- **[Por que context.Context é o sistema nervoso do Go moderno](../artigos-completos/pt/context-nervous-system-go.md)** — cancelamento e deadlines para comparar com FSM e `Submit` do batcher; propagação entre serviços é futura. **A · Context, Concorrência.** [Original](https://huncoding.com/context-nervous-system-go/).
- **[testing/synctest e testes concorrentes](../artigos-completos/pt/go-synctest-testando-codigo-concorrente.md)** — tempo controlado, timers e goroutines para comparar com testes atuais de batcher e cache. **A · Testes, Concorrência.** [Original](https://huncoding.com/go-synctest-testando-codigo-concorrente/).

## Cache e memória

- **[Ponteiros Fracos em Go e caches](../artigos-completos/pt/go-ponteiros-fracos-weak-pointer-cache.md)** — alternativa de gestão de memória para contrastar com o TTL e janitor do `memcache`; ele não usa `weak.Pointer`. **A · Cache, Go moderno.** [Original](https://huncoding.com/go-ponteiros-fracos-weak-pointer-cache/).
- **[Redis-like KV Store educacional](../artigos-completos/pt/redis-like-golang-project.md)** — compara cache local com servidor KV, TTL, persistência e Clean Architecture. **A · Cache, Concorrência.** [Original](https://huncoding.com/redis-like-golang-project/).

## HTTP, APIs, gRPC e serialização

- **[Rate Limiting em Go](../artigos-completos/pt/go-rate-limiting-algorithms.md)** — compara fixed/sliding window e token/leaky bucket para a futura borda HTTP. **B · HTTP e SSE, Concorrência.** [Original](https://huncoding.com/go-rate-limiting-algorithms/).
- **[Go e OpenAPI/Swagger](../artigos-completos/pt/go-openapi-swagger-documentando-apis-rest.md)** — alternativas para documentar contratos HTTP quando o gateway tiver API. **B · HTTP e SSE.** [Original](https://huncoding.com/go-openapi-swagger-documentando-apis-rest/).
- **[Comparação de routers HTTP em Go](../artigos-completos/pt/comparacao-routers-go-performance-benchmark.md)** — metodologia e critérios além de `ns/op`; números e versões são contextuais. **B · HTTP e SSE, Performance.** [Original](https://huncoding.com/comparacao-routers-go-performance-benchmark/).
- **[Go e gRPC: APIs do zero](../artigos-completos/pt/go-grpc-boas-praticas-producao.md)** — Protobuf, cliente, servidor, streaming e status para a comunicação planejada. **B · Protobuf e gRPC, Context.** [Original](https://huncoding.com/go-grpc-boas-praticas-producao/).
- **[O Custo Invisível do JSON](../artigos-completos/pt/go-serialization-benchmarks.md)** — compara formatos e alocações; use a metodologia e meça os payloads deste projeto. **B · Protobuf e gRPC, Performance.** [Original](https://huncoding.com/go-serialization-benchmarks/).

## Observabilidade, MCP e IA

- **[Observabilidade one-liner em Go](../artigos-completos/pt/observabilidade-one-liner-go-o11y-last9-tracekit.md)** — instrumentação com ferramentas externas para comparar estratégias futuras. **B · Observabilidade, Context.** [Original](https://huncoding.com/observabilidade-one-liner-go-o11y-last9-tracekit/).
- **[Observabilidade Distribuída com Kafka e Jaeger](../artigos-completos/pt/sistema-observabilidade-opentelemetry-go.md)** — estudo de transporte de traces por Kafka; essa arquitetura não está adotada no projeto. **B · Observabilidade, Kafka.** [Original](https://huncoding.com/sistema-observabilidade-opentelemetry-go/).
- **[Construindo um servidor MCP em Go](../artigos-completos/pt/construindo-servidor-mcp-em-go.md)** — conceitos de protocolo e ferramentas; o artigo usa SDK, enquanto o ADR do projeto prevê implementação direta. **B · MCP, IA.** [Original](https://huncoding.com/construindo-servidor-mcp-em-go/).
- **[Genkit Go 1.0](../artigos-completos/pt/genkit-go-framework-ia.md)** — flows, tool calling e RAG como alternativas de ecossistema, sem decisão de adoção. **C · IA, MCP.** [Original](https://huncoding.com/genkit-go-framework-ia/).
- **[LLM do Zero em Go](../artigos-completos/pt/llm-do-zero-como-maquinas-leem-texto.md)** — bytes, runes, UTF-8 e tokenização como contexto de IA. **C · IA, Fundamentos.** [Original](https://huncoding.com/llm-do-zero-como-maquinas-leem-texto/).

## Performance, infraestrutura e deploy

- **[GOMAXPROCS e Kubernetes](../artigos-completos/pt/gomaxprocs-kubernetes-problema.md)** — CPU limits, throttling e comportamento do runtime em pods. **B · Deploy/Kubernetes, Performance.** [Original](https://huncoding.com/gomaxprocs-kubernetes-problema/).
- **[Migrando aplicações Go para Kubernetes](../artigos-completos/pt/migrando-go-para-kubernetes.md)** — configuração, probes, shutdown e recursos para o destino GKE. **B · Deploy/Kubernetes, Context.** [Original](https://huncoding.com/migrando-go-para-kubernetes/).
- **[Do zero a um Operador Kubernetes](../artigos-completos/pt/do-zero-a-um-operator-kubernetes.md)** — reconciliação e ConfigMaps, sem demanda atual por operator próprio. **C · Deploy/Kubernetes.** [Original](https://huncoding.com/do-zero-a-um-operator-kubernetes/).
- **[O que o Terraform executa em um provider Go](../artigos-completos/pt/terraform-how-it-works.md)** — protocolo de plugin, RPCs e estado como contexto da IaC futura. **B · Infraestrutura/Cloud, gRPC.** [Original](https://huncoding.com/terraform-how-it-works/).
- **[CDKTF em Go](../artigos-completos/pt/cdktf-go-infraestrutura-como-codigo.md)** — alternativa para gerar infraestrutura Terraform em Go; não define a ferramenta do projeto. **C · Infraestrutura/Cloud.** [Original](https://huncoding.com/cdktf-go-infraestrutura-como-codigo/).
- **[Criando um Provider Terraform Customizado](../artigos-completos/pt/provider-terraform-customizado.md)** — extensão de Terraform para APIs internas, além do escopo atual. **C · Infraestrutura/Cloud.** [Original](https://huncoding.com/provider-terraform-customizado/).
- **[Por que Go em Platform Engineering](../artigos-completos/pt/go-platform-engineering-2025.md)** — cenário de ferramentas cloud-native e opinião datada de 2025. **C · Infraestrutura/Cloud, Ecossistema Go.** [Original](https://huncoding.com/go-platform-engineering-2025/).
- **[Cold Start do Go no AWS Lambda](../artigos-completos/pt/lambda-golang-coldstart.md)** — metodologia de medição em plataforma diferente do alvo GKE. **C · Infraestrutura/Cloud, Performance.** [Original](https://huncoding.com/lambda-golang-coldstart/).
- **[LocalStack e custo de testes na AWS](../artigos-completos/pt/localstack-mais-caro-que-aws.md)** — alternativas de testes de infraestrutura; preços exigem conferência atual. **C · Infraestrutura/Cloud, Testes.** [Original](https://huncoding.com/localstack-mais-caro-que-aws/).

## Ecossistema e visão do curso

- **[Distribuindo uma CLI em Go com GoReleaser](../artigos-completos/pt/go-cli-goreleaser-distribuindo-cli.md)** — pipeline de release de ferramenta CLI, complementar aos deploys de serviços. **C · Ecossistema Go.** [Original](https://huncoding.com/go-cli-goreleaser-distribuindo-cli/).
- **[Go Survey 2025](../artigos-completos/pt/go-survey-2025-gin-domina.md)** — fotografia temporal de frameworks, logging, erros e generics; percentuais envelhecem. **C · Ecossistema Go.** [Original](https://huncoding.com/go-survey-2025-gin-domina/).
- **[Vercel vs Netlify vs Railway](../artigos-completos/pt/vercel-vs-netlify-vs-railway-guerra-deploys.md)** — comparação de hospedagem e preços, sem mudar o destino GKE. **C · Ecossistema Go, Deploy.** [Original](https://huncoding.com/vercel-vs-netlify-vs-railway-guerra-deploys/).
- **[Golang Avançado: construindo um processador de pagamentos](../artigos-completos/pt/golang-avancado-curso-udemy.md)** — visão pedagógica do próprio curso e relação entre componentes. **C · Projeto/arquitetura.** A [visão interna](../visao-do-projeto.md) orienta o destino do repositório; código e testes definem o estado atual. [Original](https://huncoding.com/golang-avancado-curso-udemy/).
