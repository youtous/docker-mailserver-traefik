#!make
.PHONY: stop start start-acme start-traefik start-mailserver build rebuild help restart init-env
.DEFAULT_GOAL= help
STACK_NAME=acme_stack
COMPOSE_FILE=docker-compose.file.yml

stop: ## Stop the application.
	docker-compose -p ${STACK_NAME} -f ${COMPOSE_FILE} down ${ARGS}

start: init-env start-acme start-traefik start-mailserver ## Start the entire stack.

start-acme: # Start ACME part of the stack.
	docker-compose -p ${STACK_NAME} -f ${COMPOSE_FILE} up pebble challtestsrv ${ARGS}

start-traefik: init-env # Start traefik part of the stack.
	docker-compose -p ${STACK_NAME} -f ${COMPOSE_FILE} up traefik ${ARGS}

start-mailserver: # Start mailserver part of the stack.
	docker-compose -p ${STACK_NAME} -f ${COMPOSE_FILE} up mailserver autorenew-mailserver-certs ${ARGS}

restart: ## Restart the entire stack.
	make stop ${ARGS}
	make start ${ARGS}

rebuild: ## Rebuild the docker stack, remove old images. This command will stop the stack.
	docker-compose -p ${STACK_NAME} down
	docker-compose -p ${STACK_NAME} build --no-cache --pull
	docker-compose -p ${STACK_NAME} down
	docker image prune -f

build: ## Build the docker stack, remove old images. This command will stop the stack.
	docker-compose -p ${STACK_NAME} down
	docker-compose -p ${STACK_NAME} build
	docker-compose -p ${STACK_NAME} down
	docker image prune -f

test: ## Run all the tests of the application.

init-env: ## Init env, create needed files
	echo "CREATE empty acme.json file"
	rm -f ./acme.json
	touch ./acme.json
	chmod 600 ./acme.json

# see https://suva.sh/posts/well-documented-makefiles/
help: ## Show this help prompt.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
