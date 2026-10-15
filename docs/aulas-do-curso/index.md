# Aulas do curso

Esta seção reconstrói as aulas a partir dos 24 decks em `materiais/slides/`. Ela segue a sequência do professor, mas **não é transcrição de slides nem uma coleção de PDFs**: cada página desenvolve o problema, o modelo mental, os exemplos, o estado do repositório e os trade-offs. Os PDFs permanecem como fonte editorial local, fora do site.

O [Curso de Go](../estudo-go/index.md) é outra trilha: reorganiza os mesmos conceitos para estudo progressivo. Para aprofundar um assunto, vá da aula ao tutorial, depois ao código e aos testes. Use os [artigos do professor](../estudo-go/referencias-do-professor.md) como leitura complementar; a documentação oficial confirma comportamento normativo de linguagem e APIs.

!!! warning "Aula, decisão e implementação não são sinônimos"
    Os slides podem mostrar código de uma etapa futura como exemplo. O [código e os testes](../estudo-go/mapa-do-projeto.md) dizem o que existe neste checkout; a [visão do projeto](../visao-do-projeto.md) descreve o destino. Os [ADRs](../adr/0001-monorepo-with-independent-deployments.md) registram decisões arquiteturais vigentes. Se houver divergência, ela deve ser documentada e a implementação deve convergir; o ADR não muda por causa do slide ou do código.

## Mapa das 24 aulas

O [catálogo machine-readable](../estudo-go/aulas-do-curso.yaml) registra ID estável, título confirmado visualmente, módulo, aula, páginas, temas, referências, status e página editorial de destino. Nesta fase, cinco aulas estão publicadas; as demais aparecem abaixo somente para orientar a leitura, sem páginas vazias.

| Bloco do curso | Decks | Aulas publicadas agora |
|---|---:|---|
| Apresentação | 1 | — |
| Go na Prática | 6 | [Generics em Go](01-go-na-pratica/generics-em-go.md) |
| Arquitetura e O Alicerce | 4 | — |
| FSM, cache e batching | 3 | [Máquina de Estados Finita](03-fsm/maquina-estados-finita.md), [Dynamic Batching](05-batching/dynamic-batching.md) |
| Fraud Domain | 2 | — |
| Platform | 2 | — |
| Ledger | 2 | [Double-Entry e Idempotência](11-ledger/double-entry-idempotencia.md) |
| Gateway | 2 | [Streaming com SSE e o EventHub](12-gateway/sse-eventhub.md) |
| Produção e síntese | 2 | — |

Os **19 decks restantes**, já identificados no catálogo mas ainda sem página editorial, são:

| Bloco | Aulas a converter na Fase S2 |
|---|---|
| Apresentação | O Motor Transacional |
| Go na Prática | Interfaces como Portas; Goroutines, Channels e Select; sync.RWMutex, WaitGroup, Once; context.Context; Erros em Go |
| Arquitetura e O Alicerce | ADRs: as Decisões Registradas; Um Repositório, Quatro Serviços; Protocol Buffers; gRPC Core e HTTP/2 |
| FSM, cache e batching | Cache Shardado com TTL |
| Fraud Domain | Inferência de ML In-Process; Sigmoid sem o Pacote math |
| Platform | Teoria: a camada platform/; kafka.go: Writer, Reader e EnsureTopics |
| Ledger | Modo Degradado |
| Gateway | Rate Limiting na Borda |
| Produção e síntese | Do Docker Compose ao GKE; Nenhuma Escolha é de Graça |

## Como usar uma aula

1. Comece pela motivação e tente explicar o diagrama sem olhar o código.
2. Separe o mecanismo genérico da política de domínio e observe as marcações **implementado**, **parcial** ou **arquitetura-alvo**.
3. Confira no checkout os arquivos citados como atuais e os testes que sustentam o comportamento.
4. Siga os links para o tutorial progressivo, os artigos selecionados e a documentação oficial.
5. Responda às perguntas de revisão antes de avançar.

Para a ordem de estudo por conceito, veja [Como estudar](../estudo-go/como-estudar.md) e o [roadmap](../estudo-go/roadmap.md).
