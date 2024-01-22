# HTTP over all
Http-over-all is a unified interface for accessing various resources (nfs, smb, ssh, http/dav, git, docker) through a http endpoint.
It integrates a proxy that always delivers the latest content and  enables access restriction on different layers.
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
  - windows clients
    - to secure your content with basic authentication you should enable it ([EN](https://www.webdavsystem.com/server/prev/v2/documentation/authentication/basic_auth_vista/), [DE](https://www.windowspage.de/tipps/022703.html))
    - remove download size limit ([EN](https://blogs.objectsharp.com/post/2011/01/27/SharePoint-2010-and-Error-0x800700DF-The-file-size-exceeds-the-limit-allowed-and-cannot-be-saved.aspx#:~:text=When%20you%20upload%20a%20large,and%20cannot%20be%20saved%22%20message.&text=By%20default%2C%20Web%20Client%20file,Windows%20Registry%20using%20regedit%20command), [DE](https://www.strato.de/faq/cloud-speicher/so-erhoehen-sie-die-maximale-dateigroesze-fuer-downloads-bei-webdav-nutzung-unter-windows/))
    - network folder:
      ```bash
      browser: 192.168.1.1:8338/dav/smb_share
      folder:  \\192.168.1.1@8338\DavWWWRoot\dav\smb_share
      ```
- protecting access with basic-auth on demand
- restrict the access to your connecting resource by
  - endpoint definiton: user@xx.xx.xx:/root/.jenkins/
  - allowing only specified files (permitted resources)
  - sharing only subdirectories
- act as caching proxy for all requests against the http-endpoint (not WEBDAV)
  - only the newest version will be delivered.
- provide restricted access to secured resources with a crypted key mechanism
- provide a local space on demand

## Security
To access the various resources, http-over-all requires passwords in clear text.  
To add an extra layer of security, it is possible to encrypt the values of the ENV variables.

Be aware that encryption can be a false friend, and if someone has access to your key (CRYPT_KEY), that person could easily decrypt the value.
Therefore, it is important that you separate the key from the encrypted values.  
You can do this by defining the CRYPT_KEY in a different configuration file (for example, crypt_key.env) instead of in the main configuration file (for example, example.env).

- generate a new crypt key (CRYPT_KEY)
  ```bash
  docker run --rm php:cli-alpine php -r 'echo "CRYPT_KEY:".base64_encode(openssl_random_pseudo_bytes(32))."\n";'
  ```  
- encrypt a value  
  substitute the plain text with the encrypted one
  ```bash
  docker exec -ti http-over-all bash -ic "encrypt value2encrypt"
  ```

## SMB
### Options
| ENV-Variable      | Description               | required |
|-------------------|---------------------------|----------|
| SMB_[COUNT]_USER  | -                         | x        | 
| SMB_[COUNT]_PASS  | -                         | x        | 
| SMB_[COUNT]_SHARE | e.g. //10.23.4.161/data   | x        | 
| SMB_[COUNT]_OPTS  | e.g. vers=3.0,noserverino | -        |

General Options: yes

## SSH
### Options

| ENV-Variable      | Description             | required |
|-------------------|-------------------------|----------|
| SSH_[COUNT]_PASS  | -                       | x        | 
| SSH_[COUNT]_SHARE | e.g. rute@10.23.4.161:/ | x        | 
| SSH_[COUNT]_PORT  | default: 22             | -        | 

General Options: yes

## DAV
### Options

| ENV-Variable      | Description             | required |
|-------------------|-------------------------|----------|
| DAV_[COUNT]_USER  | -                       | x        | 
| DAV_[COUNT]_PASS  | -                       | x        | 
| DAV_[COUNT]_SHARE | e.g. http://x.x.x.x/dav | x        | 

General Options: yes

## GIT
### Options
CACHE is set to false, because the resources are lying on the local drive.

| ENV-Variable            | Description                                                      | required |
|-------------------------|------------------------------------------------------------------|----------|
| GIT_[COUNT]_REPO_URL    | e.g. https://[user]:[pass]@bitbucket.company.de/scm/sof/repo.git | x        | 
| GIT_[COUNT]_REPO_BRANCH | branch name (default: master)                                    | -        |

General Options: yes

## DOCKER

### Options

CACHE is set to false, because the resources are on the local drive.

You have to mount the docker.socket into the container (/var/run/docker.sock:/var/run/docker.sock:ro is sufficient).

The docker image should be better a pure data image.
For METHOD 'TAR' the base image has to be a Linux OS. Entrypoint and Cmd will be overwritten. It is important to know
that a shell is executed, the defaults (.bashrc) as well.
METHOD 'COPY' uses docker cp, so no operating system is required (should be faster that TAR). EXCL is applied after the
content is copied.

| ENV-Variable               | Description                                                        | required |
|----------------------------|--------------------------------------------------------------------|----------|
| DOCKER_[COUNT]_IMAGE       | e.g. ubuntu                                                        | x        |
| DOCKER_[COUNT]_TAG         | tag (default: latest)                                              | -        |
| DOCKER_[COUNT]_USER        | if access to registry requires authentication                      | -        |
| DOCKER_[COUNT]_PASS        | if access to registry requires authentication                      | -        |
| DOCKER_[COUNT]_METHOD      | method for synchronizing data (COPY)                               | x        |
| DOCKER_[COUNT]_DIGEST_PATH | path for persisting digest information (sha256-key of the image)   | -        |
| DOCKER_[COUNT]_EXCL        | paths to exclude (e.g. proc/* dev/* sys/*)                         | -        |
| DOCKER_[COUNT]_SRC_DIRS    | dirs to extract from the container (default: DOCKER-VAR WORKSPACE) | -        |

General Options: yes
## PROXY
### Options

Proxy is allowed for http endpoints
and [unix sockets](http://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass) as well.
The file permissions for the socket are very important. Read and write access on PROXY_[COUNT]_SOCKET_FILE will be set
automatically (if possible).
Do not forget to mount the socket with write permissions (/var/run/docker.sock:/var/run/docker.sock:ro is not
sufficient)
Proxy (mode: direct) supports websockets.

| ENV-Variable                 | Description                                                                                      | required |
|------------------------------|--------------------------------------------------------------------------------------------------|----------|
| PROXY_[COUNT]_NAME           | resource name (shown in root dir)                                                                | x        | 
| PROXY_[COUNT]_URL            | e.g http:/x.x.x.x/resource/ or http://unix:/var/run/docker.sock:/                                | x        | 
| PROXY_[COUNT]_AUTH           | user:password (basic auth)                                                                       | -        |
| PROXY_[COUNT]_CACHE_TIME     | cache content, and how to cache - e.g. 1d (one day)                                              | -        |
| PROXY_[COUNT]_HTTP_ROOT_SHOW | show the content in the root directory (default: true)                                           | -        | 
| PROXY_[COUNT]_IP_RESTRICTION | [ip restriction](http://nginx.org/en/docs/http/ngx_http_access_module.html) (default: allow all) | -        | 
| PROXY_[COUNT]_LOG_ACCESS     | access_log -> file, device (/dev/stdout) off (default: off)                                      | -        | 
| PROXY_[COUNT]_LOG_ERROR      | error_log -> file, device (/dev/stdout) off (default: /dev/stdout)                               | -        | 
| PROXY_[COUNT]_MODE           | cache (default for non unix-sockets) or direct (default for unix-sockets)                        | -        | 

General Options: no

## NFS
### Options
On the server that provides the nfs share you have to edit the /etc/exports accordingly.
```
/etc/exports:
/mnt/data/downloads 10.40.4.33(async,no_subtree_check,rw,all_squash,anonuid=1000,anongid=1000)
```
Reload the configuration afterwards:
```bash
exportfs -rs
```

| ENV-Variable      | Description            | required |
|-------------------|------------------------|----------|
| NFS_[COUNT]_SHARE | e.g. 10.23.4.161:/home | x        | 

General Options: yes

## LOCAL (local file access)
### Options
CACHE is set to false, because the resources are on the local drive.

| ENV-Variable       | Description | required |
|--------------------|-------------|----------|
| LOCAL_[COUNT]_PATH | /local-data | x        |

General Options: yes

## General resource options
Options for all resources

[RES] stands for Resource_[COUNT]_ (e.g. LOCAL_[COUNT])

| ENV-Variable                          | Description                                                                                      | required |
|---------------------------------------|--------------------------------------------------------------------------------------------------|----------|
| [RES]_NAME                            | resource name (shown in root dir)                                                                | x        |
| [RES]_CACHE                           | cache resources through proxy cache / true/false (default: true)                                 | -        |
| [RES]_DAV                             | true/false (default: false)                                                                      | -        |
| [RES]_DAV_METHODS                     | standard DAV methods (default: PUT DELETE MKCOL COPY MOVE)                                       | -        |
| [RES]_DAV_AUTH                        | user:password (basic auth)                                                                       | -        |
| [RES]_DAV_IP_RESTRICTION              | [ip restriction](http://nginx.org/en/docs/http/ngx_http_access_module.html) (default: allow all) | -        |
| [RES]_DAV_LOG_ACCESS                  | access_log -> file, device (/dev/stdout) off (default: off)                                      | -        | 
| [RES]_DAV_LOG_ERROR                   | error_log -> file, device (/dev/stdout) off (default: /dev/stdout)                               | -        |
| [RES]_HTTP                            | true/false (default: true)                                                                       | -        |
| [RES]_HTTP_AUTH                       | user:password (basic auth)                                                                       | -        |
| [RES]_HTTP_IP_RESTRICTION             | [ip restriction](http://nginx.org/en/docs/http/ngx_http_access_module.html) (default: allow all) | -        |
| [RES]_HTTP_LOG_ACCESS                 | access_log -> file, device (/dev/stdout) off (default: off)                                      | -        | 
| [RES]_HTTP_LOG_ERROR                  | error_log -> file, device (/dev/stdout) off (default: /dev/stdout)                               | -        |
| [RES]_PERMITTED_RESOURCES             | absolute path of permitted resource file                                                         | -        |
| [RES]_SUB_DIR_PATH_1++                | restrict acccess to this path (relative)                                                         | -        |
| [RES]_SUB_DIR_NAME_1++                | accessible name                                                                                  | -        |
| [RES]_SUB_DIR_PERMITTED_RESOURCES_1++ | absolute path of permitted resource file                                                         | -        |

## Common options

| ENV-Variable          | Description                                                                                                                                                                            | required |
|-----------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------|
| CONNECTED_URLS        | use in connected configuration, force-update via HTTP calls the URLs in parallel (e.g. https://ipaddres-other-nodeX:4334/force-update, https://ipaddres-other-nodeY:4334/force-update) | -        |
| CRYPT_KEY             | key for encrypting and decrypting                                                                                                                                                      | x        |
| HTTP_SERVER_START     | start nginx server (default: true)                                                                                                                                                     | -        |
| PERIODIC_JOB_INTERVAL | interval for processing periodic jobs (default: 5m). Infinity = inf                                                                                                                    | -        |
| PROXY_MAX_SIZE        | maximum size of the proxy cache (default: 10g)                                                                                                                                         | -        |
| PROXY_INACTIVE        | data that are not accessed during the time get removed (default: 1d)                                                                                                                   | -        |
| TINY_INSTANCE         | configure for low requirements and low memory consumption (default: false)                                                                                                             | -        |
| FORCE_UPDATE_LOCK     | timeout in seconds for repetitive call (default: 16)                                                                                                                                   | -        |
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

It is also possible to highlight specific lines -> ?view&l=1,5-10

## encrypt resources
URL (relative): /resource/folder1/folder2/file.suffix?share

To trigger the encryption you have only to add ?share to the URL. The URL to the resource will be encrypted (Decrypt URL will be shown). The link is valid as long as the CRYPT_KEY does not change. It is also valid accross different servers as long as the CRYPT_KEY is the same, and the resource on the server is also the same.
To be sure which file is behind the key, the url always ends with the file name (e.g. start.ini).

encrypted URL: /decrypt/bMXKoBXXX_zQkDKG5fAXtwvdov20A4clKimP8YsdAvbVweqcgfdrUxUsRlPdymEfGLINZD_y-c0/start.ini

Why do I should use this encryption mechanism:

- it makes unavailable resources available. With the encrypted URL you bypass the access restrictions (Authentification and ipaddress restriction)
- it restricts access to this one resource. Everything else remains secure.

Generate your own CRYPT_KEY:
```bash
docker run --rm php:cli-alpine php -r 'echo "CRYPT_KEY:".base64_encode(openssl_random_pseudo_bytes(32))."\n";'
```
# <a name="additions"></a>Additions
## func/encrypt-msg
encrypt the given message depending on the requesting host.
Only the requesting host is able to decrypt the encrypted message.

```bash
curl 'http://[http-over-all:8338]/func/encrypt-msg?m=message2encrypt'
curl -X POST -H "Content-Type: text/plain" --data "this is the message" http://[http-over-all:8338]/func/encrypt-msg
```

Options:

*h* (optional): create an encrypted message that can be decrypted  

- by the specified host (?h=10.30.1.43)
- by all hosts (?h=*)
- by multiple hosts (! for excluding)
  - ?h=10.30.1.43,10.30.2.32
  - ?h=10.30.1.10-10.30.2.9,!10.30.1.12

*v* (optional): set a maximum validity (?v=now +10 min)

```bash
curl 'http://[http-over-all:8338]/func/encrypt-msg?h=192.168.15.14&m=message2encrypt&v=now +10 min'
curl -X POST -H "Content-Type: text/plain" --data "this is the message" 'http://[http-over-all:8338]/func/encrypt-msg?h=192.168.15.14&m=message2encrypt&v=now +10 min'
```

## func/decrypt-msg

decrypt the given message.
Only the requesting host is able to decrypt the encrypted message.

```bash
curl 'http://[http-over-all:8338]/func/decrypt-msg?m=encryptedMessage'
curl -X POST -H "Content-Type: text/plain" --data 'encryptedMessage' 'http://[http-over-all:8338]/func/decrypt-msg'

```

## func/remote-ip

Show ip address from the requestor.
Sometimes you need to know your real internal ip address (e.g. if you are in a container with its own virtual network)

```bash
curl http://[http-over-all:8338]/func/remote-ip
```

## func/show-headers

Show all headers from the requestor request.

```bash
curl http://[http-over-all:8338]/func/show-headers
```
