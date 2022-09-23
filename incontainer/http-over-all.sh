#!/usr/bin/env bash
SDS_READY="/var/run/sds.ready"
rm -f ${SDS_READY}

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
  echo "$_ENV" | grep "^${RES}_[0-9]*_" | sort -t '_' -k2 -n
done
for RES in DAV DOCKER GIT LOCAL NFS PROXY SMB SSH; do
  _ENV=$(echo "$_ENV" | grep -v "^${RES}_[0-9]*_")
done
echo "---------"
echo "$_ENV" | sort
echo "-- ENV --"

mkdir -p "${DATA}"

initialize

clean_up

mount_nfs_shares

mount_smb_shares

mount_ssh_shares

mount_dav_shares

connect_or_update_git_repos "connect"

handle_proxy

handle_local_paths

connect_or_update_docker "connect"

echo touch /var/run/force-update.last
touch /var/run/force-update.last

start_http_server

touch ${SDS_READY}

echo
source /etc/os-release
echo "$(date +'%T'): ready -> ${PRETTY_NAME}"
echo "$(date +'%T'): http-over-all -> RELEASE: ${RELEASE}"

trap "term_handler" EXIT

echo
periodic_jobs
