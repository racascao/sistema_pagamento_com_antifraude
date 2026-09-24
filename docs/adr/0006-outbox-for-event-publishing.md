# ADR 0006: Outbox pattern for event publishing

## Context

The ledger persists a payment in Postgres and announces it on Kafka.
Writing to two systems without coordination loses events when the
process dies between the commit and the publish, or publishes events
for transactions that rolled back. Consumers downstream include the
investigator, so a lost manual review event means a case nobody
looks at.

## Decision

Write the event into an outbox table inside the same transaction as
the payment. A relay polls unpublished rows, writes them to Kafka
and marks them published after the broker acknowledges.

Delivery is at least once. Consumers are idempotent, keyed by
payment id, which the review updates already are.

## Consequences

Positive: the payment and its event commit or roll back together,
no event is lost, the relay recovers from crashes by construction.

Negative: events arrive with polling latency, 200 milliseconds in
the default configuration, and duplicates are possible. Both are
acceptable for an asynchronous investigation flow.
