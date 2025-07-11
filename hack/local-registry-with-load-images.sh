#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

DIR="$(dirname "${BASH_SOURCE[0]}")"
ROOT_DIR="$(realpath "${DIR}/..")"
IMAGE_PREFIX="${IMAGE_PREFIX:-m.daocloud.io/}"

# https://kind.sigs.k8s.io/docs/user/local-registry/

# Registry configuration
reg_name='kind-registry'
reg_port='5001'

# Ensure registry-data directory exists with correct permissions
mkdir -p "${ROOT_DIR}/registry-data"

# Create local registry container if not running
if [[ "$(docker inspect -f '{{.State.Running}}' "${reg_name}" 2>/dev/null || true)" != 'true' ]]; then
  target_image="docker.io/library/registry:2.8.3"
  if [[ ${IMAGE_PREFIX} != "" ]] && ! docker image inspect "${target_image}" &>/dev/null; then
    echo "Pulling registry image from ${IMAGE_PREFIX}${target_image}"
    docker pull "${IMAGE_PREFIX}${target_image}"
    docker tag "${IMAGE_PREFIX}${target_image}" "${target_image}"
  fi
  docker run \
    -d \
    --restart=always \
    -p "127.0.0.1:${reg_port}:5000" \
    --network bridge \
    --name "${reg_name}" \
    -v "${ROOT_DIR}/registry-data:/var/lib/registry" \
    "${target_image}" || :
  sleep 1
fi

function get_image() {
  grep -E "kind-registry:5000/|localhost:5001/" |
    sed -E 's#.*(kind-registry:5000/|localhost:5001/)##g; s/"//g' |
    sort |
    uniq
}

while IFS= read -r image; do
  target_image="localhost:5001/${image}"

  if ! docker manifest inspect --insecure "${target_image}" &>/dev/null; then
    source_image="${IMAGE_PREFIX}${image}"

    # Pull image if not exists locally
    if ! docker image inspect "${source_image}" &>/dev/null; then
      echo "Pulling image from ${source_image}"
      docker pull "${source_image}"
    fi

    # Tag and push to local registry
    docker tag "${source_image}" "${target_image}"
    docker push "${target_image}"
  fi
done < <(get_image)
