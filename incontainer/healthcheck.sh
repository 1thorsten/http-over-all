#!/usr/bin/env bash

# short name for http-over-all is sds (Software Distribution Server)
if [ ! -f "/var/run/sds.ready" ]; then exit 0; fi

curl -A "curl/healthcheck" -f http://localhost/ || exit 1
