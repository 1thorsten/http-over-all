update_dependencies:
	go get -u all

build:
	mkdir -p bin
	go build -ldflags="-s -w" -o bin/doclig ./src
	ls -alh bin/doclig

format:
	gofmt -w -d -s src/*.go
