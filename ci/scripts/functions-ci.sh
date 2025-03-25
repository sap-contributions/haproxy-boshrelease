#!/bin/bash

function skip_ci() {
    local ignore_list="$1"
    local changed_files="$2"
    while read -r changed_file
    do
        while read -r skip_for
        do
            # If a directory is on the allow-list
            if [ -d "$skip_for" ]; then
                for file_in_dir in "$skip_for"/*; do
                    if [ "$file_in_dir" == "$changed_file" ]; then
                        continue 3
                    fi
                done
            fi
            if [ "$skip_for" == "$changed_file" ] ; then
                continue 2
            fi
        done < "$ignore_list"
        # If we get here the file is not skipped or in a skipped dir.
        return 1
    done < "$changed_files"
    # If we get here, all files are skipped or in skipped dirs.
    return 0
}

function stop_docker() {
  echo "----- stopping docker"
  service docker stop
}

# Build acceptance test image if not found.
function build_image() {
    if docker images -a | grep "haproxy-boshrelease-testflight " ; then
    echo "Found existing testflight image, skipping docker build. To force rebuild delete this image."
    else
    pushd "$1"
        docker build -t haproxy-boshrelease-testflight .
    popd
    fi
}

function git_pull() {
    cd "${REPO_ROOT:?required}"
    echo "----- Pulling in any git submodules..."
    git config --global --add safe.directory /repo
    git config --global --add safe.directory /repo/src/ttar
    git submodule update --init --recursive --force
}

function bosh_release() {
    echo "----- Creating candidate BOSH release..."
    bosh -n reset-release # in case dev_releases/ is in repo accidentally

    bosh create-release --force
    bosh upload-release --rebase
    release_final_version=$(spruce json dev_releases/*/index.yml | jq -r ".builds[].version" | sed -e "s%+.*%%")
    export RELEASE_VERSION="${release_final_version}.latest"
    echo "----- Created ${RELEASE_VERSION}"
}

function bosh_assets() {
    stemcell_jammy_path=$START_DIR/stemcell/*.tgz
    stemcell_bionic_path=$START_DIR/stemcell-bionic/*.tgz

    echo "----- Uploading Jammy stemcell"
    bosh -n upload-stemcell $stemcell_jammy_path

    echo "----- Uploading Bionic stemcell"
    bosh -n upload-stemcell $stemcell_bionic_path

    echo "----- Uploading os-conf (used for tests only)"
    bosh -n upload-release --sha1 386293038ae3d00813eaa475b4acf63f8da226ef \
    https://bosh.io/d/github.com/cloudfoundry/os-conf-release?v=22.1.2

    export BOSH_PATH=$(command -v bosh)
    export BASE_MANIFEST_PATH="$PWD/manifests/haproxy.yml"
}
