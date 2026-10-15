# Double-Entry e Idempotência

## Onde esta aula entra no curso

Módulo **11 — Ledger**, aula **01**. Depois de contratos e persistência, a aula estabelece duas garantias diferentes para a autorização: lançamentos contábeis balanceados e segurança ao repetir um pedido cujo resultado anterior ficou ambíguo. Pré-requisitos: transações SQL, erros e chamadas remotas com prazo.

!!! warning "Estrutura SQL parcial; caso de uso ainda planejado"
    As migrações `00002_create_payments_and_entries.sql`, `00003_create_idempotency_keys.sql` e `00004_create_outbox.sql` existem. `internal/ledger/domain/payment.go`, `internal/ledger/usecase/authorize.go` e `hashCharge` do slide **não** existem neste checkout. Nenhum serviço Ledger funcional grava uma autorização completa.

## O problema que motiva a aula

Um `UPDATE accounts SET balance = ...` parece suficiente até alguém pedir o histórico de uma cobrança, disputar um estorno ou enviar duas autorizações simultâneas. O saldo final sozinho não explica **por que** chegou ali; uma sequência ingênua de leitura–cálculo–escrita também pode perder atualizações concorrentes. Separadamente, quando o cliente recebe timeout, não sabe se a cobrança falhou ou se só a resposta se perdeu. Repetir sem protocolo pode cobrar duas vezes.

## Modelo mental

Pense em dois eixos complementares:

```text
integridade do dinheiro: operação → lançamentos de débito/crédito → soma assinada = 0
segurança do retry:     chave + intenção → resposta armazenada ou conflito
```

A dupla entrada modela **o que aconteceu** e conserva um histórico auditável. A idempotência modela **a identidade da tentativa lógica** e permite devolver o mesmo resultado quando a resposta anterior é incerta. Uma não substitui a outra.

## Conceitos apresentados

### Lançamentos em vez de saldo reescrito

Para uma operação, um lançamento de débito e outro de crédito representam lados opostos. Com a convenção do SQL atual — débito positivo, crédito negativo na soma — o invariante é `Σ débitos − Σ créditos = 0` por `payment_id`. O saldo é derivável dos lançamentos; o histórico não deve ser “corrigido” apagando linhas antigas. Um estorno conceitual cria **novos lançamentos compensatórios**, preservando o rastro da operação original.

“Insert-only” é a política desejada para o histórico, mas exige proteção efetiva de escrita: a tabela atual **não** contém uma proibição geral de `UPDATE` ou `DELETE`. Tampouco o trigger sozinho garante exatamente dois lançamentos por pagamento; ele verifica que os lançamentos inseridos para o mesmo `payment_id` somem zero no momento da checagem. A regra de domínio e as permissões/constraints adicionais ainda precisam ser implementadas e testadas.

### Timeout e intenção repetida

Uma requisição pode ter sido concluída no servidor enquanto sua resposta se perdeu. O cliente envia a mesma `Idempotency-Key` no retry. O servidor deve comparar uma representação estável da **intenção** (`hashCharge` no exemplo do slide) com `request_hash` armazenado:

| Mesmo key? | Mesmo hash? | Semântica pretendida |
|---|---|---|
| Não | — | Nova operação, sujeita a validação normal. |
| Sim | Sim | Reproduzir a resposta persistida, sem cobrar de novo. |
| Sim | Não | Conflito: a chave foi reutilizada para outra intenção. |

O hash só é útil se os campos de negócio relevantes forem serializados de modo canônico; um hash de bytes de JSON com ordenação ou campos variáveis inconsistentes pode classificar pedidos equivalentes de forma errada. A escolha exata e sua validação pertencem à futura implementação.

## O que o professor está construindo

O fluxo-alvo da aula une decisão de pagamento, lançamentos, revisão quando cabível, evento de outbox e registro idempotente **numa transação local PostgreSQL**. Assim, um commit não deixa a cobrança visível sem a resposta de retry ou sem a intenção de publicar evento. A chamada externa ao processador e os casos de incerteza ainda exigem desenho cuidadoso; uma transação de banco não torna uma rede externa transacional por si só.

## Código apresentado na aula

O slide mostra funções conceituais `Balanced(entries []Entry) bool` e `hashCharge(...)` em arquivos de `internal/ledger/`. São **código da aula / arquitetura futura**, não trechos atuais do repositório.

O SQL **atual** contém uma checagem diferida:

```sql
SELECT COALESCE(SUM(CASE direction
    WHEN 'debit' THEN amount_cents
    ELSE -amount_cents END), 0)
FROM ledger_entries
WHERE payment_id = NEW.payment_id;
```

Em `00002_create_payments_and_entries.sql`, a função `check_double_entry()` levanta exceção se essa soma for diferente de zero; o trigger é `DEFERRABLE INITIALLY DEFERRED` e roda após `INSERT`. Em `00003_create_idempotency_keys.sql`, a tabela tem `key` como chave primária, `request_hash` e `response_body`. Esses objetos de banco são fundamentos, não evidência de `Authorize` implementado ou de teste de integração transacional.

## Como isso aparece no projeto hoje

| Situação | Evidência | Limite |
|---|---|---|
| **PARCIAL** | Migração de `payments` e `ledger_entries` com trigger de balanceamento | Nenhum código Go grava pares ou estornos; o trigger não impõe insert-only nem exatamente dois lançamentos. |
| **PARCIAL** | Tabela `idempotency_keys` com hash e resposta | Não há lookup, replay, tratamento de conflito nem coordenação concorrente em um caso de uso. |
| **PARCIAL** | Migração de outbox | Não há gravação conjunta nem relay de publicação. |
| **PLANEJADO** | Domínio e `Authorize` citados nos slides | Arquivos ausentes. |

## Padrões de projeto e arquitetura

**Double-entry accounting** é um invariante contábil; **idempotency key** define uma identidade de operação na borda; **Transactional Outbox** preserva a intenção de publicar após o commit. A transação única é a fronteira de consistência entre registros locais. Nenhum desses padrões dispensa uma política explícita de concorrência ou torna a publicação no broker exatamente uma vez.

## Trade-offs

| Ganho | Custo | Por que aceitar aqui |
|---|---|---|
| Histórico explicável e estornos auditáveis | Mais linhas e consultas de agregação | Dinheiro precisa de rastreabilidade, não apenas de saldo final. |
| Retry seguro para o cliente | Armazenar resposta, hash e resolver concorrência da mesma chave | Timeout deixa a conclusão ambígua; repetir sem idempotência é arriscado. |
| Commit local para decisão + outbox | Relay assíncrono e possíveis duplicatas | Evita a janela de falha entre commit e publicação separada. |

## Relação com os ADRs

O [ADR 0002](../../adr/0002-postgres-as-the-single-database.md) adota PostgreSQL como banco do sistema. O [ADR 0006](../../adr/0006-outbox-for-event-publishing.md) exige gravar o evento na mesma transação do pagamento e aceita entrega *at least once* pelo relay. O SQL atual prepara parte do caminho; se implementação futura ou exemplo de slide divergir da decisão, deve convergir para o ADR.

## Aprofunde no tutorial

Leia [13. Postgres, idempotência e Outbox](../../estudo-go/13-postgres-outbox/index.md), [Erros](../../estudo-go/04-erros/index.md) e [9. Context](../../estudo-go/07-context/index.md). A [Arquitetura](../../architecture.md) apresenta o fluxo pretendido; o [Mapa do projeto](../../estudo-go/mapa-do-projeto.md) ajuda a confirmar o que compila hoje.

## Artigos do professor relacionados

O [panorama do curso](../../artigos-completos/pt/golang-avancado-curso-udemy.md) contextualiza o Ledger e a Outbox no sistema completo. Ele descreve o destino pedagógico, **não** prova que `Authorize` ou relay existam neste checkout.

## Documentação oficial

O comportamento de constraints diferidas e transações deve ser confirmado na [documentação do PostgreSQL sobre constraint triggers](https://www.postgresql.org/docs/current/sql-createtrigger.html) e em [transações](https://www.postgresql.org/docs/current/tutorial-transactions.html). A aplicação futura deve ser testada contra um Postgres real, não inferida somente do DDL.

## Perguntas para revisão

1. Por que um saldo sobrescrito não substitui o livro de lançamentos?
2. Qual soma o trigger atual verifica, e o que ele **não** garante?
3. Como um estorno preserva o histórico em vez de reescrevê-lo?
4. Por que timeout não significa que a cobrança falhou?
5. O que muda entre mesma chave com mesmo hash e mesma chave com hash diferente?
6. Quais registros precisam compartilhar a transação local?
7. Por que outbox implica aceitar duplicatas no consumidor?

## Checklist

- [ ] Distingo integridade contábil de idempotência de requisição.
- [ ] Sei localizar o trigger e a tabela de chaves nas migrações.
- [ ] Não apresento `Balanced`, `hashCharge` ou `Authorize` como código atual.
- [ ] Consigo explicar por que o banco sozinho não resolve a chamada ao processador externo.
