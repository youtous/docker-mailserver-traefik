load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'test_helper/common'

# todo :
#  - renewal of certificated, triggers : new cert and restart of dovecot etc

function setup() {
  run_setup_file_if_necessary
}

function teardown() {
  run_teardown_file_if_necessary
}

@test "first" {
    skip 'only used to call setup_file from setup'
}

@test "check: missing certificates on mailserver" {
  run docker exec "${TEST_STACK_NAME}_mailserver_1" ls /etc/postfix/ssl/key
  assert_output --partial 'No such file or directory'
  run docker exec "${TEST_STACK_NAME}_mailserver_1" ls /etc/postfix/ssl/cert
  assert_output --partial 'No such file or directory'
}

@test "check: mailserver-traefik waits when no key" {
  # wait until traefik built ACME file
  run repeat_until_success_or_timeout 20 sh -c "docker logs ${TEST_STACK_NAME}_traefik_1 | grep -F 'Building ACME client...'"
  assert_success

  run repeat_until_success_or_timeout 30 sh -c "docker logs ${TEST_STACK_NAME}_mailserver-traefik_1 | grep -F 'Traefik acme is generating. Waiting until completed...'"
  assert_success
}

@test "modify: restart the stack with pebble (ACME server)" {
    docker-compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" down -v --remove-orphans
    docker-compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" up -d
}

@test "check: push certificate for mail.localhost.com trigged" {
  run repeat_until_success_or_timeout 60 sh -c "docker logs ${TEST_STACK_NAME}_mailserver-traefik_1 | grep -F 'Pushing mail.localhost.com to'"
  assert_success
}

@test "check: certificate mail.localhost.com received on mailserver container" {
    # test script has been triggered on mailserver
    run repeat_until_success_or_timeout 30 sh -c "docker logs ${TEST_STACK_NAME}_mailserver-traefik_1 | grep -F \"[INFO] mail.localhost.com - new certificate '/tmp/ssl/fullchain.pem' received on mailserver container\""
    assert_success

    # test trigger script completion
    run repeat_until_success_or_timeout 30 sh -c "docker logs ${TEST_STACK_NAME}_mailserver-traefik_1 | grep -F '[INFO] mail.localhost.com - Cert update: new certificate copied into container'"
    assert_success

    # test presence of certificates
    run docker exec "${TEST_STACK_NAME}_mailserver_1" ls /etc/postfix/ssl/
    assert_output --partial 'cert'
    assert_output --partial 'key'
}

@test "check: dovecot and postfix restarted using supervisorctl after certificate push" {

    # up a new stack with only mailserver
    docker-compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" down -v --remove-orphans
    docker-compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" up -d mailserver

    # wait until mailserver is up
    repeat_until_success_or_timeout 60 sh -c "docker logs ${TEST_STACK_NAME}_mailserver_1 | grep -F 'mail.localhost.com is up and running'"

    # enable certificate generation
    docker-compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" up -d

    postfix_dovecot_restarted_regex="postfix: stopped\npostfix: started\ndovecot: stopped\ndovecot: started"

    run repeat_until_success_or_timeout 30 sh -c "docker logs ${TEST_STACK_NAME}_mailserver-traefik_1 | grep -zoP '${postfix_dovecot_restarted_regex}'"
    assert_success
}

@test "last" {
    skip 'only used to call teardown_file from teardown'
}

setup_file() {
  DOCKER_FILE_TESTS="$BATS_TEST_DIRNAME/files/docker-compose.traefik.v1.file.yml"
  docker-compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" down -v --remove-orphans
  docker-compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" up -d traefik mailserver mailserver-traefik
}

teardown_file() {
  unset DOCKER_FILE_TESTS
  docker-compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" down -v --remove-orphans
}
