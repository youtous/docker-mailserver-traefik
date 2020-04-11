load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'test_helper/common'

# todo :
#  - test with consul external network

#  - multidomain, copied to multiservers
#  - single domain copied to multiserver
#  - traefik v2 test

function setup() {
  DOCKER_FILE_TESTS="$BATS_TEST_DIRNAME/files/docker-compose.traefik.v1.consul.yml"
  run_setup_file_if_necessary
}

function teardown() {
  run_teardown_file_if_necessary
}

@test "first" {
    skip 'only used to call setup_file from setup'
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

@test "check: initial pull certificates when traefik was already running" {
    # up a new stack with only mailserver
    docker-compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" down -v --remove-orphans
    docker-compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" up -d traefik consul-leader pebble challtestsrv mailserver

    # wait until certificates are generated for mail.localhost.com
    run repeat_until_success_or_timeout 120 sh -c "docker logs ${TEST_STACK_NAME}_traefik_1 | grep -F \"Adding certificate for domain(s) mail.localhost.com\""
    assert_success

    # launch certificate renewer
    docker-compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" up -d

    # test certificate is added to mailserver
    run repeat_until_success_or_timeout 30 sh -c "docker logs ${TEST_STACK_NAME}_mailserver-traefik_1 | grep -F '[INFO] mail.localhost.com - Cert update: new certificate copied into container'"
    assert_success
}

@test "check: stack consul on an external network" {



}

@test "last" {
    skip 'only used to call teardown_file from teardown'
}

setup_file() {
  docker-compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" down -v --remove-orphans
  docker-compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" up -d
}

teardown_file() {
  docker-compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" down -v --remove-orphans
}