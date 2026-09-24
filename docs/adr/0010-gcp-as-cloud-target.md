# ADR 0010: GCP as the cloud target

## Context

The production infrastructure was first drafted for AWS with EKS, RDS,
MSK and Amazon Managed Prometheus. Two facts changed the calculus:
available GCP credits cover months of the projected footprint, and
the equivalent GCP services map one to one without touching a single
line of application code.

## Decision

Target GCP. The mapping keeps every architectural property:

| Concern | Service |
|---|---|
| Cluster | GKE Standard, two node pools, fraud pool tainted and autoscaled 1 to 8, ARM machine type |
| Database | Cloud SQL for PostgreSQL 16, regional availability, private IP only, pgvector supported |
| Events | Managed Service for Apache Kafka, same protocol the services already speak |
| Metrics | Managed Service for Prometheus, enabled at the cluster, in-cluster Grafana unchanged |
| Images | Artifact Registry |

The provider is configured with an optional mock access token so
terraform validate and plan run without credentials, keeping the
course promise that no cloud account is required before the final
module.

## Consequences

Positive: zero application changes, the deciding proof that the
services only depend on protocols, not providers. Managed Prometheus
comes enabled with one block instead of a separate workspace. The
node pools keep the independent scaling story intact.

Negative: Managed Kafka is a younger product than MSK and quota or
regional availability must be checked before apply. Cloud SQL private
IP requires the service networking peering, one more moving part in
the network module. Anyone deploying to AWS instead can recover the
old design from git history.
