#!/usr/bin/env bash
set -euo pipefail

namespace="${NAMESPACE:-mlcnp-blueprint}"
gateway_port="${GATEWAY_PORT:-18080}"
sidecar_port="${SIDECAR_PORT:-18081}"
temporary_dir="$(mktemp -d)"
gateway_pid=""
sidecar_pid=""

cleanup() {
  if [[ -n "${gateway_pid}" ]]; then
    kill "${gateway_pid}" 2>/dev/null || true
    wait "${gateway_pid}" 2>/dev/null || true
  fi
  if [[ -n "${sidecar_pid}" ]]; then
    kill "${sidecar_pid}" 2>/dev/null || true
    wait "${sidecar_pid}" 2>/dev/null || true
  fi
  rm -rf "${temporary_dir}"
}
trap cleanup EXIT

for command_name in kubectl curl; do
  command -v "${command_name}" >/dev/null 2>&1 || {
    echo "error: ${command_name} is required" >&2
    exit 1
  }
done

kubectl -n "${namespace}" rollout status deployment/mlcnp-gateway --timeout=8m
kubectl -n "${namespace}" rollout status deployment/mlcnp-application --timeout=8m

kubectl -n "${namespace}" port-forward service/mlcnp-gateway \
  "${gateway_port}:8080" >"${temporary_dir}/gateway-forward.log" 2>&1 &
gateway_pid="$!"
kubectl -n "${namespace}" port-forward service/mlcnp-application \
  "${sidecar_port}:8081" >"${temporary_dir}/sidecar-forward.log" 2>&1 &
sidecar_pid="$!"

for attempt in {1..30}; do
  if curl --silent --fail --output /dev/null "http://127.0.0.1:${gateway_port}/application/"; then
    break
  fi
  if [[ "${attempt}" -eq 30 ]]; then
    echo "error: gateway did not become reachable" >&2
    cat "${temporary_dir}/gateway-forward.log" >&2
    exit 1
  fi
  sleep 1
done

curl --silent --show-error \
  --dump-header "${temporary_dir}/headers" \
  --output "${temporary_dir}/body" \
  "http://127.0.0.1:${gateway_port}/application/"

grep -qi '^X-MLCNP-Gateway: modsecurity-crs' "${temporary_dir}/headers"
grep -qi '^X-MLCNP-Sidecar: nginx' "${temporary_dir}/headers"
grep -qi '^X-MLCNP-Sidecar-Policy: baseline-v1' "${temporary_dir}/headers"
grep -qi '^X-Protected-By: OpenRASP' "${temporary_dir}/headers"
grep -q 'MLCNP protected Java workload' "${temporary_dir}/body"

kubectl -n "${namespace}" logs \
  --selector app.kubernetes.io/component=protected-workload \
  --container application-with-rasp --prefix=true --tail=-1 \
  >"${temporary_dir}/application.log"
grep -q 'OpenRASP.*Engine Initialized' "${temporary_dir}/application.log"

waf_status="$(curl --silent --output /dev/null --write-out '%{http_code}' \
  "http://127.0.0.1:${gateway_port}/application/?id=1%20UNION%20SELECT%20password%20FROM%20users")"
if [[ "${waf_status}" != "403" ]]; then
  echo "error: gateway returned HTTP ${waf_status} for the SQL injection probe" >&2
  exit 1
fi

trace_status="$(curl --silent --output /dev/null --write-out '%{http_code}' \
  --request TRACE "http://127.0.0.1:${sidecar_port}/")"
if [[ "${trace_status}" != "403" && "${trace_status}" != "405" ]]; then
  echo "error: sidecar accepted TRACE with HTTP ${trace_status}" >&2
  exit 1
fi

dd if=/dev/zero of="${temporary_dir}/large-body" bs=1024 count=1100 2>/dev/null
body_status="$(curl --silent --output /dev/null --write-out '%{http_code}' \
  --header 'Content-Type: application/octet-stream' \
  --data-binary "@${temporary_dir}/large-body" \
  "http://127.0.0.1:${sidecar_port}/")"
if [[ "${body_status}" != "413" ]]; then
  echo "error: sidecar returned HTTP ${body_status} for a body larger than 1 MiB" >&2
  exit 1
fi

kubectl -n "${namespace}" run mlcnp-network-probe \
  --image=busybox:1.37.0@sha256:9db7b59979c38555a39def84a31fb98b5296952f9e3afd4f6f11f05b07adfab0 \
  --restart=Never --attach --pod-running-timeout=2m -- \
  sh -c 'if wget -T 3 -qO- http://mlcnp-application:8081/ >/dev/null 2>&1; then exit 1; fi'
kubectl -n "${namespace}" delete pod mlcnp-network-probe --wait=false >/dev/null

echo "integration test passed: WAF, network policy, sidecar policy, application, and OpenRASP"
