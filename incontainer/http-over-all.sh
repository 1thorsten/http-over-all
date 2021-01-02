#!/usr/bin/env bash
SDS_READY="/tmp/sds.ready"
rm -f ${SDS_READY}

source "/scripts/connect-services.sh"

echo "-- ENV --"
env | grep "^DAV_" | sort
env | grep "^GIT_" | sort
env | grep "^LOCAL_" | sort
env | grep "^NFS_" | sort
env | grep "^PROXY_" | sort
env | grep "^SMB_" | sort
env | grep "^SSH_" | sort
env | grep -v "^SMB_" | grep -v "^GIT_" | grep -v "^LOCAL_" | grep -v "^SSH_" | grep -v "^DAV_" | grep -v "^PROXY_" | grep -v "^NFS_" | sort

SYS_ENV=/var/run/sys_env.sh
env | grep "^[A-Z]*_[0-9]*_" | sort | awk -F '=' '{printf "export %s\n",$0 }' > "${SYS_ENV}"
env | grep "^HTDOCS" | awk -F '=' '{printf "export %s\n",$0 }' >> "${SYS_ENV}"
env | grep "^DATA" | awk -F '=' '{printf "export %s\n",$0 }' >> "${SYS_ENV}"

echo "---------"

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

start_http_server

touch ${SDS_READY}

echo
source /etc/os-release
echo "$(date +'%T'): ready -> ${PRETTY_NAME}"

trap "term_handler" EXIT

periodic_jobs