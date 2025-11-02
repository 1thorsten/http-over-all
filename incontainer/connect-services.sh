#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2181
# SC2155: Declare and assign separately to avoid masking return values.
# SC2181: Check exit code directly with e.g. 'if mycmd;', not indirectly with $?

# nano /scripts/connect-services.sh
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
    local STOP_ON_ERROR="$(var_exp "DAV_${COUNT}_STOP_ON_ERROR" "false")"
    echo
    echo "$(date +'%T'): dav: ${RESOURCE_NAME}"

    if [ "$RESOURCE_NAME" = "nil" ]; then
      echo "ERR (config): define DAV_${COUNT}_NAME"
      return 1
    fi

    local DAV_MOUNT="${DATA}/dav/${COUNT}"

    mkdir -p "${DAV_MOUNT}"

    # umount share if already mounted
    if [[ "$(mount | grep -c "${DAV_MOUNT}")" == "1" ]]; then
      echo "umount -u ${DAV_MOUNT}"
      umount -u "${DAV_MOUNT}"
    fi

    # check accessibility
    local ACCESSIBLE
    local HTTP_STATUS="$(curl --user "${USER}:${PASS}" -s -o /dev/null -I -w "%{http_code}" --connect-timeout 1 "${SHARE%/}/")"
    if [[ "${HTTP_STATUS}" -eq '200' || "${HTTP_STATUS}" -eq '401' || "${HTTP_STATUS}" -eq '405' ]]; then
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
    elif [ "$STOP_ON_ERROR" = "true" ]; then
      echo "!!! STOP_ON_ERROR !!! -> $RESOURCE_NAME is not accessible"
      return 1
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
    local STOP_ON_ERROR="$(var_exp "SSH_${COUNT}_STOP_ON_ERROR" "false")"
    echo
    echo "$(date +'%T'): ssh: ${RESOURCE_NAME}"

    if [ "$RESOURCE_NAME" = "nil" ]; then
      echo "ERR (config): define SSH_${COUNT}_NAME"
      return 1
    fi

    local SSH_MOUNT="${DATA}/ssh/${COUNT}"

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
      if [ "$STOP_ON_ERROR" = "true" ]; then
        echo "!!! STOP_ON_ERROR !!! -> $RESOURCE_NAME is not accessible"
        return 1
      fi
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
    local STOP_ON_ERROR="$(var_exp "NFS_${COUNT}_STOP_ON_ERROR" "false")"
    echo
    echo "$(date +'%T'): nfs: ${RESOURCE_NAME}"

    if [ "$RESOURCE_NAME" = "nil" ]; then
      echo "ERR (config): define NFS_${COUNT}_NAME"
      return 1
    fi

    local NFS_MOUNT="${DATA}/nfs/${COUNT}"

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
    if [ $? -eq 0 ]; then
      initial_create_symlinks_for_resources "${RESOURCE_NAME}" "NFS_${COUNT}" "${NFS_MOUNT}" "${HTTP_ACTIVE}" "${DAV_ACTIVE}" "${CACHE_ACTIVE}"
    else
       echo "mount not successful (ignore): ${SHARE}"
       if [ "$STOP_ON_ERROR" = "true" ]; then
         echo "!!! STOP_ON_ERROR !!! -> $RESOURCE_NAME is not accessible"
         return 1
       fi
    fi
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
    local STOP_ON_ERROR="$(var_exp "SMB_${COUNT}_STOP_ON_ERROR" "false")"

    echo
    echo "$(date +'%T'): smb: ${RESOURCE_NAME}"

    if [ "$RESOURCE_NAME" = "nil" ]; then
      echo "ERR (config): define SMB_${COUNT}_NAME"
      return 1
    fi

    local SMB_MOUNT="${DATA}/smb/${COUNT}"

    mkdir -p "${SMB_MOUNT}"

    # umount share if already mounted
    if [[ "$(mount | grep -c "${SMB_MOUNT}")" == "1" ]]; then
      echo "umount -f ${SMB_MOUNT}"
      umount -f "${SMB_MOUNT}"
    fi

    local SMB_OPTS=''
    if [ "$OPTS" != "nil" ]; then
      echo "additional options detected: $OPTS"
      SMB_OPTS=",$OPTS"
    fi

    echo "mount -t cifs ${SHARE} ${SMB_MOUNT} -o user=${USER},password=obfuscated,iocharset=utf8,uid=www-data,gid=www-data,forceuid,forcegid${SMB_OPTS}"
    mount -t cifs "${SHARE}" "${SMB_MOUNT}" -o "user=${USER},password=${PASS},iocharset=utf8,uid=www-data,gid=www-data,forceuid,forcegid${SMB_OPTS}"

    if [ $? -eq 0 ]; then
      initial_create_symlinks_for_resources "${RESOURCE_NAME}" "SMB_${COUNT}" "${SMB_MOUNT}" "${HTTP_ACTIVE}" "${DAV_ACTIVE}" "${CACHE_ACTIVE}"
    else
      echo "mount not successful (ignore): ${SHARE}"
       if [ "$STOP_ON_ERROR" = "true" ]; then
         echo "!!! STOP_ON_ERROR !!! -> $RESOURCE_NAME is not accessible"
         return 1
       fi
    fi
  done
}

function connect_or_update_docker() {
  local TYPE="${1}"
  for COUNT in $(env | grep -o "^DOCKER_[0-9]*_IMAGE" | awk -F '_' '{print $2}' | sort -nu); do
    local IMAGE="$(var_exp "DOCKER_${COUNT}_IMAGE")"
    local TAG="$(var_exp "DOCKER_${COUNT}_TAG" "latest")"
    local USER="$(var_exp "DOCKER_${COUNT}_USER")"
    local PASS="$(var_exp "DOCKER_${COUNT}_PASS")"
    local DIGEST_PATH="$(var_exp "DOCKER_${COUNT}_DIGEST_PATH")"
    local SYNC_ALWAYS="$(var_exp "DOCKER_${COUNT}_SYNC_ALWAYS" "false")"

    local RESOURCE_NAME="$(var_exp "DOCKER_${COUNT}_NAME")"
    local DAV_ACTIVE="$(var_exp "DOCKER_${COUNT}_DAV" "false")"
    local HTTP_ACTIVE="$(var_exp "DOCKER_${COUNT}_HTTP" "true")"
    local CACHE_ACTIVE="$(var_exp "DOCKER_${COUNT}_CACHE" "false")"
    local STOP_ON_ERROR="$(var_exp "DOCKER_${COUNT}_STOP_ON_ERROR" "false")"

    local REPO_PATH="${DATA}/docker/${COUNT}"
    local REPO_DIR="$(echo "${REPO_URL}" | awk -F '/' '{print $NF}' | cut -d '.' -f 1)"

    local DOCKER_MOUNT="${REPO_PATH}/${REPO_DIR}"

    echo
    echo "$(date +'%T'): docker ($TYPE): ${RESOURCE_NAME} (${IMAGE}:${TAG}) | ${DOCKER_MOUNT}"

    if [ "$RESOURCE_NAME" = "nil" ]; then
      echo "ERR (config): define DOCKER_${COUNT}_NAME"
      return 1
    fi

    if [ "${TYPE}" = "connect" ] || [ ! -e "${DOCKER_MOUNT}" ]; then
      mkdir -p "${DOCKER_MOUNT}"
      chown "www-data:www-data" "${DOCKER_MOUNT}"
    fi

    local IMAGE_STATUS="NEW"
    local DIGEST
    local REAL_DIGEST_PATH="$DOCKER_MOUNT"
    local MODIFIED_FILES="0"

    if [ "$USER" = "nil" ]; then USER=""; fi
    if [ "$PASS" = "nil" ]; then PASS=""; fi
    if ! pull_output=$(doclig -action pull -image "${IMAGE}:${TAG}" -user="${USER}" -password="${PASS}" 2>&1); then
      echo "doclig -action pull -image ${IMAGE}:${TAG} -user=${USER} -password=obfuscated"
      echo "ERR (pull): ${pull_output}"

      # check if the image exists at all, if not then ignore resource
      if ! CHECK_IMAGE=$(doclig -action check-image -image "${IMAGE}:${TAG}" 2>&1); then
        echo "doclig -action check-image -image ${IMAGE}:${TAG}"
        echo "ERR (check-image): No such image: ${IMAGE}:${TAG}"
        echo "ignore ${RESOURCE_NAME}"
        if [ "$STOP_ON_ERROR" = "true" ]; then
         echo "!!! STOP_ON_ERROR !!! -> $RESOURCE_NAME is not accessible"
         return 1
        fi
        continue
      else
        DIGEST=$(echo "$CHECK_IMAGE" | grep Digest | awk -F 'sha256:' '{print $2}')
        if [ -d "${DIGEST_PATH%/}/" ]; then REAL_DIGEST_PATH="$DIGEST_PATH"; fi
        # could not pull, but image exists
        if [ ! -e "${REAL_DIGEST_PATH%/}/.${DIGEST}.digest" ]; then
          echo "image changed, declare it to NEW (digest: $DIGEST)"
          IMAGE_STATUS="NEW"
        else
          echo "image has not changed, go with that old one."
          IMAGE_STATUS="OLD"
        fi
      fi
    elif [[ "${pull_output}" == *"Status: Image is up to date"* ]]; then
      DIGEST=$(doclig -action check-image -image "${IMAGE}:${TAG}" 2>&1 | grep Digest | awk -F 'sha256:' '{print $2}')
      if [ -d "${DIGEST_PATH%/}/" ]; then REAL_DIGEST_PATH="$DIGEST_PATH"; fi
      if [ "${TYPE}" != "connect" ] && [ ! -e "${REAL_DIGEST_PATH%/}/.${DIGEST}.digest" ]; then
        echo "recognize usage of known but unused image, declare it to NEW (digest: $DIGEST)"
        IMAGE_STATUS="NEW"
      else
        IMAGE_STATUS="OLD"
      fi
    fi

    if [ "$IMAGE_STATUS" = "NEW" ] || [ "${TYPE}" = "connect" ] || [ "$SYNC_ALWAYS" = "true" ]; then
      # for better update detecting get the digest for the image
      if [ -z "$DIGEST" ]; then
        DIGEST=$(doclig -action check-image -image "${IMAGE}:${TAG}" 2>&1 | grep Digest | awk -F 'sha256:' '{print $2}');
        if [ -d "${DIGEST_PATH%/}/" ]; then REAL_DIGEST_PATH="$DIGEST_PATH"; fi
      fi
      echo "digest: $DIGEST"

      # check if the source of the remote mount has changed
      local content_has_changed=true
      local remove_old_content=false
      if [ "${TYPE}" = "connect" ]; then
        if [ ! -e "${REAL_DIGEST_PATH%/}/.${DIGEST}.digest" ]; then
          echo "image content has changed -> remove old content from ${DOCKER_MOUNT}"
          remove_old_content=true
        else
          content_has_changed=false
          echo "image content has not changed (DIGEST_PATH: ${REAL_DIGEST_PATH%/})"
        fi
      fi

      rm -f "${DOCKER_MOUNT%/}/*.digest"
      if [ -d "${DIGEST_PATH%/}/" ]; then rm -f "${DIGEST_PATH%/}/*.digest"; fi

      if [ "$content_has_changed" = true ]; then
        # remove dangling images (one backup should be fine)
        doclig -action prune > /dev/null
        sync_files_from_docker_container "$remove_old_content" "$COUNT" "$DOCKER_MOUNT" "$RESOURCE_NAME"
      elif [ "$SYNC_ALWAYS" = "true" ]; then
        sync_files_from_docker_container "$remove_old_content" "$COUNT" "$DOCKER_MOUNT" "$RESOURCE_NAME"
      fi

      echo "${IMAGE}:${TAG}" > "${DOCKER_MOUNT%/}/.${DIGEST}.digest"
      if [ -d "${DIGEST_PATH%/}/" ]; then
        echo "${IMAGE}:${TAG}" > "${DIGEST_PATH%/}/.${DIGEST}.digest"
      fi
      unset DIGEST
    fi

    # update -> call from periodic_jobs
    if [ "${TYPE}" != "update" ] || [ "$MODIFIED_FILES" != "0" ]; then
      initial_create_symlinks_for_resources "${RESOURCE_NAME}" "DOCKER_${COUNT}" "${DOCKER_MOUNT}" "${HTTP_ACTIVE}" "${DAV_ACTIVE}" "${CACHE_ACTIVE}"
    fi
  done
  if [ -d "${DATA}/docker" ]; then touch "${DATA}/docker/sds.ready"; fi
}

function connect_or_update_git_repos() {
  local TYPE="${1}"
  for COUNT in $(env | grep -o "^GIT_[0-9]*_REPO_URL" | awk -F '_' '{print $2}' | sort -nu); do
    local done=false
    while ! $done; do
      local REPO_URL="$(var_exp "GIT_${COUNT}_REPO_URL")"
      local REPO_BRANCH="$(var_exp "GIT_${COUNT}_REPO_BRANCH" "master")"
      local RESOURCE_NAME="$(var_exp "GIT_${COUNT}_NAME")"
      local SHALLOW_CLONE="$(var_exp "GIT_${COUNT}_SHALLOW_CLONE" "false")"
      local SEPARATE_GIT_DIR="$(var_exp "GIT_${COUNT}_SEPARATE_GIT_DIR" "false")"

      local DAV_ACTIVE="$(var_exp "GIT_${COUNT}_DAV" "false")"
      local HTTP_ACTIVE="$(var_exp "GIT_${COUNT}_HTTP" "true")"
      local CACHE_ACTIVE="$(var_exp "GIT_${COUNT}_CACHE" "false")"

      local STOP_ON_ERROR="$(var_exp "GIT_${COUNT}_STOP_ON_ERROR" "false")"
      local GIT_REPO_PATH="${DATA}/git/${COUNT}"
      local REPO_DIR="$(echo "${REPO_URL}" | awk -F '/' '{print $NF}' | cut -d '.' -f 1)"
      local GIT_MOUNT="${GIT_REPO_PATH}/${REPO_DIR}"

      echo
      echo "$(date +'%T'): git ($TYPE): ${RESOURCE_NAME} (${REPO_BRANCH}) | ${GIT_MOUNT}"

      if [ "$RESOURCE_NAME" = "nil" ]; then
        echo "ERR (config): define GIT_${COUNT}_NAME"
        return 1
      fi

      local GIT_DIR="${GIT_MOUNT%/}/.git"
      if [ "${SEPARATE_GIT_DIR}" = "true" ]; then
        GIT_DIR="${GIT_REPO_PATH}.git"
      elif [ -e "${GIT_REPO_PATH}.git" ]; then
        echo "delete orphaned git-dir: ${GIT_REPO_PATH}.git"
        rm -rf "${GIT_REPO_PATH}.git"
      fi
      if [ -e "${GIT_REPO_PATH}" ] && [ ! -e "${GIT_MOUNT}" ]; then
        echo "delete orphaned data: ${GIT_REPO_PATH}"
        rm -rf "${GIT_REPO_PATH:?}"/{.,}*
        if [ -e "${GIT_REPO_PATH}.git" ]; then echo "delete orphaned git-dir: ${GIT_REPO_PATH}.git"; rm -rf "${GIT_REPO_PATH}.git"; fi
      elif [ -d "${GIT_MOUNT}" ] && [ ! -d "${GIT_DIR}" ]; then
        echo "delete obsolete data: ${GIT_MOUNT}"
        rm -rf "${GIT_MOUNT:?}"/{.,}*
        if [ -e "${GIT_REPO_PATH}.git" ]; then echo "delete orphaned git-dir: ${GIT_REPO_PATH}.git"; rm -rf "${GIT_REPO_PATH}.git"; fi
      elif [ -d "${GIT_MOUNT}" ] && [ -d "${GIT_DIR}" ]; then
        local remote_origin_url=$(git -C "${GIT_MOUNT}" config remote.origin.url)
        if [ "$REPO_URL" != "$remote_origin_url" ]; then
          echo "delete old git data: ${GIT_MOUNT}"
          rm -rf "${GIT_MOUNT:?}"/{.,}*
          if [ -e "${GIT_REPO_PATH}.git" ]; then echo "delete orphaned git-dir: ${GIT_REPO_PATH}.git"; rm -rf "${GIT_REPO_PATH}.git"; fi
        fi
      fi

      # check accessibility
      local ACCESSIBLE

      local OBF_REPO_URL=$REPO_URL
      parse_url "${REPO_URL%/}/"

      local URL_STRICT="${PARSED_PROTO}${PARSED_HOST}${PARSED_PORT}"
      if [ -n "$PARSED_USER" ]; then
        local CURL_CREDENTIALS="--user ${PARSED_USER%@}"
        local OBF_CURL_CREDENTIALS="--user obfuscated"
        OBF_REPO_URL=${REPO_URL//$PARSED_USER/obfuscated@}
      fi
      # shellcheck disable=SC2086
      local HTTP_STATUS="$(curl ${CURL_CREDENTIALS} -s -o /dev/null -I -w "%{http_code}" --connect-timeout 1 "${URL_STRICT}")"
      if [[ "${HTTP_STATUS}" -eq '200' || "${HTTP_STATUS}" -eq '401' || "${HTTP_STATUS}" -eq '405' || "${HTTP_STATUS}" -eq '302' ]]; then
        ACCESSIBLE=true
      else
        ACCESSIBLE=false
        echo "command: curl ${OBF_CURL_CREDENTIALS} -s -o /dev/null -I -w %{http_code} --connect-timeout 1 ${URL_STRICT}"
        echo "resource ('${OBF_REPO_URL}' -> '${URL_STRICT}') is not accessible -> ${HTTP_STATUS}"
      fi

      # remove lock to repo since this should be an error
      if [ "${TYPE}" = "connect" ] && [ -f "${GIT_DIR}/index.lock" ]; then rm -f "${GIT_DIR}/index.lock"; fi

      if [ ! -d "${GIT_MOUNT}" ] || [ ! -d "${GIT_DIR}" ]; then
        if ! ${ACCESSIBLE}; then
          echo "${GIT_MOUNT} not exists -> ignore"
          done=true
          continue
        fi
        clone_git_repo "${GIT_REPO_PATH}" "${REPO_URL}" "${OBF_REPO_URL}" "$RESOURCE_NAME" "$SHALLOW_CLONE" "$REPO_BRANCH" "$SEPARATE_GIT_DIR"
      elif [ -e "${GIT_REPO_PATH}.error" ]; then
        echo "detect previous error: ${GIT_REPO_PATH}.error"
        if ${ACCESSIBLE}; then
          clone_git_repo_safe "${GIT_REPO_PATH}" "${REPO_URL}" "${OBF_REPO_URL}" "$RESOURCE_NAME" "$SHALLOW_CLONE" "$REPO_BRANCH" "$SEPARATE_GIT_DIR"
        fi
        # if error file still exists, go with the existing local repo
        if [ -e "${GIT_REPO_PATH}.error" ]; then
          if [ "${TYPE}" != "update" ] && [ -d "${GIT_MOUNT}" ]; then
            initial_create_symlinks_for_resources "${RESOURCE_NAME}" "GIT_${COUNT}" "${GIT_MOUNT}" "${HTTP_ACTIVE}" "${DAV_ACTIVE}" "${CACHE_ACTIVE}"
            rm -f "${GIT_REPO_PATH}.error"
          fi
          done=true
          continue
        fi
      elif [ "${SHALLOW_CLONE}" = "true" ]; then
        # clone repo for shallow branches when current branch is different from specified branch
        local current_branch=$(git -C "${GIT_MOUNT}" --no-pager branch)
        if [[ "$current_branch" != *"${REPO_BRANCH}" ]]; then
          echo "Branch: '${current_branch//\* }' (expect: '${REPO_BRANCH}')"
          clone_git_repo_safe "${GIT_REPO_PATH}" "${REPO_URL}" "${OBF_REPO_URL}" "$RESOURCE_NAME" "$SHALLOW_CLONE" "$REPO_BRANCH" "$SEPARATE_GIT_DIR"
        fi
      elif [ -f "${GIT_DIR}/index.lock" ]; then
        rm -f "${GIT_DIR}/index.lock"
      fi

      # branch handling
      local git_branch="${REPO_BRANCH}"

      if ${ACCESSIBLE}; then
        local git_checkout=$(git -C "${GIT_MOUNT}" checkout "${git_branch}" -f 2>&1)
        if [[ "${git_checkout}" != *"Already on"* ]]; then
          echo "${git_checkout}";
        fi

        git -C "${GIT_MOUNT}" clean -df
        git -C "${GIT_MOUNT}" reset --hard >/dev/null
      fi

      BLOCK_ACCESS=false
      CHECKOUT_REPO_AGAIN=false
      # on error clone repo again!! avoid counting COUNT to repeat all actions
      if ! git_output="$(git -C "${GIT_MOUNT}" pull 2>&1)"; then
        echo "git -C ${GIT_MOUNT} pull (failed)"
        echo "ERR: ${git_output}"
        if [[ "${git_output}" == *"The requested URL returned error: 503"* ]]; then
          echo "git repo is currently not accessible -> backup"
          ACCESSIBLE=false
        elif [[ "${git_output}" == *"Could not resolve host"* ]]; then
          echo "git repo is currently not accessible -> host could not be resolved"
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
        elif [[ "${git_output}" == "fatal:"* ]]; then
          if [[ "${git_output}" == *"index file smaller than expected"* ]]; then
            echo "local git repo has a serious problem"
            CHECKOUT_REPO_AGAIN=true
          else
            echo "local git repo is not accessible, block access"
            ACCESSIBLE=false
            BLOCK_ACCESS=true
          fi
        else
          CHECKOUT_REPO_AGAIN=true
        fi
      fi

      if $CHECKOUT_REPO_AGAIN; then
         echo "error resetting state, retrieve repo again"
         echo "touch ${GIT_REPO_PATH}.error"
         touch "${GIT_REPO_PATH}.error"
         done=false
         continue
      fi
      if ${ACCESSIBLE}; then
        # all works well / show subject of last commit
        local git_log=$(git -C "${GIT_MOUNT}" log -1 --pretty=format:'%s (%ar, %an)')
        echo "last_commit_log: ${git_log}"

        # set file times
        if pushd "$GIT_MOUNT" > /dev/null ; then
          local num=$(/usr/share/rsync/scripts/git-set-file-times | wc -l)
          if [ "$num" != "0" ]; then
            echo "set time for $num files -> /usr/share/rsync/scripts/git-set-file-times"
          fi
          popd > /dev/null || echo "ERR: popd from '$(pwd)'"
        fi
      fi

      if ! $BLOCK_ACCESS; then
        # update -> call from periodic_jobs
        if [ "${TYPE}" != "update" ]; then
          initial_create_symlinks_for_resources "${RESOURCE_NAME}" "GIT_${COUNT}" "${GIT_MOUNT}" "${HTTP_ACTIVE}" "${DAV_ACTIVE}" "${CACHE_ACTIVE}"
        fi
      elif [ "$STOP_ON_ERROR" = "true" ]; then
        echo "!!! STOP_ON_ERROR !!! -> $RESOURCE_NAME is not accessible"
        return 1
      fi
      done=true
    done
  done
}

function handle_local_paths() {
  for COUNT in $(env | grep -o "^LOCAL_[0-9]*_PATH" | awk -F '_' '{print $2}' | sort -nu); do
    local LOCAL_NAME="$(var_exp "LOCAL_${COUNT}_NAME")"
    local LOCAL_PATH="$(var_exp "LOCAL_${COUNT}_PATH")"
    local DAV_ACTIVE="$(var_exp "LOCAL_${COUNT}_DAV" "false")"
    local HTTP_ACTIVE="$(var_exp "LOCAL_${COUNT}_HTTP" "true")"
    local CACHE_ACTIVE="$(var_exp "LOCAL_${COUNT}_CACHE" "false")"
    local STOP_ON_ERROR="$(var_exp "LOCAL_${COUNT}_STOP_ON_ERROR" "false")"

    echo
    echo "$(date +'%T'): local: ${LOCAL_NAME}"

    if [ "$LOCAL_NAME" = "nil" ]; then
      echo "ERR (config): define LOCAL_${COUNT}_NAME"
      return 1
    fi

    if [ ! -d "${LOCAL_PATH}" ]; then
      echo "LOCAL_${COUNT}_PATH: ${LOCAL_PATH}: not exists -> ignore"
      if [ "$STOP_ON_ERROR" = "true" ]; then
        echo "!!! STOP_ON_ERROR !!! -> $LOCAL_NAME is not accessible"
        return 1
      fi
    else
      # no subdir supported so far, so "LOCAL_${COUNT}" always points to a non existing location
      initial_create_symlinks_for_resources "${LOCAL_NAME}" "LOCAL_${COUNT}" "${LOCAL_PATH}" "${HTTP_ACTIVE}" "${DAV_ACTIVE}" "${CACHE_ACTIVE}" "init"
    fi
  done
}

function handle_proxy() {
  for COUNT in $(env | grep -o "^PROXY_[0-9]*_URL" | awk -F '_' '{print $2}' | sort -nu); do
    local PROXY_NAME="$(var_exp "PROXY_${COUNT}_NAME")"
    local PROXY_URL="$(var_exp "PROXY_${COUNT}_URL")"
    local PROXY_CHECK="$(var_exp "PROXY_${COUNT}_CHECK" "$PROXY_URL")"
    local PROXY_CACHE="$(var_exp "PROXY_${COUNT}_CACHE_TIME")"
    local PROXY_MODE_DEFAULT="cache"
    local HTTP_ROOT_SHOW="$(var_exp "PROXY_${COUNT}_HTTP_ROOT_SHOW" "true")"
    local IP_RESTRICTION="$(var_exp "PROXY_${COUNT}_IP_RESTRICTION" "allow all")"
    local STOP_ON_ERROR="$(var_exp "LOCAL_${COUNT}_STOP_ON_ERROR" "false")"

    echo
    echo "$(date +'%T'): proxy: $PROXY_NAME"

    if [ "$PROXY_NAME" = "nil" ]; then
      echo "ERR (config): define PROXY_${COUNT}_NAME"
      return 1
    fi

    parse_url "${PROXY_URL%/}/"
    local STATUS
    if [ "${PARSED_HOST,,}" == "unix" ]; then
      PROXY_MODE_DEFAULT="direct"
      # PARSED_PATH = :/var/run/docker.sock:/ -> /var/run/docker.sock
      SOCKET_FILE=$(echo "$PARSED_PATH" | awk -F ':' '{print $2}')
      echo "unix socket: $SOCKET_FILE"
      STATUS='200'
      if ! socket_permission "$SOCKET_FILE"; then
        echo "unix socket is not accessible -> do not forget to bind the socket '$SOCKET_FILE' with write permissions"
        STATUS='404'
      fi
      local permissions=$(stat -c '%A %a %n' "$SOCKET_FILE")
      echo "permissions: $permissions"
    elif [ "$PROXY_CHECK" != "false" ]; then
      # check accessibility
      echo "check accessibility : curl -s -o /dev/null -I -w '%{http_code}' --connect-timeout 1 ${PROXY_CHECK}"
      #sleep 20s
      STATUS="$(curl -s -o /dev/null -I -w "%{http_code}" --connect-timeout 1 "${PROXY_CHECK}")"
    fi

    local PROXY_MODE="$(var_exp "PROXY_${COUNT}_MODE" "$PROXY_MODE_DEFAULT")"

    if [[ "${STATUS}" -eq '200' || "${STATUS}" -eq '302' || "${STATUS}" -eq '401' || "${STATUS}" -eq '405' ]]; then
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
      echo "resource is not accessible (ignore -> HTTP $STATUS): ${PROXY_URL}"
       if [ "$STOP_ON_ERROR" = "true" ]; then
         echo "!!! STOP_ON_ERROR !!! -> $PROXY_NAME is not accessible"
         return 1
       fi
    fi
  done
}
function start_light_http_server() {
    echo
    echo "$(date +'%T'): start light http server"
    doclig -action serve -listen-addr :80 &
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
    tail -f /tmp/php.log &
  fi

  echo "handle README.html (weave README.md and link to ${HTDOCS})"
  sed -i "/__INCLUDE_README__/r README.md" "/scripts/nginx-config/README.html"
  if [ -n "$RELEASE" ]; then
    sed -i "s|__RELEASE__|${RELEASE}|" "/scripts/nginx-config/README.html";
  fi

  # remove the __INCLUDE_README__ line
  sed -i "/__INCLUDE_README__/d" "/scripts/nginx-config/README.html"
  ln -fs "/scripts/nginx-config/README.html" "${HTDOCS}/README.html"

  if [ -e "/tmp/nginx_proxy_cache_active.check" ]; then
    echo "activate proxy cache"
    sed -i "s|#proxy_cache_path|proxy_cache_path|;" "/etc/nginx/nginx.conf"
  fi

  echo "service ${PHP_SERVICE} start"
  rm -rf /run/php
  service "${PHP_SERVICE}" "start"

  nginx -v

  if ! nginx; then
    cat /var/log/nginx/error.log
    exit 1
  fi
}
