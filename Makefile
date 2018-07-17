all:
	@cat Makefile | grep : | grep -v PHONY | grep -v @ | sed 's/:/ /' | awk '{print $$1}' | sort

#-------------------------------------------------------------------------------

.PHONY: install-deps
install-deps:
	glide install && gometalinter.v2 --install

.PHONY: build
build:
	go build -ldflags="-s -w" -o bin/tfregistry main.go

.PHONY: lint
lint:
	gometalinter.v2 ./main.go

.PHONY: package
package:
	upx --brute bin/tfregistry
	mkdir -p terraform-registry
	rm -Rf terraform-registry
	mkdir -p terraform-registry
	cp -rv bin terraform-registry/
	cp -rv images terraform-registry/
	cp -v *.png terraform-registry/
	cp -v *.plist terraform-registry/
	zip -r terraform-registry.zip terraform-registry/
	mv -v terraform-registry.zip terraform-registry.alfredworkflow
