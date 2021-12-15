load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'test_helper/common'

function setup() {
  DOCKER_FILE_TESTS="$BATS_TEST_DIRNAME/files/docker-compose.traefik.v1.file.new-container.yml"
  export PUSH_PERIOD="20s" # push certificates every 20s

  run_setup_file_if_necessary
}

function teardown() {
  unset PUSH_PERIOD
  run_teardown_file_if_necessary
}

@test "first" {
    skip "only used to call setup_file from setup: $( basename $BATS_TEST_FILENAME )"
}

@test "check: push existing certificate to newly created container" {

    # wait push has been done
    run repeat_until_success_or_timeout "$TEST_TIMEOUT_IN_SECONDS" sh -c "docker logs ${TEST_STACK_NAME}-mailserver-traefik-1 | grep -F \"Pushing mail.localhost.com\""
    assert_success
    first_push_time=$( date +%s )

    # up mailserver
    run docker compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" up -d mailserver
    assert_success

    # test trigger script completion
    run repeat_until_success_or_timeout "$TEST_TIMEOUT_IN_SECONDS" sh -c "docker logs --since ${first_push_time} ${TEST_STACK_NAME}-mailserver-traefik-1 | grep -F '[INFO] Periodically push initiated...'"
    assert_success
    run repeat_until_success_or_timeout "$TEST_TIMEOUT_IN_SECONDS" sh -c "docker logs --since ${first_push_time} ${TEST_STACK_NAME}-mailserver-traefik-1 | grep -F '[INFO] mail.localhost.com - Cert update: new certificate copied into container'"
    assert_success

    # test presence of certificates
    run docker exec "${TEST_STACK_NAME}-mailserver-1" find /etc/dms/tls/ -not -empty -ls
    assert_output --partial 'cert'
    assert_output --partial 'key'
}

@test "last" {
    skip 'only used to call teardown_file from teardown'
}

setup_file() {
  initAcmejson
  docker compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" down -v --remove-orphans
  docker compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" up -d traefik pebble challtestsrv

  # wait traefik+pebble are up
  run repeat_until_success_or_timeout "$TEST_TIMEOUT_IN_SECONDS" sh -c "docker logs ${TEST_STACK_NAME}-traefik-1 | grep -F \"Adding certificate for domain(s) mail.localhost.com\""
  assert_success
  acmejsonSingleIOFinished

  # then up the renewer
  run docker compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" up -d mailserver-traefik
  assert_success
}

teardown_file() {
  docker compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" down -v --remove-orphans
}
