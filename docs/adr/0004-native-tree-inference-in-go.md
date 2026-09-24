# ADR 0004: Native decision tree inference in Go

## Context

The fraud check runs inside the synchronous authorization path with
a budget near 15 milliseconds. The classic setup serves the model
from a Python sidecar or a dedicated inference server, adding a
network hop, another runtime to operate and a serialization cost on
every call.

Gradient boosted trees, the standard model family for tabular fraud
data, reduce at inference time to comparisons and additions. Nothing
about them requires a machine learning runtime.

## Decision

Evaluate the ensemble natively in Go. The model is exported to a
JSON file of flat node arrays, validated at load time, and walked
directly. The scorer allocates nothing on the hot path and sits
behind the dynamic batcher.

Training stays outside this repository. The contract between
training and serving is the model file format documented in
tools/model.

## Consequences

Positive: benchmark shows around 8 nanoseconds per score with zero
allocations, no extra hop, no second runtime, the model ships inside
the binary and cannot drift from the deploy.

Negative: reimplementing inference means owning its correctness,
covered by the validation and scoring tests. Neural models would not
fit this approach, which is why the embedding port exists separately.
