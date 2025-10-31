This folder contains a small AWX worker patch that normalizes dynamic inventory output and writes a debug inventory dump to /tmp for inspection.

Patch goal
- Convert any group whose 'hosts' key is a list into a mapping {host: {}} so Ansible inventory parsing works.
- Write a debug copy of the inventory to /tmp/awx_inventory_dump.json and a marker /tmp/awx_inventory_written_json for offline inspection.

How to produce and deploy the patched image
1. Build locally
   ./scripts/build-awx-patch.sh quay.io/myorg/awx-patched:24.6.1-inventory-dump2

2a. For kind/local clusters: load the image into kind (ensure cluster name)
   ./scripts/load-image-kind.sh quay.io/myorg/awx-patched:24.6.1-inventory-dump2 <cluster-name>

2b. For remote clusters: push the image to your registry and ensure the AWX operator can pull it.
   docker push quay.io/myorg/awx-patched:24.6.1-inventory-dump2
   Then patch the AWX CR to use spec.image: quay.io/myorg/awx-patched and spec.image_version: 24.6.1-inventory-dump2

3. Patch AWX CR to use the patched image
   kubectl -n awx patch awx ansible-awx --type merge -p '{"spec":{"image":"quay.io/myorg/awx-patched","image_version":"24.6.1-inventory-dump2"}}'

4. Confirm task pods run the patched image and that /tmp/awx_inventory_dump.json appears in the ansible-awx-task pod when a job runs.

Creating a permanent AWX API token secret
- Use scripts/create-awx-token-secret.sh to create a persistent token and store in Kubernetes as secret `awx-api-token`.

Notes
- This patch is intentionally conservative: it normalizes all groups with a hosts list into a mapping with empty hostvars. If your dynamic inventory contains hostvars, further merging logic may be needed (e.g. copying hostvars into the mapping values).
- After stabilization, consider upstreaming a more complete fix into AWX or contributing a PR.

