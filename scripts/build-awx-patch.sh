#!/usr/bin/env bash
set -euo pipefail

# Build a patched AWX image that copies our modified jobs.py into site-packages.
# Usage: ./scripts/build-awx-patch.sh <tag>
# Example: ./scripts/build-awx-patch.sh quay.io/myorg/awx-patched:24.6.1-inventory-dump2

TAG=${1:-quay.io/myorg/awx-patched:24.6.1-inventory-dump}
HERE=$(cd "$(dirname "$0")/.." && pwd)
cd "$HERE/automation/awx-image"

echo "Building image $TAG from Dockerfile in $PWD"
docker build -t "$TAG" .

echo "Built $TAG"

echo "Tip: load into kind with: kind load docker-image $TAG --name <cluster-name>"