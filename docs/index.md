# Go no payment-processor

Este site reúne o [curso progressivo de Go](estudo-go/index.md) e as referências existentes do projeto. O curso parte da implementação que está neste checkout: alguns componentes descritos na arquitetura ainda são objetivos de módulos futuros.

Comece por [Como estudar](estudo-go/como-estudar.md) e consulte o [mapa do projeto](estudo-go/mapa-do-projeto.md) antes de abrir um capítulo. O [roadmap](estudo-go/roadmap.md) separa páginas completas de páginas introdutórias.

As fontes de arquitetura e operação permanecem em [Arquitetura](architecture.md), [Runbook](runbook.md) e [ADRs](adr/0001-monorepo-with-independent-deployments.md).

## Rodar este site

Na raiz do repositório, com Docker disponível:

```bash
make docs-serve
```

Abra <http://localhost:8000>. Para validar a configuração e os links internos, use `make docs-build`. Os comandos usam um container Python separado; a aplicação Go não depende de MkDocs. Não é necessário iniciar Postgres nem os serviços para ler o curso.
