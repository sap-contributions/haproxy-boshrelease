#!/usr/bin/env bash

# This script runs in parallel with bosh create-env.
# It waits until the director container appears and the postgres job successfully starts, then,
# if director job failed, it fixes issue with runc state directories during BPM restart of failed jobs.
# (see https://github.com/cloudfoundry/bpm-release/issues/208).
#
# BPM cannot cleanup before restarting job. The cleanup means to delete
# the runc container for the job and it cannot be deleted because because
# the container cgroup scope dirs (system.slice/runc-*.scope) are owned
# by the host systemd and cannot be deleted from inside the nested container,
# even when they are empty.
#
# We will find the director container and clean runc state dirs so monit can bring
# the jobs back up via BPM restart.

set +e

director_container=""
echo "Waiting for director container to appear..." >&2
while true; do
  director_container=$(docker ps --format "{{.ID}}" | head -1) # At this point there should only be one container, the director
  if [ -n "${director_container}" ]; then
    echo "Director container appeared: ${director_container}" >&2
    break
  fi
  echo "Director container not yet running, waiting..." >&2
  sleep 5
done

echo "Waiting for postgres job to be running in director container..." >&2
while true; do
  status=$(docker exec "${director_container}" /var/vcap/bosh/bin/monit summary 2>/dev/null)
  if echo "${status}" | grep -q "postgres.*running"; then
    echo "postgres is running" >&2
    break
  fi
  echo "postgres not yet running, waiting..." >&2
  sleep 5
done

echo "Monitoring director job until it is running or needs fixing..." >&2
while [ ! -f "${CREATE_ENV_DONE_FILE:-/tmp/create-env-done}" ]; do
  status=$(docker exec "${director_container}" /var/vcap/bosh/bin/monit summary 2>/dev/null)

  if echo "${status}" | grep -q "director.*running"; then
    echo "director is running, no fix needed. Exiting." >&2
    exit 0
  fi
  if echo "${status}" | grep -qE "director.*(Execution failed)"; then
    echo "director job is failing, proceeding with fix..." >&2
    break
  fi
done

# BPM only needs the runc state dir to be gone before it can re-create
# the container. The orphaned cgroup scope dirs will be cleaned up by the
# host systemd garbage collector once there are no more references to them.
docker exec "${director_container}" bash -c '
  runc_bin=/var/vcap/packages/bpm/bin/runc
  runc_root=/var/vcap/sys/run/bpm-runc

  for container_id in $(${runc_bin} --root ${runc_root} list -q 2>/dev/null); do
    # postgres must keep running — the director depends on it
    [ "${container_id}" = "bpm-postgres" ] && continue
    echo "Cleaning up runc container: ${container_id}" >&2
    rm -rf "${runc_root:?}/${container_id}"
  done

  /var/vcap/bosh/bin/monit summary | awk "/Process/{print \$2}" | tr -d "'"'"'" | \
  while read -r job; do
    # Restart all monitored jobs except postgres (which must keep running
    # as the director database — its restart is slow and will cause the same
    # failure for director jobs, which depend on it
    [ "${job}" = "postgres" ] && continue
    echo "Restarting monit job: ${job}" >&2
    /var/vcap/bosh/bin/monit restart "${job}" || true
  done
' 2>/dev/null || true

