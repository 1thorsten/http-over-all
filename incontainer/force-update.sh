#!/usr/bin/env bash
# rm /scripts/force-update.sh; nano /scripts/force-update.sh; chmod u+x /scripts/force-update.sh
# curl -s --header "X-Debug-Out: something.meaningful" http://localhost:8338/force-update/
# http://localhost:8338/force-update/

if [ ! -f "/var/run/sds.ready" ]; then exit 1; fi

SYS_ENV="/var/run/sys_env.sh"
# shellcheck disable=SC1090
if [ -e ${SYS_ENV} ]; then source "${SYS_ENV}"; fi

source "/scripts/connect-services.sh"
echo "$(date +'%T'): http-over-all -> RELEASE: ${RELEASE}"

handle_update_jobs_lock "/var/run/force-update.lock" "handle-trap"
UPDATE_OK=true
if ! connect_or_update_git_repos "update"; then
  echo "$(date +'%T'): error updating important resource (git)"
  UPDATE_OK=false
fi
if ! connect_or_update_docker "update"; then
  echo "$(date +'%T'): error updating important resource (docker)"
  UPDATE_OK=false
fi

if [ ! "$UPDATE_OK" ]; then
  echo sudo -E /scripts/shutdown-services.sh
  sudo -E /scripts/shutdown-services.sh
  exit 1
fi

periodic_job_update_permitted_resources
touch /var/run/force-update.last
