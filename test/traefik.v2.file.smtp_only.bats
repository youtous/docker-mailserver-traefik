load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'test_helper/common'

function setup() {
  DOCKER_FILE_TESTS="$BATS_TEST_DIRNAME/files/docker-compose.traefik.v2.file.smtp_only.yml"
  run_setup_file_if_necessary
}

function teardown() {
  run_teardown_file_if_necessary
}

@test "first" {
    skip "only used to call setup_file from setup: $( basename $BATS_TEST_FILENAME )"
}


@test "check: ONLY postfix restarted using supervisorctl after certificate push (not dovecot)" {
    postfix_dovecot_restarted_regex="postfix: .*\npostfix: started"

    run repeat_until_success_or_timeout "$TEST_TIMEOUT_IN_SECONDS" sh -c "docker logs ${TEST_STACK_NAME}-mailserver-traefik-1 | grep -zoP '${postfix_dovecot_restarted_regex}'"
    sleep 5

    run docker exec "${TEST_STACK_NAME}-mailserver-1" supervisorctl status dovecot
    assert_output --partial 'STOPPED'
    assert_output --partial 'Not started'
}

@test "last" {
    skip 'only used to call teardown_file from teardown'
}

setup_file() {
  initAcmejson
  docker-compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" down -v --remove-orphans
  docker-compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" up -d traefik pebble challtestsrv

  # wait traefik+pebble are up
  run repeat_until_success_or_timeout "$TEST_TIMEOUT_IN_SECONDS" sh -c "docker logs ${TEST_STACK_NAME}-traefik-1 | grep -F \"Adding certificate for domain(s) traefik.localhost.com\""
  assert_success
  # wait until mailserver is up
  run docker-compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" up -d mailserver
  assert_success
  # wait IO done
  acmejsonIOFinished

  run repeat_until_success_or_timeout "$TEST_TIMEOUT_IN_SECONDS" sh -c "docker logs ${TEST_STACK_NAME}-mailserver-1 | grep -F 'mail.localhost.com is up and running'"
  assert_success
  # then up the entire stack
  run docker-compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" up -d
  assert_success
}

teardown_file() {
  docker-compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" down -v --remove-orphans
}