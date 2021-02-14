#!/usr/bin/env bash

export NGINX_CONF=/etc/nginx/http-over-all

# encrypt given argument and return string for usage in configuration (key = CRYPT_KEY)
# VAR = "texttoencrypt"
# @return "{crypt:${ENCRYPTED}}"
function encrypt {
  local VAR="${1}"
  if [ -z "$VAR" ]; then echo "no argument given" && exit 1; fi
  ENCRYPTED=$(php -r "include 'UnsafeCrypto.php'; echo UnsafeCrypto::encrypt('$VAR', true);")
  echo "{crypt:${ENCRYPTED}}"
}

function generate_crypt_key() {
    local CRYPT_KEY=$(php -r "echo base64_encode(openssl_random_pseudo_bytes(32));")
    echo "${CRYPT_KEY}"
}

# export env variables from file (overwrite existing ones)
function evaluate_external_env {
  local EXT_ENV="${1}"
  if [ -f "${EXT_ENV}" ]; then
    echo "evaluate $EXT_ENV"
    while IFS='' read -r line || [[ -n "$line" ]]; do
      if [[ "$line" != "" ]]; then
          # ignore comments
          if [[ $line == "#"* ]]; then continue; fi
          local IN="$(echo "${line}" | tr -d '\r' | tr -d '\n')"
          # shellcheck disable=SC2034
          IFS='=' read -r key value <<< "$IN"
          echo "-> export $key=$value"
          export "$key"="$value"
      fi
    done < "$EXT_ENV"
  fi
}
