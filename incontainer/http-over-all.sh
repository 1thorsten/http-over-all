#!/usr/bin/env bash
SDS_READY="/var/run/sds.ready"
SDS_NO_HTTP="/var/run/sds.no_http"
rm -f ${SDS_READY} ${SDS_NO_HTTP}

source /scripts/connect-services.sh
TINY_INSTANCE="$(var_exp "TINY_INSTANCE" "false")"
_ENV=$(env)

SYS_ENV=/var/run/sys_env.sh
{
echo "$_ENV" | grep "^[A-Z]*_[0-9]*_" | sort -t '_' -k1,1 -k2,2n | awk -F '=' '{printf "export %s=\"%s\"\n",$1,$2 }'
echo "$_ENV" | grep "^DATA" | awk -F '=' '{printf "export %s=\"%s\"\n",$1,$2 }'
echo "$_ENV" | grep "^HTDOCS" | awk -F '=' '{printf "export %s=\"%s\"\n",$1,$2 }'
echo "$_ENV" | grep "^TZ" | awk -F '=' '{printf "export %s=\"%s\"\n",$1,$2 }'
} > "${SYS_ENV}"

echo "-- ENV --"
for RES in DAV DOCKER GIT LOCAL NFS PROXY SMB SSH; do
  echo "$_ENV" | grep -vi "crypt" | grep "^${RES}_[0-9]*_" | sort -t '_' -k2 -n
done
for RES in DAV DOCKER GIT LOCAL NFS PROXY SMB SSH; do
  _ENV=$(echo "$_ENV" | grep -v "^${RES}_[0-9]*_")
done
echo "---------"
echo "$_ENV" | grep -vi "crypt" | sort
echo "-- ENV --"

mkdir -p "${DATA}"

initialize

clean_up

if ! mount_nfs_shares; then
  echo "$(date +'%T'): error connecting resource -> set to ERROR (http-over-all -> RELEASE: ${RELEASE})"
  sleep inf
  exit 1
fi

if ! mount_smb_shares; then
  echo "$(date +'%T'): error connecting resource -> set to ERROR (http-over-all -> RELEASE: ${RELEASE})"
  sleep inf
  exit 1
fi

if ! mount_ssh_shares; then
  echo "$(date +'%T'): error connecting resource -> set to ERROR (http-over-all -> RELEASE: ${RELEASE})"
  sleep inf
  exit 1
fi

if ! mount_dav_shares; then
  echo "$(date +'%T'): error connecting resource -> set to ERROR (http-over-all -> RELEASE: ${RELEASE})"
  sleep inf
  exit 1
fi

if ! connect_or_update_git_repos "connect"; then
  echo "$(date +'%T'): error connecting resource -> set to ERROR (http-over-all -> RELEASE: ${RELEASE})"
  sleep inf
  exit 1
fi

if ! handle_proxy; then
  echo "$(date +'%T'): error connecting resource -> set to ERROR (http-over-all -> RELEASE: ${RELEASE})"
  sleep inf
  exit 1
fi

if ! handle_local_paths; then
  echo "$(date +'%T'): error connecting resource -> set to ERROR (http-over-all -> RELEASE: ${RELEASE})"
  sleep inf
  exit 1
fi

if ! connect_or_update_docker "connect"; then
  echo "$(date +'%T'): error connecting resource -> set to ERROR (http-over-all -> RELEASE: ${RELEASE})"
  sleep inf
  exit 1
fi

echo touch /var/run/force-update.last
touch /var/run/force-update.last

HTTP_SERVER_START="$(var_exp "HTTP_SERVER_START" "true")"
if [ "$HTTP_SERVER_START" = "true" ]; then
  start_http_server
elif [ "$HTTP_SERVER_START" = "light" ]; then
  start_light_http_server
else
  echo "$(date +'%T'): do not start nginx -> (env: HTTP_SERVER_START != true | light)"
  touch ${SDS_NO_HTTP}
fi

touch ${SDS_READY}
for i in "${DATA}"/*; do
  touch "$i/sds.ready"
done

echo
source /etc/os-release
echo "$(date +'%T'): ready -> ${PRETTY_NAME}"
echo "$(date +'%T'): http-over-all -> RELEASE: ${RELEASE}"

echo
periodic_jobs
