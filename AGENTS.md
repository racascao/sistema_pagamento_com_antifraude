Contexto: payment-processor, sistema de pagamentos em Go com 4 microsservicos (gateway ,ledger, fraud, investigator), Clean Architecture por serviço (domain/usecase/infra/adapter), gRPC entre serviços, Kafka para eventos assíncronos.

Antes de mudanças arquiteturais ou novos módulos do curso, leia `docs/visao-do-projeto.md`, `docs/architecture.md` e os ADRs relevantes. A visão descreve o destino; código e testes descrevem o estado atual.

Ao aprofundar `docs/estudo-go/`, consulte `docs/estudo-go/referencias-do-professor.yaml` e leia só os artigos relevantes. Eles são referências pedagógicas; código e testes definem o estado atual, ADRs registram decisões e a documentação oficial do Go define a linguagem e a stdlib.

Ao atualizar material didático, consulte `docs/estudo-go/aulas-do-curso.yaml`, leia o deck relevante, escolha artigos em `docs/estudo-go/referencias-do-professor.yaml`, confira código e testes, consulte os ADRs e use documentação oficial quando necessário. Se slide ou código divergir de um ADR, registre a divergência e a necessidade de convergência; não altere o ADR por esse motivo.

Estilo de código:
- Comentários só quando o porquê não é óbvio pelo nome ou pela estrutura. Nunca descreva o que o código já deixa claro. Nunca escreva bloco de doc de múltiplos parágrados, uma ou duas linhas bastam.
- Sem abstrações prematuras: três linhas parecidas são melhores que uma abstração genérica cedo demais. Só generalize quando o segundo uso real aparecer.
- Erros de negócio são sentinelas (errors.New), comparados com errors.Is, nunca com == depois de qualquer wrapping. Erros de infraestrutura ganham contexto com fmt.Errorf("...: %w", err) ao subir uma camada.
- Generics (type Foo[F any]) só quando o motor é genuinamente independente do domínio (uma maquina de estados, um cache, um batcher). Nunca como troca de interface{}, tentando evitar escrever o tipo concreto.
- Testes são table-driven por padrão. Um fake de teste implementa a interface mínima da porta, sem framework de mock.

Arquitetura
- domain/ não importa nada além da stdlib.
- usecase/ orquestra só contra interfaces (portas), nunca contra infraestrutura concreta.
- infra/ implementa as portas (Postgres, gRPC, Kafta, HTTP externo)
- adapter/ traduz transporte (proto <=> dominio)
- pkg/ é compartilhado entre serviços e não conhece nada do domínio de pagamentos

Antes de considerar uma tarefa concluída
- Rode go build ./... e go vet ./...
- Não adicione dependência nova sem justificar por que a stdlib não resolve.
