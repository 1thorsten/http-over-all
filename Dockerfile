#FROM debian:bullseye-slim
#ENV PHP_VERSION=7.4

FROM debian:buster-slim
ENV PHP_VERSION=7.3
LABEL maintainer="Thorsten Winkler"
LABEL description="http-over-all"

# os part
ARG DOCKER_CLI_VERSION="20.10.3"
ARG DOWNLOAD_URL="https://download.docker.com/linux/static/stable/x86_64/docker-$DOCKER_CLI_VERSION.tgz"

ENV WEBDAV=/var/www/dav
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Berlin

RUN set -x && \
    apt-get update -y && \
    apt-get dist-upgrade -y && \
    APT_SYSTEM="sudo tzdata ca-certificates" && \
    APT_HTTP="nginx nginx-extras lua5.3" && \
    APT_PHP="php-curl php-fpm php-mbstring" && \
    APT_SERVICES="openssl sshfs nfs-common davfs2 cifs-utils git" && \
    APT_TOOLS="iputils-ping curl rsync" && \
    APT_ETC="nano" && \
    apt-get install -y --no-install-recommends ${APT_SYSTEM} ${APT_HTTP} ${APT_PHP} ${APT_SERVICES} ${APT_TOOLS} ${APT_ETC} && \
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
ARG RELEASE="1.0.7"

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
    echo "\nexport RELEASE=${RELEASE}\n" >> /scripts/system-helper.sh && \
    echo "source /scripts/system-helper.sh" >> /etc/bash.bashrc && \
    echo "http-over-all part successfully terminated" && \
    set +x

HEALTHCHECK --interval=1m --timeout=30s --start-period=5s --retries=3 CMD [ "/scripts/healthcheck.sh" ]
ENTRYPOINT [ "./http-over-all.sh" ]
