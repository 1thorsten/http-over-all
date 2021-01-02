# HTTP over all
A unified interface for accessing various resources (nfs, smb, ssh, http/dav, git, docker) through a http endpoint.
Integrates a proxy that always delivers the latest content.
Enables access restriction on different layers.
- http: basic auth, ip address
- resources: acl per resource

# Installation / Running
1. Pull the latest image
```
docker-compose pull 
```
2. Generate a personal cipher for encrypting resources
```
docker run --rm php:cli-alpine php -r 'echo "CRYPT_KEY:".base64_encode(openssl_random_pseudo_bytes(32))."\n";'
```
3. Create a configuration (or edit example.env) 
```
nano example.env
```
4. Finally, start the container
```
docker-compose up -d
```

# Building
```
docker build -t 1thorsten/http-over-all .
```

# Accessing
- http
http://localhost:8338/
- https (http2)
https://localhost:4334/
