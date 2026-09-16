# Applies the HAProxy patches bundled in the patches.tar.gz blob.
#
# Sourced (not executed) by the patched variant packaging scripts from within
# the unpacked HAProxy source tree, so patches apply to the current directory.
# Requires:
#   PKG_ROOT             - the package compile root (where the haproxy/ blobs live)
#   BOSH_INSTALL_TARGET  - set by BOSH; applied patches are copied here for inspection
mkdir -p ${BOSH_INSTALL_TARGET}/applied-patches
tar xf ${PKG_ROOT}/haproxy/patches.tar.gz

for patchfile in haproxy-patches/*.patch; do
  echo "Applying patch file ${patchfile}"
  # Conservatively limit patch fuzz factor to 0 to reduce chance of faulty patch
  patch -F 0 -p0 < ${patchfile}
  # Save patches in install target for inspection later
  cp ${patchfile} ${BOSH_INSTALL_TARGET}/applied-patches
done

rm -r haproxy-patches
