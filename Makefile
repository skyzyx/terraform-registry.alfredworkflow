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

#-------------------------------------------------------------------------------

.PHONY: tag
tag:
	@ if [ $$(git status -s -uall | wc -l) != 0 ]; then echo 'ERROR: Git workspace must be clean.'; exit 1; fi;

	@echo "This release will be tagged as: $$(cat ./VERSION)"
	@echo "This version should match your release. If it doesn't, re-run 'make version'."
	@echo "---------------------------------------------------------------------"
	@read -p "Press any key to continue, or press Control+C to cancel. " x;

	@echo " "
	@chag update $$(cat ./VERSION)
	@echo " "

	@echo "These are the contents of the CHANGELOG for this release. Are these correct?"
	@echo "---------------------------------------------------------------------"
	@chag contents
	@echo "---------------------------------------------------------------------"
	@echo "Are these release notes correct? If not, cancel and update CHANGELOG.md."
	@read -p "Press any key to continue, or press Control+C to cancel. " x;

	@echo " "

	git add .
	git commit -a -m "Preparing the $$(cat ./VERSION) release."
	chag tag --sign

#-------------------------------------------------------------------------------

.PHONY: version
version:
	@echo "Current version: $$(cat ./VERSION)"
	@read -p "Enter new version number: " nv; \
	printf "$$nv" > ./VERSION
