#!/usr/bin/env bash

# short name for http-over-all is sds (Software Distribution Server)
if [ ! -f "/tmp/sds.ready" ]; then exit 0; fi

curl -f http://localhost/ || exit 1