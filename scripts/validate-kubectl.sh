#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
kubectl_root="${project_root}/deploy/kubectl"
temporary_dir="$(mktemp -d)"
trap 'rm -rf "${temporary_dir}"' EXIT

command -v kubectl >/dev/null 2>&1 || {
  echo "error: kubectl is required" >&2
  exit 1
}

output="${temporary_dir}/kubectl-blueprint.yaml"
echo "rendering kubectl distribution"
kubectl kustomize "${kubectl_root}" >"${output}"
test -s "${output}"

grep -q 'namespace: mlcnp-blueprint' "${output}"
if [[ "$(grep -c '^kind: Namespace$' "${output}")" -ne 1 ]]; then
  echo "error: the distribution must render its dedicated namespace" >&2
  exit 1
fi

grep -q 'name: mlcnp-gateway' "${output}"
grep -q 'name: mlcnp-application' "${output}"
grep -q 'name: sidecar-proxy' "${output}"
grep -q 'name: application-with-rasp' "${output}"
grep -q 'image: nginx:1.31.3-alpine@sha256:' "${output}"
grep -q 'image: owasp/modsecurity-crs:4.25.1-nginx-alpine-202608131208@sha256:' "${output}"
grep -q 'image: mlcnp/java-openrasp-demo:local' "${output}"
grep -A1 'image: mlcnp/java-openrasp-demo:local' "${output}" | grep -q 'imagePullPolicy: IfNotPresent'
grep -q -- '-javaagent:/opt/rasp/rasp.jar' "${output}"
grep -q 'runAsNonRoot: true' "${output}"
grep -q 'readOnlyRootFilesystem: true' "${output}"
grep -q 'allowPrivilegeEscalation: false' "${output}"
grep -q 'automountServiceAccountToken: false' "${output}"
grep -A4 'name: http-sidecar' "${output}" | grep -q 'targetPort: proxy'
grep -q 'client_max_body_size 1m' "${output}"
grep -q 'limit_except GET HEAD POST PUT PATCH DELETE OPTIONS' "${output}"
grep -q 'X-MLCNP-Sidecar-Policy.*baseline-v1' "${output}"

if [[ "$(grep -c '^kind: NetworkPolicy$' "${output}")" -ne 5 ]]; then
  echo "error: the distribution must render five network policies" >&2
  exit 1
fi

dockerfile="${project_root}/images/java-openrasp-demo/Dockerfile"
grep -q 'OPENRASP_VERSION=1.3.7' "${dockerfile}"
grep -q '93525f326e9c5a353c5b09d2442c66d318e82bd7182149d4dc579bc99d82a0f2' \
  "${dockerfile}"

echo "kubectl template validated: gateway, sidecar, RASP, Service routing, and network policies"
