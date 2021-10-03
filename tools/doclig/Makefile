update_dependencies:
	go get -u all

build:
	mkdir -p bin
	go build -ldflags="-s -w" -o bin/doclig ./src
	ls -alh bin/doclig

docker-build:
	mkdir -p bin
	GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o bin/doclig_lnx ./src
	docker-compose -f ../../docker-compose.yml build build-with-tools

format:
	gofmt -w -d -s src/*.go
