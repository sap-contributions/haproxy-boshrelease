#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_FILE="${SCRIPT_DIR}/pipeline-ephemeral-vm.yml"
VARS_FILE="${SCRIPT_DIR}/vars.yml"
PIPELINE_NAME="${PIPELINE_NAME:-haproxy-boshrelease-ephemeral-vm}"
CONCOURSE_TARGET="${CONCOURSE_TARGET:-networking-extensions}"

if [ ! -f "${VARS_FILE}" ]; then
  echo "ERROR: vars file not found at ${VARS_FILE}"
  echo ""
  echo "Create it with the following keys:"
  cat <<'EOF'
---
gcp:
  project_id: YOUR_GCP_PROJECT_ID
  service_key: |
    { "type": "service_account", ... }

github:
  bot_deploy_key_private: |
    -----BEGIN OPENSSH PRIVATE KEY-----
    ...

cloud:
  region: europe-west3
  zone: europe-west3-a

slack:
  webhook: https://hooks.slack.com/services/xxx
  icon: https://...
  fail_url: https://...
EOF
  exit 1
fi

echo "==> Validating pipeline"
fly --target "${CONCOURSE_TARGET}" validate-pipeline \
  --config "${PIPELINE_FILE}"

echo "==> Setting pipeline '${PIPELINE_NAME}' on target '${CONCOURSE_TARGET}'"
fly --target "${CONCOURSE_TARGET}" set-pipeline \
  --pipeline "${PIPELINE_NAME}" \
  --config "${PIPELINE_FILE}" \
  --load-vars-from "${VARS_FILE}" \
  --non-interactive

echo "==> Pipeline '${PIPELINE_NAME}' set successfully (private, not exposed)"
echo ""
echo "To trigger manually:"
echo "  fly -t ${CONCOURSE_TARGET} trigger-job -j ${PIPELINE_NAME}/acceptance-tests-ephemeral-vm -w"

