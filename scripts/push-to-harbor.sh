#!/usr/bin/env bash
#
# Push AWX custom images to Harbor registry
# Usage: ./scripts/push-to-harbor.sh
#

set -e

# Harbor Configuration
HARBOR_REGISTRY="harbor.dgcops.com"
HARBOR_PROJECT="gglcloudflare"
HARBOR_REPO="awx-cloudflare"

# Source images (currently in use)
AWX_PATCHED_IMAGE="blackthami/awx-patched:24.6.1-inventory-dump2"
AWX_EE_IMAGE="blackthami/awx-ee-cloudflare:24.6.1-debug8"

# Target images in Harbor
HARBOR_AWX_PATCHED="${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${HARBOR_REPO}/awx-patched:24.6.1-inventory-dump2"
HARBOR_AWX_EE="${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${HARBOR_REPO}/awx-ee-cloudflare:24.6.1-debug8"

echo "================================================"
echo "  Push AWX Images to Harbor Registry"
echo "================================================"
echo ""
echo "Source Images:"
echo "  1. ${AWX_PATCHED_IMAGE}"
echo "  2. ${AWX_EE_IMAGE}"
echo ""
echo "Target Registry: ${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${HARBOR_REPO}"
echo ""
echo "================================================"
echo ""

# Check if images exist locally
echo "Checking local images..."
if ! docker image inspect "${AWX_PATCHED_IMAGE}" &>/dev/null; then
    echo "ERROR: Image ${AWX_PATCHED_IMAGE} not found locally"
    echo "Please build it first using: ./scripts/build-awx-patch.sh"
    exit 1
fi

if ! docker image inspect "${AWX_EE_IMAGE}" &>/dev/null; then
    echo "WARNING: Image ${AWX_EE_IMAGE} not found locally"
    echo "This is optional, but recommended for custom execution environment"
fi

echo "✅ Local images verified"
echo ""

# Login to Harbor
echo "Logging in to Harbor registry..."
echo "Please enter your Harbor credentials:"
docker login "${HARBOR_REGISTRY}"

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to login to Harbor registry"
    exit 1
fi

echo "✅ Logged in successfully"
echo ""

# Tag and push AWX Patched Image
echo "================================================"
echo "1. Tagging and pushing AWX Patched Image..."
echo "================================================"
docker tag "${AWX_PATCHED_IMAGE}" "${HARBOR_AWX_PATCHED}"
echo "Tagged: ${HARBOR_AWX_PATCHED}"
echo "Pushing..."
docker push "${HARBOR_AWX_PATCHED}"
echo "✅ AWX Patched image pushed successfully"
echo ""

# Tag and push AWX EE Image (if exists)
if docker image inspect "${AWX_EE_IMAGE}" &>/dev/null; then
    echo "================================================"
    echo "2. Tagging and pushing AWX EE Image..."
    echo "================================================"
    docker tag "${AWX_EE_IMAGE}" "${HARBOR_AWX_EE}"
    echo "Tagged: ${HARBOR_AWX_EE}"
    echo "Pushing..."
    docker push "${HARBOR_AWX_EE}"
    echo "✅ AWX EE image pushed successfully"
    echo ""
else
    echo "⚠️  Skipping AWX EE image (not found locally)"
    echo ""
fi

echo "================================================"
echo "✅ ALL IMAGES PUSHED SUCCESSFULLY!"
echo "================================================"
echo ""
echo "Next Steps:"
echo "1. Update your AWX CR to use Harbor images:"
echo ""
echo "   kubectl -n awx patch awx ansible-awx --type merge -p '{"
echo "     \"spec\": {"
echo "       \"image\": \"${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${HARBOR_REPO}/awx-patched\","
echo "       \"image_version\": \"24.6.1-inventory-dump2\""
echo "     }"
echo "   }'"
echo ""
echo "2. Update Execution Environment in AWX UI (if using custom EE):"
echo "   - Navigate to: Administration → Execution Environments"
echo "   - Update image to: ${HARBOR_AWX_EE}"
echo ""
echo "3. Verify pods are using new images:"
echo "   kubectl get pods -n awx -o jsonpath='{range .items[*]}{.metadata.name}{\"\\n\"}{range .spec.containers[*]}  {.name}: {.image}{\"\\n\"}{end}{end}'"
echo ""
