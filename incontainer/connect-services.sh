#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2181
# SC2155: Declare and assign separately to avoid masking return values.
# SC2181: Check exit code directly with e.g. 'if mycmd;', not indirectly with $?
source /scripts/helper.sh

function mount_dav_shares() {
  for COUNT in $(env | grep -o "^DAV_[0-9]*_NAME" | awk -F '_' '{print $2}' | sort -nu); do
    local PASS="$(var_exp "DAV_${COUNT}_PASS")"
    local USER="$(var_exp "DAV_${COUNT}_USER")"
    local SHARE="$(var_exp "DAV_${COUNT}_SHARE")"
    local RESOURCE_NAME="$(var_exp "DAV_${COUNT}_NAME")"
    local DAV_ACTIVE="$(var_exp "DAV_${COUNT}_DAV" "false")"
    local HTTP_ACTIVE="$(var_exp "DAV_${COUNT}_HTTP" "true")"
    local CACHE_ACTIVE="$(var_exp "DAV_${COUNT}_CACHE" "true")"
    echo
    echo "$(date +'%T'): dav: ${RESOURCE_NAME}"

    local DAV_MOUNT="${DATA}/dav/${COUNT}"

    if [ -e "${DAV_MOUNT}" ] && [ ! -e "${DAV_MOUNT}/${RESOURCE_NAME}" ]; then
      echo "delete orphaned data"
      rm -rf "${DAV_MOUNT:?}/*"
    fi
    mkdir -p "${DAV_MOUNT}"

    # umount share if already mounted
    if [[ "$(mount | grep -c "${DAV_MOUNT}")" == "1" ]]; then
      echo "umount -u ${DAV_MOUNT}"
      umount -u "${DAV_MOUNT}"
    fi

    # check accessibility
    local ACCESSIBLE
    local HTTP_STATUS="$(curl --user "${USER}:${PASS}" -s -o /dev/null -I -w "%{http_code}" --connect-timeout 1 "${SHARE%/}/")"
    if [[ "${HTTP_STATUS}" -eq '200' || "${HTTP_STATUS}" -eq '401' ]]; then
      ACCESSIBLE=true
    else
      ACCESSIBLE=false
      echo "resource (${SHARE}) is not accessible -> ignore"
    fi

    if ${ACCESSIBLE}; then
      local id_user="$(id -u "www-data")"
      local gid_user="$(id -g "www-data")"
      echo "echo obfuscated | mount -t davfs ${SHARE} ${DAV_MOUNT} -o users,uid=${id_user},gid=${gid_user},username=${USER}"
      echo "${PASS}" | mount -t davfs "${SHARE}" "${DAV_MOUNT}" -o "users,uid=${id_user},gid=${gid_user},username=${USER}"
      if [ $? -eq 0 ]; then
        initial_create_symlinks_for_resources "${RESOURCE_NAME}" "DAV_${COUNT}" "${DAV_MOUNT}" "${HTTP_ACTIVE}" "${DAV_ACTIVE}" "${CACHE_ACTIVE}"
      else
        echo "mount not successful (ignore): ${SHARE}"
        echo "sometimes it only works on the second try..."
      fi
    fi
  done
}

function mount_ssh_shares() {
  for COUNT in $(env | grep -o "^SSH_[0-9]*_NAME" | awk -F '_' '{print $2}' | sort -nu); do
    local PASS="$(var_exp "SSH_${COUNT}_PASS")"
    local SHARE="$(var_exp "SSH_${COUNT}_SHARE")"
    local SSH_PORT="$(var_exp "SSH_${COUNT}_PORT" "22")"
    local RESOURCE_NAME="$(var_exp "SSH_${COUNT}_NAME")"
    local DAV_ACTIVE="$(var_exp "SSH_${COUNT}_DAV" "false")"
    local HTTP_ACTIVE="$(var_exp "SSH_${COUNT}_HTTP" "true")"
    local CACHE_ACTIVE="$(var_exp "SSH_${COUNT}_CACHE" "true")"
    echo
    echo "$(date +'%T'): ssh: ${RESOURCE_NAME}"

    local SSH_MOUNT="${DATA}/ssh/${COUNT}"

    if [ -e "${SSH_MOUNT}" ] && [ ! -e "${SSH_MOUNT}/${RESOURCE_NAME}" ]; then
      echo "delete orphaned data"
      rm -rf "${SSH_MOUNT:?}/*"
    fi

    mkdir -p "${SSH_MOUNT}"

    # umount share if already mounted
    if [[ "$(mount | grep -c "${SSH_MOUNT}")" == "1" ]]; then
      echo "fusermount -u ${SSH_MOUNT}"
      fusermount -u "${SSH_MOUNT}"
    fi

    local id_user="$(id -u www-data)"
    local gid_user="$(id -g www-data)"
    echo "echo obfuscated | /usr/bin/sshfs '${SHARE}' ${SSH_MOUNT} -p ${SSH_PORT} -o password_stdin -o StrictHostKeyChecking=no -o auto_unmount,allow_other,follow_symlinks,reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,cache=no -o uid=${id_user},gid=${gid_user}"
    echo "${PASS}" | /usr/bin/sshfs "${SHARE}" "${SSH_MOUNT}" -p "${SSH_PORT}" -o "password_stdin" -o "StrictHostKeyChecking=no" -o "auto_unmount,allow_other,follow_symlinks,reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,cache=no" -o "uid=${id_user},gid=${gid_user}"
    if [ $? -eq 0 ]; then
      initial_create_symlinks_for_resources "${RESOURCE_NAME}" "SSH_${COUNT}" "${SSH_MOUNT}" "${HTTP_ACTIVE}" "${DAV_ACTIVE}" "${CACHE_ACTIVE}"
    else
      echo "mount not successful (ignore): ${SHARE}"
    fi
  done
}

# https://help.ubuntu.com/lts/serverguide/network-file-system.html.en
# https://wiki.ubuntuusers.de/NFS/
function mount_nfs_shares() {
  for COUNT in $(env | grep -o "^NFS_[0-9]*_SHARE" | awk -F '_' '{print $2}' | sort -nu); do
    local SHARE="$(var_exp "NFS_${COUNT}_SHARE")"
    local OPTS="$(var_exp "NFS_${COUNT}_OPTS")"
    local RESOURCE_NAME="$(var_exp "NFS_${COUNT}_NAME")"
    local DAV_ACTIVE="$(var_exp "NFS_${COUNT}_DAV" "false")"
    local HTTP_ACTIVE="$(var_exp "NFS_${COUNT}_HTTP" "true")"
    local CACHE_ACTIVE="$(var_exp "NFS_${COUNT}_CACHE" "true")"
    echo
    echo "$(date +'%T'): nfs: ${RESOURCE_NAME}"

    local NFS_MOUNT="${DATA}/nfs/${COUNT}"
    if [ -e "${NFS_MOUNT}" ] && [ ! -e "${NFS_MOUNT}/${RESOURCE_NAME}" ]; then
      echo "delete orphaned data"
      rm -rf "${NFS_MOUNT:?}/*"
    fi
    mkdir -p "${NFS_MOUNT}"

    # umount share if already mounted
    if [[ "$(mount | grep -c "${NFS_MOUNT}")" == "1" ]]; then
      echo "umount -f ${NFS_MOUNT}"
      umount -f "${NFS_MOUNT}"
    fi

    local NFS_OPTS
    if [ "${OPTS}" != "nil" ]; then
      echo "additional options detected: ${OPTS}"
      NFS_OPTS="-o ${OPTS}"
    fi

    echo "mount -v $SHARE $NFS_MOUNT $NFS_OPTS"
    # shellcheck disable=SC2086
    mount -v "$SHARE" "$NFS_MOUNT" $NFS_OPTS

    initial_create_symlinks_for_resources "${RESOURCE_NAME}" "NFS_${COUNT}" "${NFS_MOUNT}" "${HTTP_ACTIVE}" "${DAV_ACTIVE}" "${CACHE_ACTIVE}"
  done
}

function mount_smb_shares() {
  for COUNT in $(env | grep -o "^SMB_[0-9]*_SHARE" | awk -F '_' '{print $2}' | sort -nu); do
    local USER="$(var_exp "SMB_${COUNT}_USER")"
    local PASS="$(var_exp "SMB_${COUNT}_PASS")"
    local SHARE="$(var_exp "SMB_${COUNT}_SHARE")"
    local OPTS="$(var_exp "SMB_${COUNT}_OPTS")"
    local RESOURCE_NAME="$(var_exp "SMB_${COUNT}_NAME")"
    local DAV_ACTIVE="$(var_exp "SMB_${COUNT}_DAV" "false")"
    local HTTP_ACTIVE="$(var_exp "SMB_${COUNT}_HTTP" "true")"
    local CACHE_ACTIVE="$(var_exp "SMB_${COUNT}_CACHE" "true")"
    echo
    echo "$(date +'%T'): smb: ${RESOURCE_NAME}"

    local SMB_MOUNT="${DATA}/smb/${COUNT}"
    if [ -e "${SMB_MOUNT}" ] && [ ! -e "${SMB_MOUNT}/${RESOURCE_NAME}" ]; then
      echo "delete orphaned data"
      rm -rf "${SMB_MOUNT:?}/*"
    fi
    mkdir -p "${SMB_MOUNT}"

    # umount share if already mounted
    if [[ "$(mount | grep -c "${SMB_MOUNT}")" == "1" ]]; then
      echo "umount -f ${SMB_MOUNT}"
      umount -f "${SMB_MOUNT}"
    fi

    local SMB_OPTS=''
    if [[ "$OPTS" != "nil" ]]; then
      echo "additional options detected: $OPTS"
      SMB_OPTS=",$OPTS"
    fi

    echo "mount -t cifs ${SHARE} ${SMB_MOUNT} -o user=${USER},password=obfuscated,iocharset=utf8,uid=www-data,gid=www-data,forceuid,forcegid${SMB_OPTS}"
    mount -t cifs "${SHARE}" "${SMB_MOUNT}" -o "user=${USER},password=${PASS},iocharset=utf8,uid=www-data,gid=www-data,forceuid,forcegid${SMB_OPTS}"

    if [ $? -eq 0 ]; then
      initial_create_symlinks_for_resources "${RESOURCE_NAME}" "SMB_${COUNT}" "${SMB_MOUNT}" "${HTTP_ACTIVE}" "${DAV_ACTIVE}" "${CACHE_ACTIVE}"
    else
      echo "mount not successful (ignore): ${SHARE}"
    fi
  done
}

function connect_or_update_docker() {
  local TYPE="${1}"
  for COUNT in $(env | grep -o "^DOCKER_[0-9]*_IMAGE" | awk -F '_' '{print $2}' | sort -nu); do
    local IMAGE="$(var_exp "DOCKER_${COUNT}_IMAGE")"
    local TAG="$(var_exp "DOCKER_${COUNT}_TAG" "latest")"
    local LOGIN="$(var_exp "DOCKER_${COUNT}_LOGIN")"
    local METHOD="$(var_exp "DOCKER_${COUNT}_METHOD" "TAR")"
    local SRC_DIRS="$(var_exp "DOCKER_${COUNT}_SRC_DIRS" "./")"
    local EXCLUDES="$(var_exp "DOCKER_${COUNT}_EXCL")"
    local RESOURCE_NAME="$(var_exp "DOCKER_${COUNT}_NAME")"
    local DAV_ACTIVE="$(var_exp "DOCKER_${COUNT}_DAV" "false")"
    local HTTP_ACTIVE="$(var_exp "DOCKER_${COUNT}_HTTP" "true")"
    local CACHE_ACTIVE="$(var_exp "DOCKER_${COUNT}_CACHE" "false")"

    local REPO_PATH="${DATA}/docker/${COUNT}"
    local REPO_DIR="$(echo "${REPO_URL}" | awk -F '/' '{print $NF}' | cut -d '.' -f 1)"

    local DOCKER_MOUNT="${REPO_PATH}/${REPO_DIR}"

    echo
    echo "$(date +'%T'): docker ($TYPE): ${RESOURCE_NAME} (${IMAGE}) | ${DOCKER_MOUNT}"

    if [ -e "${DOCKER_MOUNT}" ] && [ ! -e "${DOCKER_MOUNT}/${RESOURCE_NAME}" ]; then
      echo "delete orphaned data"
      rm -rf "${DOCKER_MOUNT:?}/*"
    fi
    mkdir -p "${DOCKER_MOUNT}"

    chown "www-data:www-data" "${DOCKER_MOUNT}"

    if [ "$LOGIN" != "nil" ]; then
      echo "login"
      if ! login_output="$($LOGIN 2>&1)"; then
        echo "login not succeeded ($LOGIN)"
        echo "ERR: ${login_output}"
        echo "ignore ${RESOURCE_NAME}"
        continue
      fi
    fi

    local PULL="docker pull ${IMAGE}:${TAG}"
    local IMAGE_STATUS="NEW"
    local DIGEST

    echo "$PULL"
    if ! pull_output=$(docker pull "${IMAGE}:${TAG}" 2>&1); then
      echo "ERR (pull): ${pull_output}"

      # check if the image exists at all, if not then ignore resource
      if ! docker history "${IMAGE}:${TAG}" 2>&1; then
        echo "ignore ${RESOURCE_NAME}"
        continue
      else
        # could not pull, but image exists
        echo "image exists, so take this old one."
        IMAGE_STATUS="OLD"
      fi
    elif [[ "${pull_output}" == *"Status: Image is up to date"* ]]; then
      DIGEST=$(docker images --no-trunc --quiet "${IMAGE}:${TAG}" | tr ':' '_')
      if [ "${TYPE}" != "connect" ] && [ ! -e "/tmp/docker-digests/$DIGEST" ]; then
        echo "recognize usage of known but unused image, declare it to NEW (digest: $DIGEST)"
        IMAGE_STATUS="NEW"
      else
        IMAGE_STATUS="OLD"
      fi
    fi

    if [ "$IMAGE_STATUS" == "NEW" ] || [ "${TYPE}" == "connect" ]; then
      # for better update detecting get the digest for the image
      if [ -z "$DIGEST" ]; then DIGEST=$(docker images --no-trunc --quiet "${IMAGE}":"${TAG}" | tr ':' '_'); fi
      echo "digest: $DIGEST"
      echo "${IMAGE}:${TAG}" >"/tmp/docker-digests/$DIGEST"

      # remove <none> images (one backup should be fine)
      if none_images=$(docker images | grep "$IMAGE.*<none>" | awk '{print $3}'); then
        if [ "$none_images" != "" ]; then
          echo "remove old images: $none_images"
          docker rmi -f "$none_images"
        fi
      fi

      if [ "$METHOD" == "TAR" ]; then
        local tmp_dir=$(mktemp -d -t docker-tar-XXXXXXXXXXXX)
        # handle excludes
        local exclude_list
        if [ "$EXCLUDES" != "nil" ]; then
          echo "$METHOD: path excludes: $EXCLUDES"
          for excl in $EXCLUDES; do
            exclude_list="$exclude_list --exclude=$excl"
          done
        fi
        for dir in $SRC_DIRS; do
          # without slashes (/usr/lib/ -> usr/lib, ./ -> .)
          local DIR_BASE=${dir#/}
          DIR_BASE=${DIR_BASE%/}
          echo "$METHOD: $dir (base: $DIR_BASE) start at $(date +'%T')"
          if [ "$DIR_BASE" == "." ]; then
            docker run --rm --entrypoint "" "${IMAGE}:${TAG}" /bin/sh -c "tar c -h $exclude_list * -f -" | tar Chxf "$tmp_dir" -
          else
            docker run --rm --entrypoint "" "${IMAGE}:${TAG}" /bin/sh -c "tar c -h $exclude_list -C/ ${DIR_BASE}/* -f -" | tar Chxf "$tmp_dir" -
          fi
        done
        echo "start rsync at $(date +'%T')"
        rsync -rtu --delete "${tmp_dir}"/ "${DOCKER_MOUNT}"
        rm -rf "${tmp_dir}"
      elif [ "$METHOD" == "COPY" ]; then
        # usage of docker cp
        local tmp_dir=$(mktemp -d -t docker-copy-XXXXXXXXXXXX)
        # handle excludes
        local exclude_list
        local tmp_exclude_file
        if [ "$EXCLUDES" != "nil" ]; then
          echo "$METHOD: path excludes: $EXCLUDES (after copying data from container -> via rsync)"
          tmp_exclude_file=$(mktemp /tmp/docker-copy-excludes.XXXXXX)
          exclude_list="--exclude-from=$tmp_exclude_file"
          for excl in $EXCLUDES; do
            echo "- $excl" >> "$tmp_exclude_file"
          done
        fi
        # create a container from the image (for data extraction)
        local TMP_CNT=$(docker create "${IMAGE}:${TAG}")
        for dir in $SRC_DIRS; do
          echo "$METHOD: $dir | start at $(date +'%T')"
          docker cp -L "$TMP_CNT":"$dir" "$tmp_dir"
        done
        # remove container after copying data
        docker rm "$TMP_CNT" > /dev/null
        echo "start rsync at $(date +'%T')"
        # shellcheck disable=SC2086
        rsync -rtu --links --delete $exclude_list "${tmp_dir}"/ "${DOCKER_MOUNT}"
        if [ "$tmp_exclude_file" != "" ]; then
          rm -f "$tmp_exclude_file"
        fi
        rm -rf "$tmp_dir"
      else
        echo "unknown method: $METHOD | ignore"
        continue
      fi
    fi
    # update -> call from periodic_jobs
    if [ "${TYPE}" != "update" ]; then
      initial_create_symlinks_for_resources "${RESOURCE_NAME}" "DOCKER_${COUNT}" "${DOCKER_MOUNT}" "${HTTP_ACTIVE}" "${DAV_ACTIVE}" "${CACHE_ACTIVE}"
    fi
  done
}

function connect_or_update_git_repos() {
  local TYPE="${1}"
  for COUNT in $(env | grep -o "^GIT_[0-9]*_REPO_URL" | awk -F '_' '{print $2}' | sort -nu); do
    local REPO_URL="$(var_exp "GIT_${COUNT}_REPO_URL")"
    local REPO_BRANCH="$(var_exp "GIT_${COUNT}_REPO_BRANCH" "master")"
    local RESOURCE_NAME="$(var_exp "GIT_${COUNT}_NAME")"
    local DAV_ACTIVE="$(var_exp "GIT_${COUNT}_DAV" "false")"
    local HTTP_ACTIVE="$(var_exp "GIT_${COUNT}_HTTP" "true")"
    local CACHE_ACTIVE="$(var_exp "GIT_${COUNT}_CACHE" "false")"

    local GIT_REPO_PATH="${DATA}/git/${COUNT}"
    local REPO_DIR="$(echo "${REPO_URL}" | awk -F '/' '{print $NF}' | cut -d '.' -f 1)"
    local GIT_MOUNT="${GIT_REPO_PATH}/${REPO_DIR}"

    echo
    echo "$(date +'%T'): git ($TYPE): ${RESOURCE_NAME} (${REPO_BRANCH}) | ${GIT_MOUNT}"

    if [ -e "${GIT_REPO_PATH}" ] && [ ! -e "${GIT_MOUNT}" ]; then
      echo "delete orphaned data"
      rm -rf "${GIT_REPO_PATH:?}/*"
    fi

    # check accessibility
    local ACCESSIBLE
    parse_url "${REPO_URL%/}/"
    local URL_STRICT="${PARSED_PROTO}${PARSED_HOST}${PARSED_PORT}"
    if [ -n "$PARSED_USER" ]; then
      local CURL_CREDENTIALS="--user ${PARSED_USER%@}"
    fi
    # shellcheck disable=SC2086
    local HTTP_STATUS="$(curl ${CURL_CREDENTIALS} -s -o /dev/null -I -w "%{http_code}" --connect-timeout 1 "${URL_STRICT}")"
    if [[ "${HTTP_STATUS}" -eq '200' || "${HTTP_STATUS}" -eq '401' || "${HTTP_STATUS}" -eq '302' ]]; then
      ACCESSIBLE=true
    else
      ACCESSIBLE=false
      echo "command: curl ${CURL_CREDENTIALS} -s -o /dev/null -I -w %{http_code} --connect-timeout 1 ${URL_STRICT}"
      echo "resource ('${REPO_URL}' -> '${URL_STRICT}') is not accessible -> ${HTTP_STATUS}"
    fi

    if [ ! -d "${GIT_MOUNT}" ]; then
      if ! ${ACCESSIBLE}; then
        echo "${GIT_MOUNT} not exists -> ignore"
        continue
      fi
      clone_git_repo "${GIT_REPO_PATH}" "${REPO_URL}" "$RESOURCE_NAME"
    elif [ -e "${GIT_REPO_PATH}.error" ]; then
      echo "detect previous error: ${GIT_REPO_PATH}.error"
      if ${ACCESSIBLE}; then
        clone_git_repo_safe "${GIT_REPO_PATH}" "${REPO_URL}" "$RESOURCE_NAME"
      fi
      # if error file still exists, go with the existing local repo
      if [ -e "${GIT_REPO_PATH}.error" ]; then
        if [[ "${TYPE}" != "update" ]] && [[ -d "${GIT_MOUNT}" ]]; then
          initial_create_symlinks_for_resources "${RESOURCE_NAME}" "GIT_${COUNT}" "${GIT_MOUNT}" "${HTTP_ACTIVE}" "${DAV_ACTIVE}" "${CACHE_ACTIVE}"
          rm -f "${GIT_REPO_PATH}.error"
        fi
        continue
      fi
    else
      # remove lock to repo since this should be an error
      rm -f "${GIT_MOUNT}/.git/index.lock"
    fi

    # branch handling
    local git_branch="${REPO_BRANCH}"

    if ${ACCESSIBLE}; then
      local git_checkout=$(git -C "${GIT_MOUNT}" checkout "${git_branch}" -f 2>&1)
      if [[ "${git_checkout}" != *"Already on"* ]]; then echo "${git_checkout}"; fi

      git -C "${GIT_MOUNT}" clean -df
      git -C "${GIT_MOUNT}" reset --hard >/dev/null
    fi

    # on error clone repo again!! avoid counting COUNT to repeat all actions
    if ! git_output="$(git -C "${GIT_MOUNT}" pull 2>&1)"; then
      echo "git -C ${GIT_MOUNT} pull"
      echo "ERR: ${git_output}"
      if [[ "${git_output}" == *"The requested URL returned error: 503"* ]]; then
        echo "git repo is currently not accessible -> backup"
        ACCESSIBLE=false
      elif [[ "${git_output}" == *"Could not resolve host"* ]]; then
        echo "git repo is currently not accessible -> host could not resolved"
        ACCESSIBLE=false
      elif [[ "${git_output}" == *"unable to update"* ]]; then
        echo "git repo is currently not accessible -> unable to update"
        ACCESSIBLE=false
      elif [[ "${git_output}" == *"unable to access"* ]]; then
        echo "git repo is currently not accessible -> unable to access"
        ACCESSIBLE=false
      elif [[ "${git_output}" == *"Authentication failed"* ]]; then
        echo "git repo is currently not accessible -> Authentication failed"
        ACCESSIBLE=false
      else
        echo "error resetting state, retrieve repo again"
        echo "touch ${GIT_REPO_PATH}.error"
        touch "${GIT_REPO_PATH}.error"
        continue
      fi
    fi

    if ${ACCESSIBLE}; then
      # all works well / show subject of last commit
      local git_log=$(git -C "${GIT_MOUNT}" log -1 --pretty=format:'%s')
      echo "last_commit_log: ${git_log}"
    fi
    # update -> call from periodic_jobs
    if [ "${TYPE}" != "update" ]; then
      echo
      initial_create_symlinks_for_resources "${RESOURCE_NAME}" "GIT_${COUNT}" "${GIT_MOUNT}" "${HTTP_ACTIVE}" "${DAV_ACTIVE}" "${CACHE_ACTIVE}"
    fi
  done
}

function handle_local_paths() {
  for COUNT in $(env | grep -o "^LOCAL_[0-9]*_PATH" | awk -F '_' '{print $2}' | sort -nu); do
    local LOCAL_NAME="$(var_exp "LOCAL_${COUNT}_NAME")"
    local LOCAL_PATH="$(var_exp "LOCAL_${COUNT}_PATH")"
    local DAV_ACTIVE="$(var_exp "LOCAL_${COUNT}_DAV" "false")"
    local HTTP_ACTIVE="$(var_exp "LOCAL_${COUNT}_HTTP" "true")"
    local CACHE_ACTIVE="$(var_exp "LOCAL_${COUNT}_CACHE" "false")"

    echo
    echo "$(date +'%T'): local: ${LOCAL_NAME}"

    if [ ! -d "${LOCAL_PATH}" ]; then
      echo "LOCAL_${COUNT}_PATH: ${LOCAL_PATH}: not exists -> ignore"
    else
      # no subdir supported so far, so "LOCAL_${COUNT}" always points to a non existing location
      initial_create_symlinks_for_resources "${LOCAL_NAME}" "LOCAL_${COUNT}" "${LOCAL_PATH}" "${HTTP_ACTIVE}" "${DAV_ACTIVE}" "${CACHE_ACTIVE}"
    fi
  done
}

function handle_proxy() {
  for COUNT in $(env | grep -o "^PROXY_[0-9]*_URL" | awk -F '_' '{print $2}' | sort -nu); do
    local PROXY_NAME="$(var_exp "PROXY_${COUNT}_NAME")"
    local PROXY_URL="$(var_exp "PROXY_${COUNT}_URL")"
    local PROXY_CACHE="$(var_exp "PROXY_${COUNT}_CACHE_TIME")"
    local PROXY_MODE_DEFAULT="cache"
    local HTTP_ROOT_SHOW="$(var_exp "PROXY_${COUNT}_HTTP_ROOT_SHOW" "true")"
    local IP_RESTRICTION="$(var_exp "PROXY_${COUNT}_IP_RESTRICTION" "allow all")"

    echo
    echo "$(date +'%T'): proxy: $PROXY_NAME"

    parse_url "${PROXY_URL%/}/"
    local STATUS
    if [ "${PARSED_HOST,,}" == "unix" ]; then
      PROXY_MODE_DEFAULT="direct"
      # PARSED_PATH = :/var/run/docker.sock:/ -> /var/run/docker.sock
      SOCKET_FILE=$(echo "$PARSED_PATH" | awk -F ':' '{print $2}')
      echo "unix socket: $SOCKET_FILE"
      STATUS='200'
      if ! socket_permission "$SOCKET_FILE"; then
        echo "unix socket is not accessible"
        STATUS='404'
      fi
      local permissions=$(stat -c '%A %a %n' "$SOCKET_FILE")
      echo "permissions: $permissions"
    else
      # check accessibility
      echo "check accessibility : curl -s -o /dev/null -I -w '%{http_code}' --connect-timeout 1 ${PROXY_URL%/}/"
      STATUS="$(curl -s -o /dev/null -I -w "%{http_code}" --connect-timeout 1 "${PROXY_URL%/}/")"
    fi

    local PROXY_MODE="$(var_exp "PROXY_${COUNT}_MODE" "$PROXY_MODE_DEFAULT")"

    if [[ "${STATUS}" -eq '200' || "${STATUS}" -eq '401' ]]; then
      if [[ ${IP_RESTRICTION,,} != *"satisfy"* ]]; then
        IP_RESTRICTION="satisfy all; $IP_RESTRICTION"
      fi
      if [ "${PROXY_CACHE}" == "nil" ]; then
        SED_PATTERN="s|__PROXY_NAME__|${PROXY_NAME%/}|; s|__PROXY_URL__|${PROXY_URL%/}/|; s|#IP_RESTRICTION|${IP_RESTRICTION%;};|;"
      else
        SED_PATTERN="s|__PROXY_NAME__|${PROXY_NAME%/}|; s|__PROXY_URL__|${PROXY_URL%/}/|; s|#IP_RESTRICTION|${IP_RESTRICTION%;};|; s|__PROXY_CACHE_TIME__|${PROXY_CACHE}|;  s|#proxy_cache|proxy_cache|;"
      fi

      if [ "${PROXY_MODE,,}" == "direct" ]; then
        PROXY_MODE="direct"
      else
        PROXY_MODE="cache"
      fi
      local TEMP_FILE="${NGINX_CONF}/proxy_${PROXY_NAME}.conf"
      echo "use nginx-config/location-proxy-$PROXY_MODE.template"
      sed "${SED_PATTERN}" nginx-config/location-proxy-"$PROXY_MODE".template >"${TEMP_FILE}"

      handle_log "${TEMP_FILE}" "PROXY_${COUNT}_LOG_ACCESS" "PROXY_${COUNT}_LOG_ERROR"
      handle_basic_auth "PROXY_${COUNT}_AUTH" "proxy_${PROXY_NAME}" "${TEMP_FILE}"

      if [ "${HTTP_ROOT_SHOW}" == "true" ]; then
        echo "HTTP: root show active"
        echo "mkdir -p ${HTDOCS%/}/${PROXY_NAME%/}"
        mkdir -p "${HTDOCS%/}/${PROXY_NAME%/}"
        chown www-data:www-data "${HTDOCS%/}/${PROXY_NAME%/}"
      else
        sed -i "/autoindex/d" "${TEMP_FILE}"
      fi
      sed -i "/#/d" "${TEMP_FILE}"
    else
      echo "resource is not accessible (ignore): ${PROXY_URL}"
    fi
  done
}

function start_http_server() {
  echo
  echo "$(date +'%T'): start http server"

  mkdir -p "/tmp/cache"
  chown -R "www-data:www-data" "/tmp/cache"
  chmod -R "a+rw" "/tmp/cache"

  local PHP_LOG_FILE="/tmp/php.log"
  touch ${PHP_LOG_FILE}
  chown "www-data:www-data" ${PHP_LOG_FILE}
  # https://unix.stackexchange.com/questions/261531/how-to-send-output-from-one-terminal-to-another-without-making-any-new-pipe-or-f
  if [ "$PHP_LOG_SYSOUT" == "false" ]; then
    echo "avoid redirecting ${PHP_LOG_FILE} to stdout (PHP_LOG_SYSOUT: $PHP_LOG_SYSOUT)"
  else
    echo "redirect ${PHP_LOG_FILE} to stdout from main_process (PHP_LOG_SYSOUT: $PHP_LOG_SYSOUT)"
    tail -f ${PHP_LOG_FILE} >"/proc/1/fd/1" &
  fi

  echo "handle README.html (weave README.md and link to ${HTDOCS})"
  sed -i "/__INCLUDE_README__/r README.md" "/scripts/nginx-config/README.html"
  # remove the __INCLUDE_README__ line
  sed -i "/__INCLUDE_README__/d" "/scripts/nginx-config/README.html"
  ln -fs "/scripts/nginx-config/README.html" "${HTDOCS}/README.html"

  if [ -e "/tmp/nginx_proxy_cache_active.check" ]; then
    echo "activate proxy cache"
    sed -i "s|#proxy_cache_path|proxy_cache_path|;" "/etc/nginx/nginx.conf"
  fi

  echo "service ${PHP7_SERVICE} start"
  service "${PHP7_SERVICE}" "start"

  nginx -v

  if ! nginx; then
    cat /var/log/nginx/error.log
    exit 1
  fi
}
