mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
current_dir := $(dir $(mkfile_path))

#-------------------------------------------------------------------------------
# Global stuff.

# Determine which version of `$(ECHO)` to use. Use version from coreutils if available.
ECHOCHECK := $(shell command -v /usr/local/opt/coreutils/libexec/gnubin/$(ECHO) 2> /dev/null)
ifdef ECHOCHECK
    ECHO=/usr/local/opt/coreutils/libexec/gnubin/echo
else
    ECHO=echo
endif

GO=$(shell which go)

#-------------------------------------------------------------------------------
# Running `make` will show the list of subcommands that will run.

all: help

.PHONY: help
## help: [help]* Prints this help message.
help:
	@ $(ECHO) "Usage:"
	@ $(ECHO) ""
	@ sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' | sed -e 's/^/ /' | \
		while IFS= read -r line; do \
			if [[ "$$line" == *"]*"* ]]; then \
				$(ECHO) "\033[1;33m$$line\033[0m"; \
			else \
				$(ECHO) "$$line"; \
			fi; \
		done

#-------------------------------------------------------------------------------
# Build

.PHONY: build-prep
## build-prep: [build] Updates go.mod and downloads dependencies.
build-prep:
	mkdir -p ./bin
	$(GO) mod tidy -go=1.17 -v
	$(GO) mod download -x
	$(GO) get -v ./...

.PHONY: build-release-prep
## build-release-prep: [build] Post-development, ready to release steps.
build-release-prep:
	$(GO) mod download

.PHONY: build
## build: [build]* Compiles the source code into a native binary.
build: build-prep
	$(GO) build -ldflags="-s -w  -X main.commit=$$(git rev-parse HEAD) -X main.date=$$(date -I) -X main.version=$$(cat ./VERSION | tr -d '\n')" -o ./bin/tfregistry *.go

.PHONY: new-golang
## new-golang: [build] Installs a non-standard/future version of Golang.
new-golang:
	go get golang.org/dl/$(GO)
	$(GO) download

#-------------------------------------------------------------------------------
# Clean

.PHONY: clean-go
## clean-go: [clean] Clean Go's module cache.
clean-go:
	$(GO) clean -i -r -x -testcache -modcache -cache

.PHONY: clean-npm
## clean-npm: [clean] Removes the root `node_modules` directory.
clean-npm:
	- rm -Rf ./node_modules

.PHONY: clean
## clean: [clean]* Runs ALL cleaning tasks.
clean: clean-npm clean-go

#-------------------------------------------------------------------------------
# Linting

.PHONY: golint
## golint: [lint] Runs `golangci-lint` (static analysis, formatting) against all Golang (*.go) tests with a standardized set of rules.
golint:
	@ $(ECHO) " "
	@ $(ECHO) "=====> Running gofmt and golangci-lint..."
	gofmt -s -w *.go
	gofumpt -e -l -s *.go
	golangci-lint run --fix *.go

.PHONY: goupdate
## goupdate: [lint] Runs `go-mod-outdated` to check for out-of-date packages.
goupdate:
	@ $(ECHO) " "
	@ $(ECHO) "=====> Running go-mod-outdated..."
	go list -u -m -json all | go-mod-outdated -update -direct -style markdown

.PHONY: goconsistent
## goconsistent: [lint] Runs `go-consistent` to verify that implementation patterns are consistent throughout the project.
goconsistent:
	@ $(ECHO) " "
	@ $(ECHO) "=====> Running go-consistent..."
	go-consistent -v ./...

.PHONY: goimportorder
## goimportorder: [lint] Runs `go-consistent` to verify that implementation patterns are consistent throughout the project.
goimportorder:
	@ $(ECHO) " "
	@ $(ECHO) "=====> Running impi..."
	impi --local github.com/skyzyx/terraform-registry.alfredworkflow --ignore-generated=true --scheme=stdLocalThirdParty ./...

.PHONY: goconst
## goconst: [lint] Runs `goconst` to identify values that are re-used and could be constants.
goconst:
	@ $(ECHO) " "
	@ $(ECHO) "=====> Running goconst..."
	goconst -match-constant -numbers ./...

.PHONY: markdownlint
## markdownlint: [lint] Runs `markdownlint` (formatting, spelling) against all Markdown (*.md) documents with a standardized set of rules.
markdownlint:
	@ $(ECHO) " "
	@ $(ECHO) "=====> Running Markdownlint..."
	npx markdownlint-cli --fix '*.md' --ignore 'node_modules'

.PHONY: lint
## lint: [lint]* Runs ALL linting/validation tasks.
lint: markdownlint golint goupdate goconsistent goimportorder goconst

#-------------------------------------------------------------------------------
# Git Tasks

.PHONY: tag
## tag: [release] Tags (and GPG-signs) the release.
tag:
	@ if [ $$(git status -s -uall | wc -l) != 1 ]; then echo 'ERROR: Git workspace must be clean.'; exit 1; fi;

	@ $(ECHO) "This release will be tagged as: $$(cat ./VERSION)"
	@ $(ECHO) "This version should match your release. If it doesn't, re-run 'make version'."
	@ $(ECHO) "---------------------------------------------------------------------"
	@ read -p "Press any key to continue, or press Control+C to cancel. " x;

	@ $(ECHO) " "
	@ chag update $$(cat ./VERSION)
	@ $(ECHO) " "

	@ $(ECHO) "These are the contents of the CHANGELOG for this release. Are these correct?"
	@ $(ECHO) "---------------------------------------------------------------------"
	@ chag contents
	@ $(ECHO) "---------------------------------------------------------------------"
	@ $(ECHO) "Are these release notes correct? If not, cancel and update CHANGELOG.md."
	@ read -p "Press any key to continue, or press Control+C to cancel. " x;

	@ $(ECHO) " "

	git add .
	git commit -a -m "Preparing the $$(cat ./VERSION) release."
	chag tag --sign

.PHONY: version
## version: [release] Sets the version for the next release; pre-req for a release tag.
version:
	@ $(ECHO) "Current version: $$(cat ./VERSION)"
	@ read -p "Enter new version number: " nv; \
	printf "$$nv" > ./VERSION

.PHONY: release
## release: [release] Compiles the source code into binaries for all supported platforms and prepares release artifacts.
release:
	goreleaser release

.PHONY: package
## package: [release]* Compiles a local copy of the workflow without notarizing/releasing it.
package: build
	@ $(ECHO) " "
	@ $(ECHO) "=====> Ensure that we start with a clean directory, without errors..."
	mkdir -p terraform-registry
	rm -Rf terraform-registry
	mkdir -p terraform-registry

	@ $(ECHO) " "
	@ $(ECHO) "=====> Copy over the necessary files..."
	cp -rv bin terraform-registry/
	cp -rv images terraform-registry/
	cp -v *.plist terraform-registry/

	@ $(ECHO) " "
	@ $(ECHO) "=====> Package everything up..."
	cd terraform-registry/ && zip -r ../terraform-registry.zip *
	mv -v terraform-registry.zip terraform-registry.alfredworkflow
	# open terraform-registry.alfredworkflow
