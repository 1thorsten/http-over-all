# HTTP over all
A unified interface for accessing various resources (nfs, smb, ssh, http/dav, git, docker) through a http endpoint.
Integrates a proxy that always delivers the latest content.
Enables access restriction on different layers.
- http: basic auth, ip address
- resources: acl per resource

[Special Functions](#special-functions)

[Additions](#additions)

**Supported protocols (according the order of connecting):**

- NFS
- SMB (up to version 3)
- SSH
- DAV
- GIT
- DOCKER
- PROXY
- LOCAL (local file access)

## Features
- support WEBDAV for the provided resources and allow the following methods DELETE MKCOL COPY MOVE PROPFIND OPTIONS
  - Allow changing files where it is possible and desired
- protecting access with basic-auth on demand
- restrict the access to your connecting resource by
  - endpoint definiton: user@xx.xx.xx:/root/.jenkins/
  - allowing only specified files (permitted resources)
  - shareing only subdirectories
- act as caching proxy for all requests against the http-endpoint (not WEBDAV)
  - only the newest version will be delivered.
- provide restricted access to secured resources with a crypted key mechanism
- provide a local space on demand

# Protocols
## SMB
### Options

| ENV-Variable | Description | required |
| -------------| ------------| ---------|
| SMB_[COUNT]_USER | - | x | 
| SMB_[COUNT]_PASS | - | x | 
| SMB_[COUNT]_SHARE | e.g. //10.23.4.161/data | x | 
| SMB_[COUNT]_OPTS | e.g. vers=3.0 | - |

General Options: yes

## SSH
### Options
| ENV-Variable | Description | required |
| -------------| ------------| ---------|
| SSH_[COUNT]_PASS | - | x | 
| SSH_[COUNT]_SHARE | e.g. rute@10.23.4.161:/ | x | 

General Options: yes

## DAV
### Options
| ENV-Variable | Description | required |
| -------------| ------------| ---------|
| DAV_[COUNT]_USER | - | x | 
| DAV_[COUNT]_PASS | - | x | 
| DAV_[COUNT]_SHARE | e.g. http://x.x.x.x/dav | x | 

General Options: yes

## GIT
### Options
CACHE is set to false, because the resources are lying on the local drive.

| ENV-Variable | Description | required |
| -------------| ------------| ---------|
| GIT_[COUNT]_REPO_URL | e.g. https://[user]:[pass]@bitbucket.company.de/scm/sof/repo.git | x | 
| GIT_[COUNT]_REPO_BRANCH | branch name (default: master) | - |

General Options: yes

## DOCKER
### Options
CACHE is set to false, because the resources are on the local drive.

The docker image should be better a pure data image. Entrypoint and Cmd are overwritten. If the METHOD 'TAR' is chosen, it is also important to know that a shell is executed and the defaults (.bashrc) are executed.
The base image should be a Linux image, because of the method used to synchronize data between containers.

| ENV-Variable | Description | required |
| -------------| ------------| ---------|
| DOCKER_[COUNT]_IMAGE | e.g. ubuntu | x |
| DOCKER_[COUNT]_LOGIN | e.g. docker login url.your-repo.de -u user -p password | - |
| DOCKER_[COUNT]_TAG | tag (default: latest) | - |
| DOCKER_[COUNT]_METHOD | method   for synchronizing data (default: TAR) | - |
| DOCKER_[COUNT]_SRC_DIRS | dirs to extract from the container (default: DOCKER-VAR WORKSPACE) | - |
| DOCKER_[COUNT]_EXCL | paths to exclude (e.g. proc/* dev/* sys/*) | - |

General Options: yes
## PROXY
### Options
| ENV-Variable | Description | required |
| -------------| ------------| ---------|
| PROXY_[COUNT]_URL | e.g http:/x.x.x.x/resource/ | x | 
| PROXY_[COUNT]_CACHE | cache content, and how to cache - e.g. 1d (one day) | - | 
| PROXY_[COUNT]_HTTP_ROOT_SHOW | show the content in the root directory (default: true) | - | 
| PROXY_[COUNT]_HTTP_IP_RESTRICTION | ip restriction (default: allow all;) | - | 

General Options: no

## NFS
### Options

| ENV-Variable | Description | required |
| -------------| ------------| ---------|
| NFS_[COUNT]_SHARE | e.g. 10.23.4.161:/home | x | 

General Options: yes

## LOCAL (local file access)
### Options
CACHE is set to false, because the resources are on the local drive.

| ENV-Variable | Description | required |
| -------------| ------------| ---------|
| LOCAL_[COUNT]_PATH | /local-data | x |

General Options: yes

## General resource options
Options for all resources
[RES] stands for Resource_[COUNT]_ (e.g. LOCAL_[COUNT])

| ENV-Variable | Description | required |
| -------------| ------------| ---------|
| [RES]_NAME | resource name (shown in root dir) | x |
| [RES]_CACHE | cache resources through proxy cache / true/false (default: true) | - |
| [RES]_DAV | true/false (default: false) | - |
| [RES]_DAV_METHODS | standard DAV methods (e.g. PUT DELETE MKCOL COPY MOVE) | - |
| [RES]_DAV_AUTH | user:password (basic auth) | - |
| [RES]_DAV_IP_RESTRICTION | ip restriction (default: allow all;) | - |
| [RES]_HTTP | true/false (default: true) | - |
| [RES]_HTTP_AUTH | user:password (basic auth) | - |
| [RES]_HTTP_IP_RESTRICTION | ip restriction (default: allow all;) | - |
| [RES]_PERMITTED_RESOURCES | absolute path of permitted resource file | - |
| [RES]_SUB_DIR_PATH_1++ | restrict acccess to this path (relative) | - |
| [RES]_SUB_DIR_NAME_1++ | accessible name | - |
| [RES]_SUB_DIR_PERMITTED_RESOURCES_1++ | absolute path of permitted resource file | - |

## Common options

| ENV-Variable | Description | required |
| -------------| ------------| ---------|
| CRYPT_KEY | key for encrypting and decrypting | x |
| PERIODIC_JOB_INTERVAL | interval in minutes for processing periodic jobs (default: 5) | - |
| PROXY_MAX_SIZE | maximum size of the proxy cache (default: 10g) | - |
| PROXY_INACTIVE | data that are not accessed during the time get removed (default: 1d) | - |

# <a name="special-functions"></a>Special functions
## periodic jobs
ENV: PERIODIC_JOB_INTERVAL

http-over-all has a simple periodic update mechanism which addresses
- git (it makes a git pull)
- restricted resources (reads the configuration files and adjust the resources accordingly)

## force update (update content)
URL (relative): /force-update

This triggers the update mechanism described above. It is guaranteed that the update mechanism can not call in parallel.

## highlight resources
URL (relative): /resource/folder1/folder2/file.suffix?view

The content will be shown highlighted and with line numbers. Thanks to Prism.js.

## encrypt resources
URL (relative): /resource/folder1/folder2/file.suffix?share

To trigger the encryption you have only to add ?share to the URL. The URL to the resource will be encrypted. The decrypt URL will be shown. The link is valid as long as the CRYPT_KEY does not change. It is also valid accross different servers as long as the CRYPT_KEY is the same and the resource on the server is also the same.
To be sure which file is behind the key, the url always ends with the file name (e.g. start.ini).

encrypted URL: /decrypt/bMXKoBXXX_zQkDKG5fAXtwvdov20A4clKimP8YsdAvbVweqcgfdrUxUsRlPdymEfGLINZD_y-c0/start.ini

Why do I should use this encryption mechanism:

- it makes unavailable resources available. With the encrypted URL you bypasses the access restrictions (Authentification and ipaddress restriction)
- it restricts access to this one resource. Everything else remains secure.

Generate your own CRYPT_KEY:
```bash
docker run --rm php:cli-alpine php -r 'echo "CRYPT_KEY:".base64_encode(openssl_random_pseudo_bytes(32))."\n";'
```
# <a name="additions"></a>Additions
## func/remote-ip
Show ip address from the requestor.
Sometime you need to know your real internal ip address (e.g. if you are in a container with its own virtual network)

```bash
curl http://[http-over-all:8338]/func/remote-ip
```


