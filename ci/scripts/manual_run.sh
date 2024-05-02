#!/bin/bash
set -ex
cd ${REPO_ROOT:?required}
FOCUS=${1:?required}
ADDITIONAL_ARGS=("--focus" "$FOCUS")
source /tmp/local-bosh/director/env

echo "----- Creating candidate BOSH release..."
bosh -n reset-release # in case dev_releases/ is in repo accidentally

bosh create-release --force
bosh upload-release --rebase
release_final_version=$(spruce json dev_releases/*/index.yml | jq -r ".builds[].version" | sed -e "s%+.*%%")
export RELEASE_VERSION="${release_final_version}.latest"
echo "----- Created ${RELEASE_VERSION}"

echo "----- Uploading Jammy stemcell"
bosh -n upload-stemcell $stemcell_jammy_path

echo "----- Uploading Bionic stemcell"
bosh -n upload-stemcell $stemcell_bionic_path

echo "----- Uploading BPM"
bosh -n upload-release $bpm_release_path

echo "----- Uploading os-conf (used for tests only)"
bosh -n upload-release --sha1 386293038ae3d00813eaa475b4acf63f8da226ef \
  https://bosh.io/d/github.com/cloudfoundry/os-conf-release?v=22.1.2

export BOSH_PATH=$(which bosh)
export BASE_MANIFEST_PATH="$PWD/manifests/haproxy.yml"

cd "acceptance-tests"

echo "----- Installing dependencies"
go mod download

echo "----- Running tests"

export PATH=$PATH:$GOPATH/bin
ginkgo version
ginkgo -v -p -r --trace --show-node-events --randomize-all --flake-attempts 5 "${ADDITIONAL_ARGS[@]}"
