all:
	@cat Makefile | grep : | grep -v PHONY | grep -v @ | sed 's/:/ /' | awk '{print $$1}' | sort

#-------------------------------------------------------------------------------

.PHONY: install-deps
install-deps:
	glide install && gometalinter.v2 --install

.PHONY: build
build:
	go build -ldflags="-s -w" -o bin/tfregistry main.go

.PHONY: package
package:
	env GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o bin/tfregistry main.go

.PHONY: lint
lint:
	gometalinter.v2 ./main.go
