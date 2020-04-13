load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'test_helper/common'

function setup() {
  DOCKER_FILE_TESTS="$BATS_TEST_DIRNAME/files/docker-compose.traefik.v1.file.yml"
  run_setup_file_if_necessary
}

function teardown() {
  run_teardown_file_if_necessary
}

@test "first" {
    skip "only used to call setup_file from setup: $( basename $BATS_TEST_FILENAME )"
}

@test "check: missing certificates on mailserver" {
  run docker exec "${TEST_STACK_NAME}_mailserver_1" ls /etc/postfix/ssl/key
  assert_output --partial 'No such file or directory'
  run docker exec "${TEST_STACK_NAME}_mailserver_1" ls /etc/postfix/ssl/cert
  assert_output --partial 'No such file or directory'
}

@test "check: mailserver-traefik waits when no key" {
  # wait until traefik built ACME file
  run repeat_until_success_or_timeout "$TEST_TIMEOUT_IN_SECONDS" sh -c "docker logs ${TEST_STACK_NAME}_traefik_1 | grep -F 'Building ACME client...'"
  assert_success

  run repeat_until_success_or_timeout "$TEST_TIMEOUT_IN_SECONDS" sh -c "docker logs ${TEST_STACK_NAME}_mailserver-traefik_1 | grep -F 'Traefik acme is generating. Waiting until completed...'"
  assert_success
}

@test "last" {
    skip 'only used to call teardown_file from teardown'
}

setup_file() {
  docker-compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" down -v --remove-orphans
  docker-compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" up -d traefik mailserver mailserver-traefik
}

teardown_file() {
  docker-compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" down -v --remove-orphans
}
