# ADR 0003: gRPC between services, HTTP and SSE at the edge

## Context

The authorization path is latency sensitive: gateway to ledger to
fraud and back, all inside a budget of a few hundred milliseconds.
Internal calls benefit from binary serialization, multiplexed HTTP/2
connections and generated type safe clients. Public clients need a
protocol every language and tool understands, and operators need to
watch investigations progress in real time.

## Decision

Services talk gRPC internally. The gateway exposes JSON over HTTP to
the public and streams investigation progress with Server-Sent
Events instead of WebSockets.

SSE was chosen over WebSockets because the stream is one directional
by nature, works through plain HTTP infrastructure, reconnects for
free in browsers and needs no protocol upgrade handling.

## Consequences

Positive: typed contracts with compile time breakage on drift, cheap
connection reuse under load, a public API that curl can exercise.

Negative: two serialization layers exist at the boundary and the
proto files require a generation step in the workflow.
