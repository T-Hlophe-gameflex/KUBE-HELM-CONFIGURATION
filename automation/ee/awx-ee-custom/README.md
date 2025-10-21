Custom AWX Execution Environment (EE)

Overview
- Base image: quay.io/ansible/awx-ee:24.6.1
- We pin `ansible-runner` and `ansible-core` to known versions. Adjust as needed.
- The image includes an optional debug entrypoint that will print `/runner/inventory/hosts` if present when the container starts. This can help confirm what the runner is seeing.

Build (local)

# From this repo root
cd automation/ee/awx-ee-custom
docker build -t <registry>/<org>/awx-ee-custom:24.6.1-debug .

Push

docker push <registry>/<org>/awx-ee-custom:24.6.1-debug

Usage with AWX
- Push the image to a registry accessible by the cluster.
- Create or update an Execution Environment in AWX to point to this image (via UI or AWX API).
- Update your job template(s) to use the new Execution Environment.
- Launch the job and collect job events / stdout. The debug entrypoint will print `/runner/inventory/hosts` at container start if it exists.

Notes
- You may need to adjust pinned versions (`ansible-runner`, `ansible-core`) if you have other compatibility requirements.
- In production, remove the debug entrypoint or set non-interfering command so normal EE behavior is preserved.
