#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

DIR="$(dirname "${BASH_SOURCE[0]}")"

ROOT_DIR="$(realpath "${DIR}/..")"

# Get all log files in logs directory
log_files=("${ROOT_DIR}"/logs/kube-apiserver-audit.*.log)

yaml_content="$(kubectl kustomize "${ROOT_DIR}/overview/kube-apiserver-audit-exporter")"

for file in "${log_files[@]}"; do
  # Extract timestamp between last dot and .log
  timestamp=$(basename "${file}")
  timestamp=${timestamp%.log}
  timestamp=${timestamp#kube-apiserver-audit.}
  echo "---"
  echo "${yaml_content}" |
    sed "s/ audit-exporter/ audit-exporter-${timestamp}/g" |
    sed "s/ kube-apiserver-audit-exporter/ kube-apiserver-audit-exporter-${timestamp}/g" |
    sed "s/kube-apiserver-audit.log/kube-apiserver-audit.${timestamp}.log/g"
done
