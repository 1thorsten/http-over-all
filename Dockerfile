FROM debian:buster-slim
ENV PHP_VERSION=7.3
LABEL maintainer="Thorsten Winkler"
LABEL description="http-over-all"

#FROM ubuntu:20.04
#ENV PHP_VERSION=7.4

# os part

# https://www.howtoforge.de/anleitung/wie-man-webdav-mit-lighttpd-auf-debian-etch-konfiguriert/

ARG DOCKER_CLI_VERSION="20.10.1"
ARG DOWNLOAD_URL="https://download.docker.com/linux/static/stable/x86_64/docker-$DOCKER_CLI_VERSION.tgz"

ENV WEBDAV=/var/www/dav
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Berlin

RUN set -x && \
    apt-get update -y && \
    apt-get dist-upgrade -y && \
    APT_SYSTEM="sudo tzdata ca-certificates lsof procps" && \
    APT_HTTP="nginx nginx-extras lua5.3 apache2-utils" && \
    APT_PHP="php-curl php-fpm php-mbstring" && \
    APT_SERVICES="openssl sshfs nfs-common davfs2 cifs-utils git" && \
    APT_TOOLS="iputils-ping wget curl rsync" && \
    APT_ETC="nano" && \
    apt-get install -y --no-install-recommends ${APT_SYSTEM} ${APT_HTTP} ${APT_PHP} ${APT_SERVICES} ${APT_TOOLS} ${APT_ETC} && \
    mkdir -p ${WEBDAV}/web && \
    chown www-data:www-data ${WEBDAV}/web && \
    rm -f /var/www/html/index.nginx-debian.html ; rm -f /etc/nginx/mime.types && \
    # docker-cli
    mkdir -p /tmp/download && \
    curl -L $DOWNLOAD_URL | tar -xz -C /tmp/download && \
    mv /tmp/download/docker/docker /usr/local/bin/ && \
    rm -rf /tmp/download && \
    # debian cleanup
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* ; rm -f /var/lib/dpkg/*-old && \
    echo "OS part successfully terminated" && \
    set +x

ENV PHP7_ETC=/etc/php/$PHP_VERSION
ENV PHP7_SERVICE=php${PHP_VERSION}-fpm
ENV PHP7_SOCK=/var/run/php/php${PHP_VERSION}-fpm.sock
ENV PHP_LOG_SYSOUT=true

# http-over-all part
ARG SSL_COUNTRY=DE
ARG SSL_STATE=Berlin
ARG SSL_LOCALITY=Berlin
ARG SSL_ORGANIZATION=http-over-all
ARG SSL_ORGANIZATIONALUNIT=IT
ARG SSL_EMAILADDRESS=noreply@no.com
ARG SSL_COMMONNAME=http-over-all

ENV HTDOCS=/var/www/html
ENV START_CMD="/bin/bash http-over-all.sh"
ENV DATA=/remote

VOLUME [ "/remote/git", "/local-data", "/nginx-cache" ]
ADD incontainer /scripts
WORKDIR /scripts

RUN set -x && \
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/nginx-selfsigned.key -out /etc/ssl/certs/nginx-selfsigned.crt -subj "/C=${SSL_COUNTRY}/ST=${SSL_STATE}/L=${SSL_LOCALITY}/O=${SSL_ORGANIZATION}/OU=${SSL_ORGANIZATIONALUNIT}/CN=${SSL_COMMONNAME}/emailAddress=${SSL_EMAILADDRESS}" && \
    # https://wiki.ubuntuusers.de/sudo/Konfiguration/
    # https://kofler.info/sudo-ohne-passwort/
    printf '\nwww-data  ALL=(ALL) NOPASSWD: /scripts/force-update.sh\n' >> /etc/sudoers && \
    find /scripts -name "*.sh" -exec sed -i 's/\r$//' {} + && \
    echo "http-over-all part successfully terminated" && \
    set +x

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 CMD [ "/scripts/healthcheck.sh" ]
ENTRYPOINT [ "./http-over-all.sh" ]
