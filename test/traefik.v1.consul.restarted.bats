load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'test_helper/common'

function setup() {
  DOCKER_FILE_TESTS="$BATS_TEST_DIRNAME/files/docker-compose.traefik.v1.consul.yml"
  run_setup_file_if_necessary
}

function teardown() {
  run_teardown_file_if_necessary
}

@test "first" {
    skip "only used to call setup_file from setup: $( basename $BATS_TEST_FILENAME )"
}


@test "check: dovecot and postfix restarted using supervisorctl after certificate push" {
    # up a new stack with only mailserver and traefik
    docker compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" up -d mailserver traefik consul-leader pebble challtestsrv

    # wait until mailserver is up
    repeat_until_success_or_timeout "$TEST_TIMEOUT_IN_SECONDS" sh -c "docker logs ${TEST_STACK_NAME}-mailserver-1 | grep -F 'mail.localhost.com is up and running'"

    # enable certificate generation
    docker compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" up -d

    postfix_dovecot_restarted_regex="postfix: .*\npostfix: started\ndovecot: .*\ndovecot: started"

    run repeat_until_success_or_timeout "$TEST_TIMEOUT_IN_SECONDS" sh -c "docker logs ${TEST_STACK_NAME}-mailserver-traefik-1 | grep -zoP '${postfix_dovecot_restarted_regex}'"
    assert_success
}

@test "last" {
    skip 'only used to call teardown_file from teardown'
}

setup_file() {
  docker compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" down -v --remove-orphans
}

teardown_file() {
  docker compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" down -v --remove-orphans
}