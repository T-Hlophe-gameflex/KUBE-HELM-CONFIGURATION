#!/usr/bin/env bash
set -euo pipefail

# Load a locally-built docker image into kind cluster nodes.
# Usage: ./scripts/load-image-kind.sh <image-tag> [kind-cluster-name]

IMAGE=${1:?image tag is required}
CLUSTER_NAME=${2:-kind}

if ! command -v kind >/dev/null 2>&1; then
  echo "kind not found in PATH; ensure kind is installed or use an alternative to push the image to your cluster's registry"
  exit 2
fi

echo "Loading $IMAGE into kind cluster $CLUSTER_NAME"
kind load docker-image "$IMAGE" --name "$CLUSTER_NAME"

echo "Image loaded."

echo "If AWX Operator can't pull the image from a registry, consider setting spec.image/pullPolicy or creating an imagePullSecret."