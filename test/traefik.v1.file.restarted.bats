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

@test "check: dovecot and postfix restarted using supervisorctl after certificate push" {
    postfix_dovecot_restarted_regex="postfix: .*\npostfix: started\ndovecot: .*\ndovecot: started"

    run repeat_until_success_or_timeout "$TEST_TIMEOUT_IN_SECONDS" sh -c "docker logs ${TEST_STACK_NAME}_mailserver-traefik_1 | grep -zoP '${postfix_dovecot_restarted_regex}'"
    assert_success
}

@test "last" {
    skip 'only used to call teardown_file from teardown'
}

setup_file() {
  initAcmejson
  docker-compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" down -v --remove-orphans

  docker-compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" up -d traefik pebble challtestsrv

  # wait traefik+pebble are up
  run repeat_until_success_or_timeout "$TEST_TIMEOUT_IN_SECONDS" sh -c "docker logs ${TEST_STACK_NAME}_traefik_1 | grep -F \"Adding certificate for domain(s) traefik.localhost.com\""
  assert_success
  # wait until mailserver is up
  run docker-compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" up -d mailserver
  assert_success
  run repeat_until_success_or_timeout "$TEST_TIMEOUT_IN_SECONDS" sh -c "docker logs ${TEST_STACK_NAME}_mailserver_1 | grep -F 'mail.localhost.com is up and running'"
  assert_success
  # then up the entire stack
  run docker-compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" up -d
  assert_success
}

teardown_file() {
  docker-compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" down -v --remove-orphans
}
