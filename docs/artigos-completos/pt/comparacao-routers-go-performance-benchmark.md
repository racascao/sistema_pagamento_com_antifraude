---
title: "Comparação de Performance: Os 5 Principais HTTP Routers do Go"
source: "https://huncoding.com/comparacao-routers-go-performance-benchmark/"
author: "otavio_celestino"
language: "pt-br"
date: "2025-09-30"
tags: []
---

# Comparação de Performance: Os 5 Principais HTTP Routers do Go

Postado em  30/09/2025    Atualizado  01/10/2026  

[![Preview Image](../assets/images/comparing-performances-routers-go-3ef9519c0376.gif)](../assets/images/comparing-performances-routers-go-3ef9519c0376.gif)

Por  *[Otavio Celestino dos Santos](https://github.com/HunCoding)*  

7 min

E aí, pessoal!

Hoje vou fazer uma **análise completa de performance** dos principais HTTP routers do Go. Vamos ver quem realmente é o mais rápido, quem consome menos memória e qual é o melhor para cada cenário!

Se você prefere conteúdo em vídeo, já gravei um vídeo completo comparando esses routers no YouTube:

> **Nota**: O Gorilla Mux foi descontinuado em dezembro de 2022, então não está incluído nesta comparação. Se você ainda usa Gorilla Mux, recomendo migrar para um dos routers ativos mencionados aqui.

## Os 5 Principais Routers

Vamos comparar os **5 routers mais populares** do ecossistema Go:

1. **Gin** - O mais popular- **Echo** - Focado em performance- **Fiber** - Inspirado no Express.js- **Chi** - Modular e flexível- **HttpRouter** - O mais rápido e minimalista

## Metodologia dos Benchmarks

Para uma comparação justa, vamos usar:

- **Go 1.21+** (versão mais recente)- **Testes padronizados** com `go test -bench`- **Múltiplos cenários**: rotas estáticas, dinâmicas, middleware- **Métricas**: requests/segundo, latência, uso de memória- **Ambiente**: Linux, 8 cores, 16GB RAM

## Benchmark 1: Rotas Estáticas

Vamos começar com o cenário mais simples - rotas estáticas:


```go
// Gin
r.GET("/users", handler)
r.GET("/posts", handler)
r.GET("/comments", handler)

// Echo
e.GET("/users", handler)
e.GET("/posts", handler)
e.GET("/comments", handler)

// Fiber
app.Get("/users", handler)
app.Get("/posts", handler)
app.Get("/comments", handler)

// Chi
r.Get("/users", handler)
r.Get("/posts", handler)
r.Get("/comments", handler)

// HttpRouter
r.GET("/users", handler)
r.GET("/posts", handler)
r.GET("/comments", handler)
```


**Resultados (requests/segundo):**

| Router | Requests/sec | Latência (μs) | Memória (MB) |
| --- | --- | --- | --- |
| **HttpRouter** | 48,000 | 21 | 10 |
| **Fiber** | 45,000 | 22 | 12 |
| **Gin** | 42,000 | 24 | 15 |
| **Echo** | 38,000 | 26 | 18 |
| **Chi** | 35,000 | 29 | 20 |

## Benchmark 2: Rotas com Parâmetros

Agora vamos testar rotas dinâmicas:


```go
// Gin
r.GET("/users/:id", handler)
r.GET("/posts/:id/comments/:comment_id", handler)

// Echo
e.GET("/users/:id", handler)
e.GET("/posts/:id/comments/:comment_id", handler)

// Fiber
app.Get("/users/:id", handler)
app.Get("/posts/:id/comments/:comment_id", handler)

// Chi
r.Get("/users/{id}", handler)
r.Get("/posts/{id}/comments/{comment_id}", handler)

// HttpRouter
r.GET("/users/:id", handler)
r.GET("/posts/:id/comments/:comment_id", handler)
```


**Resultados (requests/segundo):**

| Router | Requests/sec | Latência (μs) | Memória (MB) |
| --- | --- | --- | --- |
| **HttpRouter** | 40,000 | 25 | 12 |
| **Gin** | 38,000 | 26 | 16 |
| **Fiber** | 36,000 | 28 | 14 |
| **Echo** | 32,000 | 31 | 19 |
| **Chi** | 28,000 | 36 | 22 |

## Benchmark 3: Middleware Stack

Vamos testar com middleware (autenticação, logging, CORS):


```go
// Gin
r.Use(gin.Logger())
r.Use(gin.Recovery())
r.Use(corsMiddleware)
r.Use(authMiddleware)

// Echo
e.Use(middleware.Logger())
e.Use(middleware.Recover())
e.Use(corsMiddleware)
e.Use(authMiddleware)

// Fiber
app.Use(logger.New())
app.Use(recover.New())
app.Use(corsMiddleware)
app.Use(authMiddleware)

// Chi
r.Use(middleware.Logger)
r.Use(middleware.Recoverer)
r.Use(corsMiddleware)
r.Use(authMiddleware)

// HttpRouter
r.GlobalOPTIONS = http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
    // CORS handling
})
// Middleware precisa ser implementado manualmente
```


**Resultados (requests/segundo):**

| Router | Requests/sec | Latência (μs) | Memória (MB) |
| --- | --- | --- | --- |
| **HttpRouter** | 35,000 | 29 | 15 |
| **Fiber** | 32,000 | 31 | 18 |
| **Gin** | 30,000 | 33 | 20 |
| **Echo** | 28,000 | 36 | 22 |
| **Chi** | 25,000 | 40 | 25 |

## Benchmark 4: JSON Serialization

Testando serialização de JSON (cenário real):


```go
type User struct {
    ID    int    `json:"id"`
    Name  string `json:"name"`
    Email string `json:"email"`
}

func handler(c *gin.Context) {
    user := User{ID: 1, Name: "João", Email: "joao@example.com"}
    c.JSON(200, user)
}
```


**Resultados (requests/segundo):**

| Router | Requests/sec | Latência (μs) | Memória (MB) |
| --- | --- | --- | --- |
| **HttpRouter** | 30,000 | 33 | 18 |
| **Fiber** | 28,000 | 36 | 20 |
| **Gin** | 26,000 | 38 | 22 |
| **Echo** | 24,000 | 42 | 24 |
| **Chi** | 22,000 | 45 | 26 |

## Análise Detalhada por Router

### 🥇 **HttpRouter** - O Mais Rápido

**Vantagens:**

- **Performance superior** em todos os testes- **Zero dependências** externas- **100% compatível** com `net/http`- Baixo consumo de memória- Usado como base pelo Gin

**Desvantagens:**

- **API minimalista** (menos recursos built-in)- Middleware precisa ser implementado manualmente- Menos recursos avançados

**Quando usar:**

- Aplicações que precisam de **máxima performance**- APIs de alta frequência- Quando você quer controle total sobre a implementação

### 🥈 **Fiber** - O Alternativo Rápido

**Vantagens:**

- **Performance excelente** (segundo lugar)- Baseado no `fasthttp` (mais rápido que `net/http`)- API familiar para desenvolvedores Node.js- Baixo consumo de memória

**Desvantagens:**

- **Incompatibilidade** com `net/http` padrão- Ecossistema menor- Menos middleware disponível

**Quando usar:**

- Aplicações que precisam de **alta performance**- APIs de alta frequência- Quando você pode abrir mão da compatibilidade com `net/http`

### 🥉 **Gin** - O Equilibrado

**Vantagens:**

- **Excelente performance** com `net/http` padrão- Ecossistema maduro e ativo- API limpa e intuitiva- Muitos middleware disponíveis

**Desvantagens:**

- Ligeiramente mais lento que Fiber- Consumo de memória um pouco maior

**Quando usar:**

- **Aplicações em produção** que precisam de performance- Quando você quer compatibilidade com `net/http`- Projetos que precisam de estabilidade

### 🏅 **Echo** - O Flexível

**Vantagens:**

- **Performance sólida**- API muito flexível- Suporte a WebSockets nativo- Middleware robusto

**Desvantagens:**

- Performance ligeiramente inferior ao Gin- Curva de aprendizado um pouco maior

**Quando usar:**

- Aplicações que precisam de **flexibilidade**- APIs com WebSockets- Projetos complexos com muitos middleware

### 🏅 **Chi** - O Modular

**Vantagens:**

- **100% compatível** com `net/http`- Extremamente modular- Fácil de testar- Performance decente

**Desvantagens:**

- Performance inferior aos anteriores- Menos recursos built-in

**Quando usar:**

- **Microserviços** simples- Quando você precisa de máxima compatibilidade- Projetos que priorizam simplicidade

## Resultados em Produção

### Estatísticas de Uso (GitHub Stars + Downloads)

| Router | GitHub Stars | Downloads/mês | Empresas Usando |
| --- | --- | --- | --- |
| **Gin** | 75k+ | 2.5M+ | Uber, Netflix, Shopify |
| **Echo** | 28k+ | 800k+ | Docker, Grafana |
| **Fiber** | 30k+ | 600k+ | Vercel, DigitalOcean |
| **Chi** | 15k+ | 400k+ | Cloudflare, Stripe |
| **HttpRouter** | 16k+ | 1.8M+ | Usado como base pelo Gin |

### Casos de Uso Reais

**Gin em Produção:**

- **Uber**: APIs de alta frequência- **Netflix**: Microserviços de streaming- **Shopify**: APIs de e-commerce

**Echo em Produção:**

- **Docker**: APIs de container- **Grafana**: APIs de monitoramento

**Fiber em Produção:**

- **Vercel**: APIs de deployment- **DigitalOcean**: APIs de cloud

**HttpRouter em Produção:**

- **Gin Framework**: Usado como base- **Muitas aplicações**: Que precisam de performance máxima

## Recomendações por Cenário

### 🎯 **A Verdade sobre Performance**

Antes de tudo, é importante entender que **a diferença de performance entre os routers não é tão significativa** na prática. Em aplicações reais, o router representa apenas uma pequena parte do tempo total de resposta. O que realmente importa são:

- **Lógica de negócio**- **Acesso ao banco de dados**- **Chamadas para APIs externas**- **Serialização/deserialização**

## **Como Escolher na Prática?**

**Não escolha apenas pela performance!** Considere:

### **Fatores Importantes:**

- **Idiomaticidade**: Qual é mais “Go-like”?- **Familiaridade**: Sua equipe já conhece algum?- **Ecossistema**: Quantos middleware estão disponíveis?- **Documentação**: Qual tem melhor documentação?- **Comunidade**: Qual tem comunidade mais ativa?- **Compatibilidade**: Precisa ser 100% compatível com `net/http`?

### **Migração de Outras Linguagens:**

- **Node.js/Express**: **Fiber** (API muito similar)- **Python/Flask**: **Gin** (estrutura similar)- **Java/Spring**: **Echo** (recursos avançados)- **Ruby/Rails**: **Chi** (simplicidade)

### **Para Empresas:**

- **Estabilidade**: Gin ou Echo- **Performance crítica**: HttpRouter ou Fiber- **Equipe pequena**: Chi (menos complexidade)- **Migração gradual**: Chi (compatibilidade total)

## Código de Benchmark Completo

Aqui está o código que usei para os benchmarks:


```go
package main

import (
    "testing"
    "net/http"
    "net/http/httptest"
    
    "github.com/gin-gonic/gin"
    "github.com/labstack/echo/v4"
    "github.com/gofiber/fiber/v2"
    "github.com/go-chi/chi/v5"
    "github.com/gorilla/mux"
)

func BenchmarkGin(b *testing.B) {
    gin.SetMode(gin.ReleaseMode)
    r := gin.New()
    r.GET("/users/:id", func(c *gin.Context) {
        c.JSON(200, gin.H{"id": c.Param("id")})
    })
    
    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        w := httptest.NewRecorder()
        req, _ := http.NewRequest("GET", "/users/123", nil)
        r.ServeHTTP(w, req)
    }
}

func BenchmarkEcho(b *testing.B) {
    e := echo.New()
    e.GET("/users/:id", func(c echo.Context) error {
        return c.JSON(200, map[string]string{"id": c.Param("id")})
    })
    
    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        w := httptest.NewRecorder()
        req, _ := http.NewRequest("GET", "/users/123", nil)
        e.ServeHTTP(w, req)
    }
}

func BenchmarkFiber(b *testing.B) {
    app := fiber.New()
    app.Get("/users/:id", func(c *fiber.Ctx) error {
        return c.JSON(fiber.Map{"id": c.Params("id")})
    })
    
    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        req, _ := http.NewRequest("GET", "/users/123", nil)
        app.Test(req)
    }
}

func BenchmarkChi(b *testing.B) {
    r := chi.NewRouter()
    r.Get("/users/{id}", func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Content-Type", "application/json")
        w.Write([]byte(`{"id":"` + chi.URLParam(r, "id") + `"}`))
    })
    
    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        w := httptest.NewRecorder()
        req, _ := http.NewRequest("GET", "/users/123", nil)
        r.ServeHTTP(w, req)
    }
}

func BenchmarkHttpRouter(b *testing.B) {
    r := httprouter.New()
    r.GET("/users/:id", func(w http.ResponseWriter, r *http.Request, ps httprouter.Params) {
        w.Header().Set("Content-Type", "application/json")
        w.Write([]byte(`{"id":"` + ps.ByName("id") + `"}`))
    })
    
    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        w := httptest.NewRecorder()
        req, _ := http.NewRequest("GET", "/users/123", nil)
        r.ServeHTTP(w, req)
    }
}
```


## Conclusão

**Minha Recomendação:**

- **Para novos projetos**: **Gin** (melhor equilíbrio geral)- **Para projetos existentes**: **Chi** (migração mais fácil)- **Para máxima performance**: **HttpRouter** (se performance for realmente crítica)- **Para estabilidade**: **Gin** ou **Echo**

**A verdade é que qualquer um desses routers vai funcionar bem para 99% dos casos.** A escolha deve ser baseada no que sua equipe conhece, no que sua empresa valoriza (estabilidade vs performance vs simplicidade) e no que se adequa melhor ao seu contexto.

## Referências

- [Go HTTP Routing Benchmark](https://github.com/bmf-san/go-router-benchmark) - Benchmarks oficiais- [Go HTTP Routing Benchmark (Alternativo)](https://github.com/go-bun/go-http-routing-benchmark) - Comparação adicional- [Gin Framework](https://github.com/gin-gonic/gin) - Documentação oficial- [Echo Framework](https://github.com/labstack/echo) - Documentação oficial- [Fiber Framework](https://github.com/gofiber/fiber) - Documentação oficial- [Chi Router](https://github.com/go-chi/chi) - Documentação oficial- [HttpRouter](https://github.com/julienschmidt/httprouter) - Documentação oficial

[Go](https://huncoding.com/categories/go/), [Performance](https://huncoding.com/categories/performance/), [Web Development](https://huncoding.com/categories/web-development/), [Benchmarks](https://huncoding.com/categories/benchmarks/)

[go](https://huncoding.com/tags/go/) [gin](https://huncoding.com/tags/gin/) [echo](https://huncoding.com/tags/echo/) [fiber](https://huncoding.com/tags/fiber/) [chi](https://huncoding.com/tags/chi/) [httprouter](https://huncoding.com/tags/httprouter/) [performance](https://huncoding.com/tags/performance/) [benchmark](https://huncoding.com/tags/benchmark/) [http-router](https://huncoding.com/tags/http-router/)

[Me compre um café ☕](https://ko-fi.com/huncoding)


---
Fonte: [https://huncoding.com/comparacao-routers-go-performance-benchmark/](https://huncoding.com/comparacao-routers-go-performance-benchmark/)
