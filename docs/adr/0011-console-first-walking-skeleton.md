# ADR 0011: Console shipped first as a walking skeleton

## Context

The operator console could be built at the end, after every backend
capability exists, or shipped ready from day one. The system is also
a course: learners build the backend module by module and need
visible progress to stay motivated.

## Decision

Ship the console complete from the start and make it degrade by
capability. Every panel probes the backend it needs: the gateway
health endpoint, the read models and the SSE feed. A missing
capability renders a locked state naming the course module that
unlocks it, never an error.

Two consequences for the backend shape. First, a minimal gateway
goes live early (the walking skeleton), so the console has an origin
to talk to while the rest is under construction. Second, the browser
never needs CORS: the vite dev server and the nginx image both proxy
the API under the same origin, and the SSE handlers push an opening
comment so buffering proxies release the stream immediately.

## Consequences

Positive: progress is visible after every module, the console doubles
as a manual test harness (payment presets replace curl), and the
proxy setup mirrors how real deployments put an edge in front of an
API.

Negative: capability probing adds polling requests against the local
gateway, and the locked state labels couple the console copy to the
course module numbering.
