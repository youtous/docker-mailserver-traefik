load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'test_helper/common'

function setup() {
  init_acme_traefik
  docker network prune -f
  docker-compose -p "$TEST_STACK_NAME" -f "$BATS_TEST_DIRNAME/files/docker-compose.file.yml" build mailserver-traefik
  docker-compose -p "$TEST_STACK_NAME" -f "$BATS_TEST_DIRNAME/files/docker-compose.file.yml" up -d mailserver mailserver-traefik traefik
}

function teardown() {
  # docker-compose -p "$TEST_STACK_NAME" -f "$DIR/files/docker-compose.file.yml" stop
  docker-compose -p "$TEST_STACK_NAME" -f "$BATS_TEST_DIRNAME/files/docker-compose.file.yml" down -v --remove-orphans
}


@test "check: missing certificates on mailserver" {
  run docker exec "${TEST_STACK_NAME}_mailserver_1" ls /etc/postfix/ssl
  assert_output --partial 'No such file or directory'
}

@test "check: mailserver-traefik waits when no key" {
  repeat_until_success_or_timeout 20 $(docker logs "${TEST_STACK_NAME}_mailserver-traefik_1" | grep -F "Building ACME client...")
  run docker logs "${TEST_STACK_NAME}_mailserver-traefik_1"
  assert_output --partial 'Traefik acme is generating. Waiting until completed...'
}