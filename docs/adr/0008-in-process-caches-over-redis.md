# ADR 0008: In process caches instead of Redis

## Context

Two hot path features need fast state: velocity counting per card
and the semantic cache of recently decided attempts. The reflex
answer is Redis. That adds a network round trip to the tightest part
of the system, a service to operate, and a failure mode where cache
unavailability degrades authorization latency.

## Decision

Keep both in process. Velocity uses a sharded TTL map. The semantic
cache holds recent embedding vectors behind a small rolling window.
Both are bounded in size and time.

The known tradeoff: with multiple fraud replicas, each holds
independent state. Velocity counting becomes per replica, softened
by hash balancing on card fingerprint at the gRPC client. The hard
limit stays enforced globally by the ledger idempotency and review
flow.

## Consequences

Positive: zero network cost on the hot path, two fewer failure
modes, nothing new to operate, memory bounded by construction.

Negative: state is not shared across replicas and resets on deploy.
When either becomes unacceptable, the ports allow a Redis adapter
without touching the pipeline.
