# ADR 0002: Postgres as the single database, pgvector included

## Context

The ledger requires strict transactional integrity. The investigator
requires vector similarity search over historical fraud cases. The
obvious path adds a dedicated vector database next to the relational
one, which means one more component to operate, back up and secure.

## Decision

Use PostgreSQL 16 for everything. Money movement uses regular tables
with constraints and a deferred trigger enforcing double entry
balance. Fraud patterns live in the same instance using the pgvector
extension with an ivfflat index for cosine search.

A dedicated vector database is a deliberate future option, not a
starting requirement. The PatternStore port isolates the decision so
swapping to Qdrant changes one adapter.

## Consequences

Positive: one database to operate, one backup policy, transactions
across payments and reviews, identical setup in local and cloud
because RDS ships pgvector.

Negative: at hundreds of millions of vectors or heavy ANN load, a
dedicated engine performs better. The port makes that migration
mechanical when the scale justifies it.
