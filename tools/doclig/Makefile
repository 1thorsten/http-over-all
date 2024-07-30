update_dependencies:
	/usr/local/opt/go/libexec/bin/go get -u -t ./...

build:
	mkdir -p bin
	/usr/local/opt/go/libexec/bin/go build -ldflags="-s -w" -o bin/doclig ./src
	ls -al bin/doclig

format:
	gofmt -w -d -s src/*.go

doclig-build:
	mkdir -p bin
	GOOS=linux GOARCH=amd64 /usr/local/opt/go/libexec/bin/go build -ldflags="-s -w" -o bin/doclig_lnx ./src
	env DOCKER_BUILDKIT=0 docker compose -f docker-compose-doclig.yml build build-with-tools

doclig-up:
	docker compose -f docker-compose-doclig.yml up hoa-doclig

doclig-down:
	docker compose -f docker-compose-doclig.yml down

docker-compose-build:
	env DOCKER_BUILDKIT=0 docker compose -f ../../docker-compose.yml build

docker-compose-up:
	docker compose -f ../../docker-compose.yml up http-over-all

docker-compose-down:
	docker compose -f ../../docker-compose.yml down

docker-compose-exec-bash:
	docker exec -ti http-over-all bash
