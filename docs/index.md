# Go no payment-processor

Este é um material de estudo organizado a partir do projeto desenvolvido no curso da HunCoding. Ele complementa o aprendizado com explicações progressivas da linguagem e das decisões que existem neste checkout; não é documentação oficial da HunCoding.

## Como usar este material

Siga a trilha na ordem do menu: conceito, exemplo mínimo quando necessário, código real, exercício e retorno ao projeto. Compare sempre os trechos marcados como origem com o arquivo indicado e use o [mapa do projeto](estudo-go/mapa-do-projeto.md) para separar comportamento implementado de arquitetura planejada.

Comece por [Como estudar](estudo-go/como-estudar.md) e depois avance para [Fundamentos](estudo-go/01-fundamentos/index.md). O [roadmap](estudo-go/roadmap.md) informa quais módulos já têm laboratório de código.

## Projeto usado no estudo

O repositório reúne os executáveis `gateway`, `ledger`, `fraud` e `investigator`. Neste momento, seus `main` ainda são pontos de entrada mínimos; a comunicação gRPC, Kafka e os fluxos completos descritos na arquitetura permanecem etapas futuras. Os estudos de caso funcionais são `pkg/fsm` e `pkg/memcache`.

As fontes de arquitetura e operação permanecem em [Arquitetura](architecture.md), [Runbook](runbook.md) e [ADRs](adr/0001-monorepo-with-independent-deployments.md).

## Curso e referências

O material acompanha o estudo do curso **Golang Avançado — Microsserviços, gRPC, Kafka, IA e Antifraude**.

- [Ver curso na Udemy](https://www.udemy.com/course/golang-avancado-microsservicos-grpc-kafka-ia-antifraude/?couponCode=MT261005G1)
- [Canal HunCoding no YouTube](https://www.youtube.com/@huncoding)

## Rodar este site

Na raiz do repositório, com Docker disponível:

```bash
make docs-serve
```

Abra <http://localhost:8000>. Para validar a configuração e os links internos, use `make docs-build`. Os comandos usam um container Python separado; a aplicação Go não depende de MkDocs. Não é necessário iniciar Postgres nem os serviços para ler o curso.
