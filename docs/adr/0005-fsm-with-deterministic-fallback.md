# ADR 0005: FSM pipeline with deterministic fallback

## Context

The scoring flow has ordered stages with branching: enrichment, fast
rules, model scoring, semantic tiebreak, finalization. Implemented as
nested function calls, the branching logic disappears into control
flow and the failure behavior of each stage becomes implicit.

The model stage can fail or exceed its budget. A payment
authorization can never hang or crash because a model was slow.

## Decision

Model the pipeline as an explicit finite state machine. Each stage is
a named state with one handler. The machine bounds total hops,
records every transition with duration and error, and supports a
declared fallback per state.

The ml_score state falls back to finalize. Before returning the
error, the handler marks the decision as degraded and routes the
attempt to manual review. Availability wins over model coverage, and
the degradation is visible in the response instead of silent.

## Consequences

Positive: the pipeline topology is readable in one place, every run
produces a trace for observability, fallback behavior is declared
and tested, loops are structurally impossible.

Negative: the machine adds indirection for what is, on the happy
path, a linear flow. The trace allocation is accepted as the cost of
auditability.
