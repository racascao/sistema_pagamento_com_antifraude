# ADR 0009: Metrics live in Grafana, workflow lives in the console

## Context

The operator console needs live payment events and case detail. It is
tempting to also render latency percentiles, decision rates and queue
depths inside it, which means rebuilding time series storage, window
functions and alerting that dedicated tools already do well.

The frontend also needs an event source. The browser cannot consume
Kafka directly: it would require exposing brokers publicly, per user
authentication on consumer groups and a protocol browsers do not
speak.

## Decision

Split by concern. Workflow surfaces (live feed, review queue, case
detail, human decisions) belong to the console, fed by the gateway:
REST read models proxied from the ledger over gRPC, and Server-Sent
Events fanned out by an in process hub that consumes the existing
payments and reviews topics once.

Aggregated metrics belong to Prometheus and Grafana. Every service
exposes /metrics, Prometheus scrapes, and one dashboard versioned in
the repository is provisioned as code. The same manifests run on
compose, kind and the cloud cluster. In the cloud, Managed Service
for Prometheus is enabled on the cluster (see ADR 0010) for teams
that do not want to operate metric storage.

## Consequences

Positive: the console stays small and product shaped, metrics get
proper windowing and alerting for free, the dashboard is reviewable
in pull requests, and the Kafka topics gain a second consumer without
any producer change.

Negative: two places to look at during an incident, mitigated by
linking the dashboard from the console. The SSE hub holds subscriber
state per gateway replica, acceptable because subscribers reconnect
and the feed is observational, not transactional.
