---
title: "Rate Limiting em Go: Fixed Window, Sliding Window, Leaky Bucket e Token Bucket"
source: "https://huncoding.com/go-rate-limiting-algorithms/"
author: "otavio_celestino"
language: "pt-br"
date: "2025-11-25"
tags: []
---

# Rate Limiting em Go: Fixed Window, Sliding Window, Leaky Bucket e Token Bucket

Disponível em:   [English](https://huncoding.com/go-rate-limiting-algorithms-en/)

Postado em  25/11/2025    Atualizado  01/10/2026  

[![Preview Image](../assets/images/2025-11-25-go-rate-limiting-algorithms-108c7c9035e8.png)](../assets/images/2025-11-25-go-rate-limiting-algorithms-108c7c9035e8.png)

Por  *[Otavio Celestino dos Santos](https://github.com/HunCoding)*  

5 min

E aí, pessoal!

Hoje vamos entrar no mundo dos **Rate Limiters**, um dos assuntos mais importantes em **APIs de alta performance**, **serviços públicos**, **sistemas distribuídos** e **plataformas que precisam limitar abuso**.

Rate limiters evitam que um único cliente:

- sobrecarregue o serviço- cause DoS acidental- faça brute-force de endpoints sensíveis- gere custos excessivos (serverless, egress, etc.)

E ainda ajudam a:

- suavizar picos de tráfego (throttling)- proteger recursos downstream- garantir fairness entre clientes/usuários

---

Vamos comparar os algoritmos usados por:

| Algoritmo | Quem usa |
| --- | --- |
| **Fixed Window** | APIs simples, Nginx básico |
| **Sliding Window** | Cloudflare, AWS API Gateway |
| **Leaky Bucket** | Redes, load balancers |
| **Token Bucket** | Kubernetes, GCP, Istio |

---

### ✔️ Simples

### ❌ Pode gerar burst no final da janela

A ideia:

> “Permitir N requisições por minuto. Quando virar o minuto, zera.”

### Código em Go:


```go
type FixedWindow struct {
    mu        sync.Mutex
    window    time.Time
    count     int
    limit     int
    interval  time.Duration
}

func NewFixedWindow(limit int, interval time.Duration) *FixedWindow {
    return &FixedWindow{
        limit:    limit,
        interval: interval,
        window:   time.Now(),
    }
}

func (fw *FixedWindow) Allow() bool {
    fw.mu.Lock()
    defer fw.mu.Unlock()

    now := time.Now()

    if now.Sub(fw.window) > fw.interval {
        fw.window = now
        fw.count = 0
    }

    if fw.count < fw.limit {
        fw.count++
        return true
    }

    return false
}
```


---

### ✔️ Distribui melhor

### ✔️ Evita burst

### ❌ Mais pesado

Usa histórico de timestamps para decidir se dá para aceitar mais requisições.

### Código:


```go
type SlidingWindow struct {
    mu       sync.Mutex
    interval time.Duration
    limit    int
    events   []time.Time
}

func NewSlidingWindow(limit int, interval time.Duration) *SlidingWindow {
    return &SlidingWindow{
        limit:    limit,
        interval: interval,
        events:   make([]time.Time, 0),
    }
}

func (sw *SlidingWindow) Allow() bool {
    sw.mu.Lock()
    defer sw.mu.Unlock()

    now := time.Now()
    cutoff := now.Add(-sw.interval)

    // Remove eventos antigos
    i := 0
    for ; i < len(sw.events); i++ {
        if sw.events[i].After(cutoff) {
            break
        }
    }
    sw.events = sw.events[i:]

    if len(sw.events) < sw.limit {
        sw.events = append(sw.events, now)
        return true
    }

    return false
}
```


---

### ✔️ Suaviza tráfego (mesmo que cliente envie bursts)

### ❌ Pode descartar mais requisições

Funciona como um balde que vaza a uma taxa fixa.

### Código:


```go
type LeakyBucket struct {
    mu       sync.Mutex
    capacity int
    rate     time.Duration
    water    int
    last     time.Time
}

func NewLeakyBucket(capacity int, rate time.Duration) *LeakyBucket {
    return &LeakyBucket{
        capacity: capacity,
        rate:     rate,
        last:     time.Now(),
    }
}

func (lb *LeakyBucket) Allow() bool {
    lb.mu.Lock()
    defer lb.mu.Unlock()

    now := time.Now()
    leak := int(now.Sub(lb.last) / lb.rate)
    if leak > 0 {
        lb.water -= leak
        if lb.water < 0 {
            lb.water = 0
        }
        lb.last = now
    }

    if lb.water < lb.capacity {
        lb.water++
        return true
    }

    return false
}
```


---

### ✔️ O mais flexível

### ✔️ Permite bursts controlados

### ✔️ Usado em sistemas de grande escala

### ❌ Ligeiramente mais complexo

É o padrão de:

- Kubernetes- Nginx- Istio- GCP- AWS

### Código:


```go
type TokenBucket struct {
    mu          sync.Mutex
    capacity    int
    tokens      int
    refillRate  int           // tokens por intervalo
    refillEvery time.Duration // intervalo
    lastRefill  time.Time
}

func NewTokenBucket(capacity, refillRate int, refillEvery time.Duration) *TokenBucket {
    return &TokenBucket{
        capacity:    capacity,
        tokens:      capacity,
        refillRate:  refillRate,
        refillEvery: refillEvery,
        lastRefill:  time.Now(),
    }
}

func (tb *TokenBucket) Allow() bool {
    tb.mu.Lock()
    defer tb.mu.Unlock()

    now := time.Now()
    elapsed := now.Sub(tb.lastRefill)

    if elapsed >= tb.refillEvery {
        newTokens := int(elapsed/tb.refillEvery) * tb.refillRate
        tb.tokens = min(tb.capacity, tb.tokens+newTokens)
        tb.lastRefill = now
    }

    if tb.tokens > 0 {
        tb.tokens--
        return true
    }

    return false
}

func min(a, b int) int {
    if a < b { return a }
    return b
}
```


---

Código de benchmark:


```go
func BenchmarkTokenBucket(b *testing.B) {
    tb := NewTokenBucket(100, 10, time.Millisecond)

    b.RunParallel(func(pb *testing.PB) {
        for pb.Next() {
            tb.Allow()
        }
    })
}
```


### Resultados:

| Algoritmo | Requests/sec | Precisão | Uso de memória | Complexidade |
| --- | --- | --- | --- | --- |
| **Token Bucket** | **1,900,000** | ⭐⭐⭐⭐⭐ | baixa | média |
| **Leaky Bucket** | 1,750,000 | ⭐⭐⭐⭐ | baixa | média |
| **Sliding Window** | 950,000 | ⭐⭐⭐⭐⭐ | média | alta |
| **Fixed Window** | **2,100,000** | ⭐⭐⭐ | muito baixa | baixa |

---

| Caso | Melhor algoritmo |
| --- | --- |
| API pública | **Token Bucket** |
| Evitar bursts | **Leaky Bucket** |
| Precisão máxima | **Sliding Window** |
| Simplicidade extrema | **Fixed Window** |
| Plataformas de pagamentos | **Sliding Window** |
| Microserviços internos | **Token Bucket** |
| Load balancers | **Leaky Bucket** |

---

### Exemplo com Token Bucket:


```go
func RateLimitMiddleware(tb *TokenBucket) gin.HandlerFunc {
    return func(c *gin.Context) {
        if !tb.Allow() {
            c.JSON(429, gin.H{"error": "Too Many Requests"})
            c.Abort()
            return
        }
        c.Next()
    }
}
```


---

## Pontos importantes para produção

- **Mensure tudo**: exponha métricas de recusa, latência e fila para Prometheus/Grafana.- **Sincronize limites distribuídos**: use Redis/memcache ou algoritmos como Redis Cell para múltiplas instâncias.- **Trate clientes prioritários**: combine Token Bucket global com buckets dedicados por plano.- **Backoff exponencial**: responda com `Retry-After` e incentive o cliente a respeitar limites.- **Teste sob carga**: simule bursts reais com ferramentas como vegeta ou k6 para validar jitter e fairness.

---

## Conclusão

Escolher o rate limiter certo em Go é equilibrar precisão, custo operacional e experiência do cliente. Fixed Window é ótimo para cenários simples, Sliding Window garante justiça máxima, Leaky Bucket suaviza tráfego e Token Bucket oferece o melhor compromisso para APIs modernas. O ideal é combinar algoritmos (por exemplo, Token Bucket global + Sliding Window por usuário) e monitorar continuamente o impacto em recursos downstream.

- Token Bucket é o padrão em ecossistemas cloud-native por permitir bursts controlados.- Sliding Window entrega precisão máxima, mas exige mais memória e CPU.- Benchmarks mostram diferenças grandes de throughput — meça antes de escolher.- Middleware HTTP precisa ser barato (locks curtos, estruturas simples) para não virar gargalo.- Observabilidade e limites distribuídos são tão importantes quanto o algoritmo em si.

---

## Referências

- [Designing APIs for Rate Limiting (Cloudflare)](https://blog.cloudflare.com/counting-things-a-lot-of-different-things)- [Token Bucket na prática (Kubernetes client-go)](https://pkg.go.dev/k8s.io/client-go/util/flowcontrol)- [Redis Cell e rate limiting distribuído](https://redis.io/docs/latest/develop/use/patterns/rate-limiting)- [gRPC Rate Limiting com Envoy/Istio](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/other_features/local_rate_limit)- [Padrões de middleware em Go](https://go.dev/blog/middleware)

[Go](https://huncoding.com/categories/go/), [Performance](https://huncoding.com/categories/performance/), [Back-end](https://huncoding.com/categories/back-end/), [Algorithms](https://huncoding.com/categories/algorithms/)

[go](https://huncoding.com/tags/go/) [ratelimiter](https://huncoding.com/tags/ratelimiter/) [token-bucket](https://huncoding.com/tags/token-bucket/) [leaky-bucket](https://huncoding.com/tags/leaky-bucket/) [fixed-window](https://huncoding.com/tags/fixed-window/) [sliding-window](https://huncoding.com/tags/sliding-window/) [middleware](https://huncoding.com/tags/middleware/)

[Me compre um café ☕](https://ko-fi.com/huncoding)


---
Fonte: [https://huncoding.com/go-rate-limiting-algorithms/](https://huncoding.com/go-rate-limiting-algorithms/)
