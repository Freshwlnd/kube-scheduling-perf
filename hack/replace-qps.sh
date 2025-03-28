#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

QPS="${1:-1000}"

find . \
    -iname \
    "*.yaml" \
    -not \( \
        -path ./vendor/\* \
        -o -path ./tmp/\* \
    \) \
    -type f \
    -exec sed -i 's|\([0-9]\+\)\(.\+\)# <--QPS|'${QPS}'\2# <--QPS|g' {} +
