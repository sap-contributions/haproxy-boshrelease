#!/usr/bin/env bash
# Decides which SSL backend HAProxy is compiled against, from the blobs present
# in the package compile root.
#
# Both FIPS and non-FIPS AWS-LC build from the SAME aws-lc-v* LTS source tarball;
# FIPS is just a build-time flag (-DFIPS=1) plus the Go toolchain, which drives
# the delocate/inject_hash integrity step. Go is bundled ONLY for FIPS, so the
# presence of the golang-* blob -- not the source tarball name -- is the FIPS
# discriminator.
#
# ORDER IS LOAD-BEARING: a FIPS build ships BOTH the aws-lc-v* source and the
# golang-* toolchain, so golang-* must be tested first. If the order were
# reversed (or a golang blob were ever bundled into a non-FIPS build), a FIPS
# build would be silently misdetected as plain AWS-LC and produce a non-FIPS
# binary. This contract is pinned by spec/haproxy/detect_ssl_backend_spec.rb.
#
# Prints exactly one of: awslc-fips | awslc | openssl
# Arg 1: directory containing the haproxy/ blob subdir (defaults to CWD).
detect_ssl_backend() {
  local root="${1:-.}"
  if ls "${root}"/haproxy/golang-*.tar.gz 1>/dev/null 2>&1; then
    echo "awslc-fips"
  elif ls "${root}"/haproxy/aws-lc-v*.tar.gz 1>/dev/null 2>&1; then
    echo "awslc"
  else
    echo "openssl"
  fi
}
