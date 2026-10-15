---
title: "Genkit Go 1.0: o framework do Google para construir aplicações de IA em Go"
source: "https://huncoding.com/genkit-go-framework-ia/"
author: "otavio_celestino"
language: "pt-br"
date: "2026-09-02"
tags: []
---

# Genkit Go 1.0: o framework do Google para construir aplicações de IA em Go

Disponível em:   [English](https://huncoding.com/genkit-go-ai-framework-en/)

Postado em  02/09/2026    Atualizado  01/10/2026  

[![Preview Image](../assets/images/2026-09-02-genkit-go-framework-ia-f22d05a2b329.png)](../assets/images/2026-09-02-genkit-go-framework-ia-f22d05a2b329.png)

Por  *[Otavio Celestino dos Santos](https://github.com/HunCoding)*  

5 min

E aí, pessoal!

O Google lançou o Genkit Go 1.0, a versão estável do framework open source deles para construir aplicações com IA generativa em Go. Depois de um período em alpha, a 1.0 traz estabilidade de API com compatibilidade garantida dentro da série 1.x, uma CLI standalone e uma Developer UI para testar e monitorar fluxos.

Neste post vou cobrir o que é o Genkit, o que ele resolve, como funciona na prática e o que mudou na 1.0.

---

## O que é o Genkit

Genkit é um framework open source do Google para desenvolver aplicações com IA generativa. A versão para Go combina as características da linguagem, tipagem estática, concorrência nativa e compilação rápida, com uma camada de abstração sobre modelos, bancos vetoriais e pipelines de IA.

A proposta é que você não precise reescrever a integração toda vez que trocar de modelo ou provedor. O Genkit fornece uma interface unificada que funciona com Gemini, GPT-4, Claude, modelos locais via Ollama e outros, com mudança mínima de código.

---

## API unificada de geração

Um problema comum ao construir com LLMs é que cada provedor tem sua própria SDK, seus próprios formatos de request e response e suas próprias convenções. Trocar de modelo significa reescrever a integração.

O Genkit resolve isso com uma interface consistente. Para alternar entre modelos, você muda o nome:


```go
// Gemini
response, err := ai.Generate(ctx, googleai.Model("gemini-2.5-flash"), ...)

// GPT-4o
response, err := ai.Generate(ctx, openai.Model("gpt-4o"), ...)

// Claude
response, err := ai.Generate(ctx, anthropic.Model("claude-sonnet-5"), ...)
```


A mesma chamada e o mesmo formato de resposta, independente do provedor. Isso é útil em projetos onde você quer experimentar modelos diferentes ou manter fallbacks.

---

## Fluxos type-safe

O conceito central do Genkit são os **flows**: workflows multi-etapa com tipagem e observabilidade incorporadas. Você define um fluxo com structs Go e o framework valida entradas e saídas via JSON schema automaticamente.


```go
type RecipeInput struct {
    Ingredients []string `json:"ingredients"`
    Servings    int      `json:"servings"`
}

type Recipe struct {
    Name         string   `json:"name"`
    Instructions []string `json:"instructions"`
    PrepTime     string   `json:"prep_time"`
}

recipeFlow := genkit.DefineFlow("generateRecipe",
    func(ctx context.Context, input RecipeInput) (Recipe, error) {
        response, err := ai.GenerateData[Recipe](ctx,
            googleai.Model("gemini-2.5-flash"),
            ai.WithTextPrompt(fmt.Sprintf(
                "Crie uma receita usando %v para %d pessoas",
                input.Ingredients, input.Servings,
            )),
        )
        if err != nil {
            return Recipe{}, err
        }
        return response.Output(), nil
    },
)
```


O modelo recebe o prompt, devolve JSON, o Genkit valida contra o schema da struct `Recipe` e você recebe um valor Go tipado. Sem parsing manual, sem `map[string]interface{}`.

---

## Tool calling

O Genkit suporta tool calling: você define funções Go e o modelo decide quando e como chamá-las.


```go
getWeather := ai.DefineTool(
    "getWeather",
    "Retorna a temperatura atual de uma cidade",
    func(ctx context.Context, input struct {
        City string `json:"city"`
    }) (string, error) {
        return fetchWeather(input.City)
    },
)

response, err := ai.Generate(ctx,
    googleai.Model("gemini-2.5-flash"),
    ai.WithTextPrompt("Qual é o clima em São Paulo agora?"),
    ai.WithTools(getWeather),
)
```


O modelo recebe a definição da ferramenta, decide chamar `getWeather` com `{"city": "São Paulo"}`, recebe o resultado e incorpora na resposta final. O Genkit cuida do loop de orquestração.

---

## RAG nativo

Retrieval-Augmented Generation é um padrão para conectar LLMs a dados próprios. O Genkit tem suporte a RAG com APIs para indexar e recuperar documentos, com suporte a múltiplos provedores de banco vetorial.


```go
// indexar documentos
err := ai.Index(ctx, indexer, ai.WithDocs(documents...))

// recuperar documentos relevantes e usar no prompt
docs, err := ai.Retrieve(ctx, retriever,
    ai.WithRetrieverText("como funciona o sistema de pagamentos?"),
)

response, err := ai.Generate(ctx, model,
    ai.WithTextPrompt("Responda com base nos documentos fornecidos"),
    ai.WithDocs(docs...),
)
```


A troca de banco vetorial funciona igual à troca de modelo: você muda o `indexer` e o `retriever` sem alterar o restante do código.

---

## Dotprompt: prompts como arquivos versionáveis

Em projetos com LLMs, prompts costumam ficar espalhados no código como strings literais, sem versionamento e sem separação clara entre lógica e instrução.

O Genkit tem o **Dotprompt**: arquivos `.prompt` que consolidam em um único lugar o texto do prompt, o schema de entrada e saída, a seleção de modelo e as configurações de geração.


```plaintext
---
model: googleai/gemini-2.5-flash
input:
  schema:
    topic: string
    audience: string
output:
  schema:
    title: string
    sections: string[]
    conclusion: string
---

Você é um redator técnico experiente.
Escreva um artigo sobre  para uma audiência de .
```


O arquivo fica no repositório junto com o código, é versionável com Git e pode ser editado sem recompilar a aplicação.

---

## Deployment como endpoints HTTP

Um fluxo Genkit pode ser exposto diretamente como endpoint HTTP:


```go
mux := http.NewServeMux()
mux.Handle("/recipe", genkit.Handler(recipeFlow))

server := &http.Server{
    Addr:    ":8080",
    Handler: mux,
}
server.Start(ctx)
```


O fluxo recebe requests POST com o input JSON e devolve o output tipado, sem configuração adicional.

---

## O que mudou na 1.0

A principal mudança em relação ao alpha é a estabilidade de API: dentro da série 1.x, não haverá quebras de compatibilidade.

Além disso, a 1.0 trouxe:

**CLI standalone**, com instalação sem dependências adicionais:


```bash
curl -sL cli.genkit.dev | bash
```


**Developer UI**: interface visual para testar fluxos, inspecionar a execução passo a passo, monitorar latência e consumo de tokens e explorar traces.

**`genkit init:ai-tools`**: novo comando que configura assistentes de IA (Gemini CLI, Claude Code, Cursor) com documentação e ferramentas MCP integradas ao projeto.

---

## Plugins disponíveis

Na 1.0, o Genkit Go suporta:

- **Google AI** (Gemini 2.5 Flash, Gemini 2.5 Pro, etc.)- **Vertex AI** (modelos do Google Cloud)- **OpenAI** (GPT-4o, GPT-4 Turbo, etc.)- **Anthropic** (Claude Sonnet, Claude Haiku, etc.)- **Ollama** (modelos open source locais: Llama, Mistral, Qwen, etc.)- **Pinecone** (banco vetorial para RAG)- **Google Cloud** (telemetria e observabilidade)

---

## Vale a pena usar?

O Genkit ocupa um espaço que estava sendo preenchido por ports Go de frameworks Python como LangChain e LlamaIndex, com a diferença de ser desenvolvido pelo Google com Go como linguagem principal.

Os pontos positivos são a API unificada de modelos, que reduz o lock-in de provedor, os fluxos type-safe, que aproveitam o compilador Go para validação, e a observabilidade incorporada.

O ponto de atenção é que o ecossistema ainda está crescendo. Os plugins cobrem os provedores principais, mas integrações com bancos vetoriais específicos e com ferramentas de observabilidade além do Google Cloud ainda são limitadas.

Para projetos novos que precisam integrar LLMs em Go, vale experimentar. Para projetos existentes com integrações diretas, a decisão depende do que você ganha com a abstração versus o custo de migração.

---

Você já usou o Genkit ou algum framework parecido em Go? Me conta nos comentários.

Até o próximo post!

**Referências:**

- [Introducing Genkit for Go — Google Developers Blog](https://developers.googleblog.com/introducing-genkit-for-go-build-scalable-ai-powered-apps-in-go/)- [Announcing Genkit Go 1.0 — Google Developers Blog](https://developers.googleblog.com/announcing-genkit-go-10-and-enhanced-ai-assisted-development/)

[Go](https://huncoding.com/categories/go/), [IA](https://huncoding.com/categories/ia/), [Genkit](https://huncoding.com/categories/genkit/)

[go](https://huncoding.com/tags/go/) [golang](https://huncoding.com/tags/golang/) [genkit](https://huncoding.com/tags/genkit/) [ia](https://huncoding.com/tags/ia/) [ai](https://huncoding.com/tags/ai/) [llm](https://huncoding.com/tags/llm/) [rag](https://huncoding.com/tags/rag/) [google](https://huncoding.com/tags/google/) [gemini](https://huncoding.com/tags/gemini/) [agentes](https://huncoding.com/tags/agentes/)

[Me compre um café ☕](https://ko-fi.com/huncoding)


---
Fonte: [https://huncoding.com/genkit-go-framework-ia/](https://huncoding.com/genkit-go-framework-ia/)
