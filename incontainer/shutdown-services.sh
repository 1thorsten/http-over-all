#!/usr/bin/env bash

function shutdown {
    local SDS_READY="/var/run/sds.ready"
    local SDS_NO_HTTP="/var/run/sds.no_http"
    local IS_NO_HTTP=false

    local files_to_remove=$SDS_READY
    if [ -f "$SDS_NO_HTTP" ]; then
      files_to_remove="$files_to_remove $SDS_NO_HTTP"
      IS_NO_HTTP=true
    fi

    echo "$(date +'%T'): (shutdown) clean up and unmount all filesystems"
    echo rm -f "$files_to_remove"
    rm -f "$files_to_remove"

    for i in "${DATA}"/*; do
      echo rm -f "$i/sds.ready"
      rm -f "$i/sds.ready"
    done

    for i in $(mount | grep -v "type ext4 " | awk '{print $3}' | grep "^/remote/"); do
      echo "/usr/bin/umount --force $i"
      /usr/bin/umount  --force "$i"
    done

    if [ "$IS_NO_HTTP" = false ]; then
      echo "$(date +'%T'): (shutdown) stop http server"
      service nginx stop
    fi
}

shutdown
