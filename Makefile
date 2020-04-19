#!make
.PHONY: tests build build-test clean help tests-compose-no-build tests-swarm-no-build tests-no-build
.DEFAULT_GOAL= help

build: ## Build the image
	echo "building latest mailserver-traefik image..."
	docker build . -t 'mailserver-traefik'

build-test: ## Build the test image
	echo "building latest mailserver-traefik:test-image image..."
	docker build . -t 'mailserver-traefik:test-image'

tests: build-test ## Run all the tests. The test image will be built. Docker swarm will be activated then disabled
	make tests-no-build

tests-no-build: ## Run all tests without building initial image. Docker swarm will be activated then disabled
	echo "Docker-compose tests"
	make tests-compose-no-build
	make tests-swarm-no-build
	make clean

tests-compose-no-build: ## Run docker-compose tests.
	echo "Docker-compose tests"
	./test/libs/bats/bin/bats test/*.bats

tests-swarm-no-build: ## Run docker swarm tests. Docker swarm will be activated then disabled.
	echo "Docker swarm tests"
	docker swarm init || true
	./test/libs/bats/bin/bats test/swarm/*.bats
	docker swarm leave --force || true

clean: ## Remove docker images built.
	docker rmi mailserver-traefik:test-image
	rm -f test/files/acme.json
	rm -f test/files/swarm/acme.json

# see https://suva.sh/posts/well-documented-makefiles/
help: ## Show this help prompt.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
