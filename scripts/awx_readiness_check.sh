#!/usr/bin/env bash
set -euo pipefail
NAMESPACE=awx
AWX_SVC=ansible-awx-service
LOCAL_PORT=8043
#!/usr/bin/env bash
set -euo pipefail
NAMESPACE=awx
AWX_SVC=ansible-awx-service
LOCAL_PORT=8043
AWX_USER="admin"
AWX_PASS=$(kubectl get secret ansible-awx-admin-password -n "${NAMESPACE}" -o jsonpath='{.data.password}' | base64 --decode)

echo "Checking AWX pods in namespace ${NAMESPACE}..."
kubectl get pods -n "${NAMESPACE}" -o wide

echo "Checking PVCs..."
kubectl get pvc -n "${NAMESPACE}"

# ensure port is free
if lsof -i :"${LOCAL_PORT}" &>/dev/null; then
  echo "Port ${LOCAL_PORT} in use, cannot port-forward. Please free it or edit the script." 
else
  echo "Starting port-forward to ${AWX_SVC}:${LOCAL_PORT}..."
  kubectl port-forward svc/"${AWX_SVC}" "${LOCAL_PORT}":80 -n "${NAMESPACE}" >/tmp/awx-port-forward.log 2>&1 &
  PF_PID=$!
  sleep 1
  echo "Port-forward PID ${PF_PID} started; checking AWX API..."
  if curl -sS -u "${AWX_USER}":"${AWX_PASS}" "http://127.0.0.1:${LOCAL_PORT}/api/v2/me/" --max-time 5 | grep -q '"username":"admin"'; then
    echo "AWX API reachable and admin authenticated."
  else
    echo "AWX API did not respond or auth failed. Showing last 200 chars of logs:"
    tail -c 200 /tmp/awx-port-forward.log || true
    kill "${PF_PID}" || true
    exit 2
  fi
  # cleanup
  kill "${PF_PID}" || true
fi

echo "Readiness check complete." 

