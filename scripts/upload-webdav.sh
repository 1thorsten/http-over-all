#!/bin/bash

SERVER=$1
if [ -z "$SERVER" ]; then
 SERVER=localhost
fi

USER="1thorsten"
PASS="webdav"
CREDENTIALS="${USER}:${PASS}"

CURRENT_DIRECTORY=$(echo "$PWD" | awk -F '/' '{print $NF}')
BASE_DAV_PATH="http://${SERVER}:8338/dav/local/"

function create_webdav_directory {
    local DAV_PATH=$1
    local DELETE_FIRST=$2

    # first delete the directory 
    if [ "$DELETE_FIRST" = "true" ]; then
        RET=$(curl --user $CREDENTIALS -X DELETE "${DAV_PATH%/}"/ -sw '%{http_code}' |  grep -E "^[0-9]{3}")
        echo "webdav: delete ${DAV_PATH}: $RET"
    fi

    RET=$(curl --user $CREDENTIALS -X MKCOL "${DAV_PATH%/}"/ -sw '%{http_code}' |  grep -E "^[0-9]{3}")
    echo "webdav: create ${DAV_PATH}: $RET"

    if [ "$RET" == "409" ]; then
        echo "Error creating $DAV_PATH: $RET"
        exit 1
    fi
}

function upload_files {
    local DIRNAME=$1
    local DIR_PATH=$2
    local DAV_PATH="${BASE_DAV_PATH}/${DIRNAME}"

    create_webdav_directory "${DAV_PATH}/" "true"

    for file in $(ls -A "$DIR_PATH"); do
        if [ -f "${DIR_PATH}$file" ]; then
            RET=$(curl --user $CREDENTIALS -T "${DIR_PATH}""$file" "${DAV_PATH%/}"/ -sw '%{http_code}' |  grep -E "^[0-9]{3}")
            echo "webdav: uploading ${DIR_PATH}$file to ${DAV_PATH}: $RET"
        fi
    done
}

function download_hint {
    local DAV_PATH="${BASE_DAV_PATH}/${CURRENT_DIRECTORY}"
    echo "Download: " 
    # echo wget -q -N -r -l 100 --preserve-permissions -np -R 'index.html*' -nH --cut-dirs=4 --http-user=$USER --http-password=$PASS ${DAV_PATH}/
    echo "wget -S -N --http-user=$USER --http-password=$PASS ${DAV_PATH%/}/update-from-webdav.sh $SERVER ; . update-from-webdav.sh $SERVER"
}

create_webdav_directory "${BASE_DAV_PATH}/" "false"
upload_files "${CURRENT_DIRECTORY}" "./"
upload_files "${CURRENT_DIRECTORY}/incontainer" "./incontainer/"
upload_files "${CURRENT_DIRECTORY}/scripts" "./scripts/"

download_hint