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
#
# BPM only needs the runc state dir to be gone before it can re-create
# the container. The orphaned cgroup scope dirs will be cleaned up by the
# host systemd garbage collector once there are no more references to them.

set +e

monit_bin=/var/vcap/bosh/bin/monit
director_container=""
echo "Waiting for director container to appear..." >&2
while true; do
  director_container=$(docker ps --format "{{.ID}}" | head -1) # At this point there should only be one container, the director
  if [ -n "${director_container}" ]; then
    echo "Director container appeared: ${director_container}" >&2
    break
  fi
  echo "Director container not yet running, waiting..." >&2
  sleep 10
done

echo "Waiting for postgres job to be running in director container..." >&2
iteration=0
while true; do
  # Recheck the director container ID every N iterations — bosh create-env may
  # recreate the container before starting jobs there, giving it a new ID.
  # Stale ID causes all docker exec calls to fail silently.
  if [ $((iteration % 4)) -eq 0 ]; then
    new_container=$(docker ps --format "{{.ID}}" | head -1)
    if [ -n "${new_container}" ] && [ "${new_container}" != "${director_container}" ]; then
      echo "Director container ID changed: ${director_container} -> ${new_container}" >&2
      director_container="${new_container}"
    fi
  fi
  iteration=$((iteration + 1))

  status=$(docker exec "${director_container}" ${monit_bin} summary 2>/dev/null)
  if echo "${status}" | grep -q "'postgres'.*running"; then
    echo "postgres is running" >&2
    break
  fi
  echo "postgres not yet running, waiting..." >&2
  sleep 3
done

echo "Monitoring jobs until all are running or create-env reaches its timeout..." >&2
while true; do
  status=$(docker exec "${director_container}" ${monit_bin} summary 2>/dev/null)

  # Categorise jobs into three states:
  #   running  — 'running'
  #   failed   — 'Execution failed' (BPM could not start/restart the process)
  #   pending  — anything else (Does not exist, not monitored, initializing, restart pending, etc.)
  # monit summary lines look like:  "Process 'job-name'   <status>"
  all_jobs=$(echo "${status}" | awk "/Process/{print \$2}" | tr -d "'")

  failed_jobs=""
  pending_jobs=""
  all_running=true

  while read -r job; do
    [ -z "${job}" ] && continue
    # Extract the status portion after the job name, then strip any trailing
    # " - <suffix>" (e.g. "Execution failed - restart pending" -> "Execution failed")
    job_status=$(echo "${status}" | grep "'${job}'" | sed "s/.*'${job}'[[:space:]]*//" | sed "s/[[:space:]]*-[[:space:]].*//" | xargs)
    if echo "${job_status}" | grep -qiw "running"; then
      : # running — good
    elif echo "${job_status}" | grep -qi "execution failed"; then
      failed_jobs="${failed_jobs} ${job}"
      all_running=false
    else
      pending_jobs="${pending_jobs} ${job}"
      all_running=false
    fi
  done <<< "${all_jobs}"

  if [ "${all_running}" = "true" ]; then
    echo "All jobs are running. Exiting." >&2
    exit 0
  fi

  if [ -n "${pending_jobs}" ]; then
    echo "Pending jobs (waiting for them to settle):${pending_jobs}" >&2
  fi

  if [ -z "${failed_jobs}" ]; then
    echo "No failed jobs, only pending — skipping fix, will recheck..." >&2
    sleep 10
    continue
  fi

  echo "Failed jobs detected:${failed_jobs}" >&2
  echo "Applying fix..." >&2

  # For each failed job: remove its runc state dir so BPM can re-create it,
  # then restart it via monit.
  for job in ${failed_jobs}; do
    # Map monit job name to runc container id (BPM uses "bpm-<job>" convention)
    runc_id="bpm-${job}"
    docker exec "${director_container}" bash -c "
      runc_root=/var/vcap/sys/run/bpm-runc
      monit_bin=${monit_bin}
      runc_id='${runc_id}'
      if [ -d \"\${runc_root}/\${runc_id}\" ]; then
        echo \"Removing runc state dir for \${runc_id}\" >&2
        rm -rf \"\${runc_root:?}/\${runc_id}\"
      fi
      echo \"Restarting monit job: ${job}\" >&2
      \${monit_bin} restart '${job}' || true
    " 2>/dev/null || true
  done

  echo "Fix applied, waiting 10s before re-checking..." >&2
  sleep 10
done

echo "create-env completed, fix-bosh-instance exiting." >&2
