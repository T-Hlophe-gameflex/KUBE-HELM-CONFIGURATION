# Push AWX Images to Harbor Registry

## Overview
This guide explains how to push your custom AWX images to the Harbor registry at `harbor.dgcops.com` under the project `gglcloudflare` with repository `awx-cloudflare`.

## Images to Push

### 1. AWX Patched Image (Main Application)
- **Current Image:** `blackthami/awx-patched:24.6.1-inventory-dump2`
- **Target:** `harbor.dgcops.com/gglcloudflare/awx-cloudflare/awx-patched:24.6.1-inventory-dump2`
- **Purpose:** Patched AWX application with inventory normalization fixes
- **Size:** ~997MB

### 2. AWX Execution Environment (Optional)
- **Current Image:** `blackthami/awx-ee-cloudflare:24.6.1-debug8`
- **Target:** `harbor.dgcops.com/gglcloudflare/awx-cloudflare/awx-ee-cloudflare:24.6.1-debug8`
- **Purpose:** Custom execution environment with pinned Ansible versions
- **Size:** ~1.75GB

## Quick Start

### Option 1: Use the Automated Script (Recommended)

```bash
# Run the push script
./scripts/push-to-harbor.sh
```

The script will:
1. Verify local images exist
2. Prompt for Harbor login credentials
3. Tag images with Harbor registry path
4. Push images to Harbor
5. Display next steps for updating AWX

### Option 2: Manual Push

```bash
# 1. Login to Harbor
docker login harbor.dgcops.com

# 2. Tag and push AWX Patched Image
docker tag blackthami/awx-patched:24.6.1-inventory-dump2 \
  harbor.dgcops.com/gglcloudflare/awx-cloudflare/awx-patched:24.6.1-inventory-dump2

docker push harbor.dgcops.com/gglcloudflare/awx-cloudflare/awx-patched:24.6.1-inventory-dump2

# 3. Tag and push AWX EE Image (optional)
docker tag blackthami/awx-ee-cloudflare:24.6.1-debug8 \
  harbor.dgcops.com/gglcloudflare/awx-cloudflare/awx-ee-cloudflare:24.6.1-debug8

docker push harbor.dgcops.com/gglcloudflare/awx-cloudflare/awx-ee-cloudflare:24.6.1-debug8
```

## Update AWX to Use Harbor Images

### Step 1: Update AWX CR (Main Application)

```bash
kubectl -n awx patch awx ansible-awx --type merge -p '{
  "spec": {
    "image": "harbor.dgcops.com/gglcloudflare/awx-cloudflare/awx-patched",
    "image_version": "24.6.1-inventory-dump2",
    "image_pull_policy": "Always"
  }
}'
```

### Step 2: Verify Deployment

```bash
# Watch pods restart
kubectl get pods -n awx -w

# Check that new image is being used
kubectl get pods -n awx -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .spec.containers[*]}  {.name}: {.image}{"\n"}{end}{"\n"}{end}'
```

### Step 3: Update Execution Environment (Optional)

If you pushed the custom EE image:

1. Open AWX Web UI
2. Navigate to: **Administration → Execution Environments**
3. Find your Execution Environment or create new one
4. Update **Image** field to:
   ```
   harbor.dgcops.com/gglcloudflare/awx-cloudflare/awx-ee-cloudflare:24.6.1-debug8
   ```
5. Update your Job Template to use this Execution Environment

## Harbor Project Setup

If the project doesn't exist yet, create it in Harbor:

1. Login to Harbor: `https://harbor.dgcops.com`
2. Create new project: `gglcloudflare`
3. Create repository: `awx-cloudflare`
4. Set appropriate access permissions
5. Optional: Enable vulnerability scanning

## Troubleshooting

### Login Issues

```bash
# If login fails, ensure you have access to the Harbor project
# Contact Harbor admin to grant access to gglcloudflare project
```

### Image Pull Issues in Kubernetes

If AWX can't pull images from Harbor, create an image pull secret:

```bash
# Create Docker registry secret
kubectl create secret docker-registry harbor-registry \
  --docker-server=harbor.dgcops.com \
  --docker-username=YOUR_USERNAME \
  --docker-password=YOUR_PASSWORD \
  --docker-email=YOUR_EMAIL \
  -n awx

# Update AWX CR to use the secret
kubectl -n awx patch awx ansible-awx --type merge -p '{
  "spec": {
    "image_pull_secrets": ["harbor-registry"]
  }
}'
```

### Verify Image in Harbor

After pushing, verify the images are accessible:

```bash
# List images in Harbor
curl -u "username:password" \
  "https://harbor.dgcops.com/api/v2.0/projects/gglcloudflare/repositories/awx-cloudflare/artifacts"
```

## Image Details

### AWX Patched Image Features
- Base: `quay.io/ansible/awx:24.6.1`
- Patches: `jobs.py` with inventory normalization
- Fixes: Dynamic inventory parsing issues
- Debug: Writes inventory dumps to `/tmp/awx_inventory_dump.json`

### AWX EE Image Features
- Base: `quay.io/ansible/awx-ee:24.6.1`
- Ansible Core: 2.15.12 (pinned)
- Ansible Runner: 2.4.0 (pinned)
- Debug: Inventory snapshot on container start
- Temp directories: Properly configured for AWX

## Related Files

- Build script: `scripts/build-awx-patch.sh`
- AWX Dockerfile: `automation/awx-image/Dockerfile`
- EE Dockerfile: `automation/ee/awx-ee-custom/Dockerfile`
- Sync script: `automation/scripts/sync-awx-project.sh`

## Notes

- Images are approximately 1-2GB each, upload time depends on your connection
- Always test in a non-production environment first
- Keep both Docker Hub and Harbor images in sync
- Consider automating this with CI/CD pipeline

## Support

For issues:
1. Check AWX operator logs: `kubectl logs -n awx -l app.kubernetes.io/name=awx-operator`
2. Check AWX task pod logs: `kubectl logs -n awx -l app.kubernetes.io/component=task`
3. Verify image accessibility from cluster
