# Minimal AWX patched image
# Based on the upstream AWX image used in the cluster. This Dockerfile copies a patched
# `jobs.py` into the site-packages path where AWX's task runner reads it.

FROM quay.io/ansible/awx:24.6.1

# Create a directory to hold our patched module
WORKDIR /tmp/awx_patch

# Copy the patched file into the image
COPY jobs.py /tmp/awx_patch/jobs.py

# Determine site-packages path for the AWX venv and copy the patched file into place
# The path below matches the AWX task venv used in the cluster; adjust if your AWX image
# layout differs.
USER root
RUN set -eux; \
    TARGET_DIR=/var/lib/awx/venv/awx/lib/python3.11/site-packages/awx/main/tasks; \
    mkdir -p "$TARGET_DIR"; \
    cp /tmp/awx_patch/jobs.py "$TARGET_DIR/jobs.py"; \
    chown root:root "$TARGET_DIR/jobs.py"; chmod 644 "$TARGET_DIR/jobs.py"; \
    rm -rf /tmp/awx_patch
# revert to the default image user if it exists
USER 1000

# Minimal metadata
LABEL maintainer="thami.hlophe <devnull@example.com>" \
      awx_patch_version="1"

CMD ["/usr/bin/tini", "--", "/usr/bin/awx"]
