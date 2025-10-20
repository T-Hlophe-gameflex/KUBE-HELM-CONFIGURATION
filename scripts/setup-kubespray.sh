#!/usr/bin/env bash

set -euo pipefail

# Install dependencies (ignore SSL cert)
pip3 install --user --trusted-host pypi.org --trusted-host files.pythonhosted.org -r requirements.txt

# Clone Kubespray if not present

if [ ! -d "kubespray" ]; then
  git clone https://github.com/kubernetes-sigs/kubespray.git
fi
cd kubespray

# Install Kubespray requirements (ignore SSL cert)
pip3 install --user --trusted-host pypi.org --trusted-host files.pythonhosted.org -r requirements.txt

# Copy inventory
cp -r ../inventory/mycluster inventory/mycluster

# Run Kubespray playbook
ansible-playbook -i inventory/mycluster/hosts.yaml --become --become-user=root cluster.yml

cd ..
