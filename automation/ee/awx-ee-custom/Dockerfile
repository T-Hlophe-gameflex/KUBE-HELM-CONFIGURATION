# Custom AWX Execution Environment (EE)
# Base: quay.io/ansible/awx-ee:24.6.1
# Purpose: provide a reproducible EE with pinned ansible-runner/ansible-core versions

FROM quay.io/ansible/awx-ee:24.6.1

# Switch to root to install/upgrade packages
USER root

# Install or pin Python packages that control ansible/runner behavior
# (Examples pinned; adjust to your registry / requirements as needed)
RUN pip install --no-cache-dir \
    "ansible-runner==2.4.0" \
    "ansible-core==2.15.12"

# Optional: include a small debug entrypoint script to dump runner inventory when container starts
COPY entrypoint.sh /usr/local/bin/ee-entrypoint.sh
RUN chmod +x /usr/local/bin/ee-entrypoint.sh

# Ensure runner directories exist and are owned by the non-root user at build time
RUN mkdir -p /runner /runner/.ansible_local_tmp /runner/.ansible_remote_tmp \
    && chown -R 1000:1000 /runner

# Restore user to default (the AWX EE expects a non-root user)
USER 1000

# Ensure Ansible uses writable temp dirs inside the container
ENV HOME=/runner
ENV ANSIBLE_LOCAL_TEMP=/runner/.ansible_local_tmp
ENV ANSIBLE_REMOTE_TEMP=/runner/.ansible_remote_tmp

ENTRYPOINT ["/usr/local/bin/ee-entrypoint.sh"]
CMD ["/bin/sh","-c","/bin/sleep infinity"]
