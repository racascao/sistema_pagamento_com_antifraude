#!/usr/bin/env bash
# Builds and pushes every service image (gateway, ledger, fraud,
# investigator, console) to the Artifact Registry repository that
# deploy/terraform/gke.tf creates (google_artifact_registry_repository
# "images", repository_id "payment-processor").
#
# Usage: deploy/scripts/push-images.sh <PROJECT_ID> [REGION] [TAG]
#
# The fraud image is built for linux/arm64 because it runs on the
# "fraud-inference" node pool, which uses t2a (ARM) machines
# (deploy/terraform/gke.tf, variable gke_fraud_machine_type). Every
# other image runs on the "core-services" pool (e2-standard-2, amd64)
# and the console is a static nginx image, so linux/amd64 is enough
# for it too.
set -euo pipefail

PROJECT_ID="${1:?usage: push-images.sh <PROJECT_ID> [REGION] [TAG]}"
REGION="${2:-us-central1}"
TAG="${3:-latest}"

cd "$(dirname "$0")/../.."

REPO="${REGION}-docker.pkg.dev/${PROJECT_ID}/payment-processor"

echo "==> Configuring docker auth for ${REGION}-docker.pkg.dev"
gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet

if ! docker buildx version >/dev/null 2>&1; then
  echo "docker buildx is required (ships with recent Docker Desktop / docker-buildx-plugin)." >&2
  exit 1
fi
docker buildx inspect payment-processor-builder >/dev/null 2>&1 || \
  docker buildx create --name payment-processor-builder --use >/dev/null
docker buildx use payment-processor-builder

echo "==> Building and pushing amd64 service images (core-services pool)"
for svc in gateway ledger investigator; do
  echo "--- ${svc} ---"
  docker buildx build \
    --platform linux/amd64 \
    --build-arg SERVICE="${svc}" \
    -f deploy/docker/Dockerfile \
    -t "${REPO}/${svc}:${TAG}" \
    --push .
done

echo "==> Building and pushing fraud image for arm64 (fraud-inference pool)"
docker buildx build \
  --platform linux/arm64 \
  --build-arg SERVICE=fraud \
  -f deploy/docker/Dockerfile \
  -t "${REPO}/fraud:${TAG}" \
  --push .

echo "--- console ---"
docker buildx build \
  --platform linux/amd64 \
  -f web/console/Dockerfile \
  -t "${REPO}/console:${TAG}" \
  --push web/console

cat <<EOF

==> Done. Images pushed:
  ${REPO}/gateway:${TAG}
  ${REPO}/ledger:${TAG}
  ${REPO}/fraud:${TAG}        (linux/arm64)
  ${REPO}/investigator:${TAG}
  ${REPO}/console:${TAG}

Next: point the gcp overlay at these images, e.g.

  cp -r deploy/k8s /tmp/payment-processor-gcp-k8s
  sed -i.bak -e 's#REGION#${REGION}#g' -e 's#PROJECT_ID#${PROJECT_ID}#g' -e 's#TAG#${TAG}#g' \\
    /tmp/payment-processor-gcp-k8s/overlays/gcp/kustomization.yaml
  kubectl apply -k /tmp/payment-processor-gcp-k8s/overlays/gcp

or simply run: make gcp-deploy GCP_PROJECT=${PROJECT_ID} GCP_REGION=${REGION} GCP_TAG=${TAG}
EOF
