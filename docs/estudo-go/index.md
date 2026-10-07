# Curso de Go pelo payment-processor

O ponto de partida é um repositório em construção. Hoje ele contém quatro executáveis mínimos, contratos Protobuf ainda sem RPCs, uma máquina de estados genérica funcional, um cache concorrente funcional, migrações SQL e infraestrutura declarativa. Essa diferença entre desenho e implementação é útil para aprender a ler código com rigor.

O percurso atual é [Fundamentos](01-fundamentos/index.md) → [Interfaces](03-interfaces/interfaces-na-fsm.md) → [Erros](04-erros/cadeia-de-erros.md) → [Generics](05-generics/machine-generica.md) → [Testes](08-testes/testando-fsm.md) → [FSM](11-fsm/index.md) → [Concorrência](06-concorrencia/index.md) → [Cache](12-cache/index.md). A FSM e o cache fornecem exemplos reais sem substituir o foco em Go. O [roadmap](roadmap.md) separa capítulos completos de módulos ainda introdutórios.

## Como usar o curso

1. Leia [Como estudar](como-estudar.md) e [Mapa do projeto](mapa-do-projeto.md).
2. Em cada capítulo, abra os arquivos de origem indicados e compare os trechos com o checkout atual.
3. Execute os comandos apenas no ambiente indicado; os exemplos da FSM não exigem stack de serviços.
4. Resolva os exercícios antes de avançar para o checkpoint.

Se um componente só constar de um ADR, trate-o como decisão planejada. O [guia do conceito ao código](conceito-para-codigo.md) mostra como fazer essa distinção.
