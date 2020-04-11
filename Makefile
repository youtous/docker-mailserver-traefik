#!make
.PHONY: test build-test clean help
.DEFAULT_GOAL= help

build-test: ## Build the test image
	docker build . -t 'mailserver-traefik:test-image'

tests: build-test ## Run all the tests.
	./test/libs/bats/bin/bats test/*.bats
	make clean

clean: ## Remove docker images built.
	docker rmi mailserver-traefik:test-image

# see https://suva.sh/posts/well-documented-makefiles/
help: ## Show this help prompt.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
