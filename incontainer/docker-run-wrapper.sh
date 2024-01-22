#!/usr/bin/env bash

# SIGTERM-handler
# https://blog.codeship.com/trapping-signals-in-docker-containers/
function term_handler() {
  echo "$(date +'%T'): (term_handler) EXIT signal detected"
  echo "sudo -E /scripts/shutdown-services.sh"
  sudo -E /scripts/shutdown-services.sh

  echo "$(date +'%T'): (term_handler) shutdown complete"
  exit 143 # 128 + 15 -- SIGTERM
}
trap "term_handler" EXIT

echo "sudo -E /scripts/http-over-all.sh"
sudo -E /scripts/http-over-all.sh
