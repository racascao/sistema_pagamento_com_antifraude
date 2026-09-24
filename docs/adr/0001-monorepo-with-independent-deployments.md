# ADR 0001: Monorepo with independent deployments

## Context

The system is composed of four services: gateway, ledger, fraud and
investigator. They share gRPC contracts, domain conventions and a
local environment. The team is small and every service is versioned,
reviewed and released by the same people.

Splitting into one repository per service would require publishing
the proto contracts as a versioned artifact, coordinating releases
across repositories and cloning four projects to run the system.

## Decision

Keep every service in a single repository with a single Go module.
Each service remains an independent deployment: its own binary, its
own container image, its own Deployment and its own scaling policy.

The microservice boundary is the deploy unit, not the repository.

## Consequences

Positive: one clone runs everything, contracts live next to their
consumers, cross service refactors land in one commit, checkpoints
per course module are simple tags.

Negative: CI needs path filters to avoid rebuilding everything on
every change once the project grows. Repository level access control
is not possible, which can matter for larger organizations.
