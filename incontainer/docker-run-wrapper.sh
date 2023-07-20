#!/usr/bin/env bash

# SIGTERM-handler
# https://blog.codeship.com/trapping-signals-in-docker-containers/
function term_handler() {
  echo "$(date +'%T'): stop http server and unmount all filesystems / EXIT signal detected"
  for i in $(mount | awk '{print $3}' | grep "^/remote/"); do
    echo "sudo /usr/bin/umount --force $i"
    sudo /usr/bin/umount  --force "$i"
  done
  service nginx stop
  echo "$(date +'%T'): all terminated"
  exit 143 # 128 + 15 -- SIGTERM
}
trap "term_handler" EXIT

echo "sudo -E /scripts/http-over-all.sh"
sudo -E /scripts/http-over-all.sh
