# Payment processor build and run targets.
#
# Windows users: run these targets inside WSL2.

SHELL := /bin/bash
GOBIN := $(shell go env GOPATH)/bin
COMPOSE := docker compose

.PHONY: help
help: ## List available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-18s %s\n", $$1, $$2}'

## ----- Development -----

.PHONY: setup
setup: ## Verify and install local tooling
	./scripts/setup.sh

.PHONY: proto
proto: ## Regenerate gRPC code from proto files
	mkdir -p proto/gen/go
	PATH=$$(go env GOPATH)/bin:$$PATH protoc --proto_path=proto \
		--go_out=proto/gen/go --go_opt=paths=source_relative \
		--go-grpc_out=proto/gen/go --go-grpc_opt=paths=source_relative \
		fraud/v1/fraud.proto ledger/v1/ledger.proto

.PHONY: build
build: ## Compile all services
	go build ./...

## ----- Local stack (Docker Compose) -----

.PHONY: up
up: ## Build and start the full local stack
	$(COMPOSE) up --build -d
	@echo "gateway on http://localhost:8080"
	@echo "console on http://localhost:3001"
	@echo "grafana on http://localhost:3000"

.PHONY: down
down: ## Stop the stack and remove volumes
	$(COMPOSE) down -v

.PHONY: logs
logs: ## Tail logs from every service
	$(COMPOSE) logs -f

.PHONY: ps
ps: ## Show stack status
	$(COMPOSE) ps

## ----- Demo requests -----

.PHONY: demo-approved
demo-approved: ## Send a payment that should be approved
	curl -s -X POST http://localhost:8080/v1/payments \
		-H 'Content-Type: application/json' \
		-H "Idempotency-Key: demo-$$$$(date +%s)" \
		-d '{"account_id":"00000000-0000-0000-0000-000000000002","card_fingerprint":"fp_demo_ok","amount_cents":5000,"currency":"BRL","merchant_category":"electronics"}' | jq .

.PHONY: demo-denied
demo-denied: ## Send a payment with a blocklisted card
	curl -s -X POST http://localhost:8080/v1/payments \
		-H 'Content-Type: application/json' \
		-H "Idempotency-Key: demo-$$$$(date +%s)" \
		-d '{"account_id":"00000000-0000-0000-0000-000000000002","card_fingerprint":"fp_stolen_card_001","amount_cents":5000,"currency":"BRL","merchant_category":"electronics"}' | jq .

.PHONY: demo-review
demo-review: ## Send an ambiguous payment that goes to manual review
	curl -s -X POST http://localhost:8080/v1/payments \
		-H 'Content-Type: application/json' \
		-H "X-Forwarded-For: 203.0.113.10" \
		-H "Idempotency-Key: demo-$$$$(date +%s)" \
		-d '{"account_id":"00000000-0000-0000-0000-000000000003","card_fingerprint":"fp_demo_review","amount_cents":150000,"currency":"BRL","merchant_category":"gift_cards"}' | jq .

.PHONY: demo-stream
demo-stream: ## Stream investigation progress (PAYMENT_ID=...)
	curl -N http://localhost:8080/v1/reviews/$(PAYMENT_ID)/stream

.PHONY: demo-feed
demo-feed: ## Stream every payment and review event live
	curl -N http://localhost:8080/v1/events/stream

.PHONY: demo-reviews
demo-reviews: ## List the review queue
	curl -s "http://localhost:8080/v1/reviews?limit=10" | jq .

.PHONY: dashboards
dashboards: ## Print monitoring URLs
	@echo "grafana:    http://localhost:3000/d/payment-processor"
	@echo "prometheus: http://localhost:9090/targets"

.PHONY: load-test
load-test: ## Run the k6 load test against the local stack
	k6 run test/load/payment-flow.js
