#!/usr/bin/env bash
# curl -s --header "X-Debug-Out: something.meaningful" http://localhost:8338/force-update/
# http://localhost:8338/force-update/

SYS_ENV="/var/run/sys_env.sh"
# shellcheck disable=SC1090
if [ -e ${SYS_ENV} ]; then source "${SYS_ENV}"; fi

source "/scripts/connect-services.sh"
echo "$(date +'%T'): http-over-all -> RELEASE: ${RELEASE}"

handle_update_jobs_lock "/var/run/force-update.lock" "handle-trap"

connect_or_update_git_repos "update" 
connect_or_update_docker "update"

periodic_job_update_permitted_resources
