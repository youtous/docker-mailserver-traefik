load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'test_helper/common'


function setup() {
  DOCKER_FILE_TRAEFIK_TESTS="$BATS_TEST_DIRNAME/files/docker-compose.traefik.v1.file-external_traefik.yml"
  DOCKER_FILE_MAILSERVER_TESTS="$BATS_TEST_DIRNAME/files/docker-compose.traefik.v1.file-external_mailserver.yml"
  TEST_STACK_NAME_TRAEFIK="${TEST_STACK_NAME}_traefik"
  TEST_STACK_NAME_MAILSERVER="${TEST_STACK_NAME}_mailserver"
  run_setup_file_if_necessary
}

function teardown() {
  run_teardown_file_if_necessary
}

@test "first" {
    skip 'only used to call setup_file from setup'
}

@test "check: initial pull certificates when traefik was already running" {
    # up traefik stack and only mailserver
    docker-compose -p "$TEST_STACK_NAME_TRAEFIK" -f "$DOCKER_FILE_TRAEFIK_TESTS" up -d
    docker-compose -p "$TEST_STACK_NAME_MAILSERVER" -f "$DOCKER_FILE_MAILSERVER_TESTS" up -d mailserver

    # wait until certificates are generated for mail.localhost.com
    run repeat_until_success_or_timeout 200 sh -c "docker logs ${TEST_STACK_NAME_TRAEFIK}_traefik_1 | grep -F \"Adding certificate for domain(s) mail.localhost.com\""
    assert_success

    # launch certificate renewer
    docker-compose -p "$TEST_STACK_NAME_MAILSERVER" -f "$DOCKER_FILE_MAILSERVER_TESTS" up -d

    # test certificates are dumped
    run repeat_until_success_or_timeout 45 sh -c "docker exec ${TEST_STACK_NAME_MAILSERVER}_mailserver-traefik_1 ls /tmp/ssl | grep mail.localhost.com"
    assert_success

    # test posthook certificate is triggered
    run repeat_until_success_or_timeout 30 sh -c "docker logs ${TEST_STACK_NAME_MAILSERVER}_mailserver-traefik_1 | grep -F '[INFO] mail.localhost.com - Cert update: new certificate copied into container'"
    assert_success

    # test presence of certificates
    run docker exec "${TEST_STACK_NAME_MAILSERVER}_mailserver_1" ls /etc/postfix/ssl/
    assert_output --partial 'cert'
    assert_output --partial 'key'
}

@test "last" {
    skip 'only used to call teardown_file from teardown'
}

setup_file() {
  docker-compose -p "$TEST_STACK_NAME_TRAEFIK" -f "$DOCKER_FILE_TRAEFIK_TESTS" down -v --remove-orphans
  docker-compose -p "$TEST_STACK_NAME_MAILSERVER" -f "$DOCKER_FILE_MAILSERVER_TESTS" down -v --remove-orphans

  docker network create test-traefik-public-external || true

  docker volume rm test-acme-external || true
  docker volume create test-acme-external || true
}

teardown_file() {
  docker-compose -p "$TEST_STACK_NAME_TRAEFIK" -f "$DOCKER_FILE_TRAEFIK_TESTS" down -v --remove-orphans
  docker-compose -p "$TEST_STACK_NAME_MAILSERVER" -f "$DOCKER_FILE_MAILSERVER_TESTS" down -v --remove-orphans

  docker network rm test-traefik-public-external || true
  docker volume rm test-acme-external || true
}
