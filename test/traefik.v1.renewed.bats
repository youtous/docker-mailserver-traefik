load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'test_helper/common'

function setup() {
  DOCKER_FILE_TESTS="$BATS_TEST_DIRNAME/files/docker-compose.traefik.v1.renewed.yml"
  run_setup_file_if_necessary
}

function teardown() {
  run_teardown_file_if_necessary
}

@test "first" {
    skip "only used to call setup_file from setup: $( basename $BATS_TEST_FILENAME )"
}

@test "check: when a certificate is renewed, the corresponding mailserver must receive and update the certificate" {
    # mock first certificate generation
    run cp "${BATS_TEST_DIRNAME}/fixtures/acme.v1.json" "${BATS_TEST_DIRNAME}/files/acme.json" && chmod 600 "${BATS_TEST_DIRNAME}/files/acme.json"
    assert_success
    run docker-compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" up -d -V mailserver mailserver-traefik
    assert_success

    # test script has been triggered on mailserver
    run repeat_until_success_or_timeout "$TEST_TIMEOUT_IN_SECONDS" sh -c "docker logs ${TEST_STACK_NAME}_mailserver-traefik_1 | grep -F \"[INFO] mail.localhost.com - new certificate '/tmp/ssl/fullchain.pem' received on mailserver container\""
    assert_success
    # test trigger script completion
    run repeat_until_success_or_timeout "$TEST_TIMEOUT_IN_SECONDS" sh -c "docker logs ${TEST_STACK_NAME}_mailserver-traefik_1 | grep -F '[INFO] mail.localhost.com - Cert update: new certificate copied into container'"
    assert_success
    # test presence of certificates
    run docker exec "${TEST_STACK_NAME}_mailserver_1" ls /etc/postfix/ssl/
    assert_output --partial 'cert'
    assert_output --partial 'key'

    fp_mailserver_initial=$( docker exec "${TEST_STACK_NAME}_mailserver_1" sha256sum /etc/postfix/ssl/cert | awk '{print $1}' )

    # save timestamp for log
    first_restart_timestamp=$( date +%s )

    # once the a first certificate has been pushed, we must simulate a new renewal
    run cp "${BATS_TEST_DIRNAME}/fixtures/acme.v1.inversed.json" "${BATS_TEST_DIRNAME}/files/acme.json" && chmod 600 "${BATS_TEST_DIRNAME}/files/acme.json"
    assert_success

    # let the magical operates
    run repeat_until_success_or_timeout "$TEST_TIMEOUT_IN_SECONDS" sh -c "docker logs --since ${first_restart_timestamp} ${TEST_STACK_NAME}_mailserver-traefik_1 | grep -F \"[INFO] mail.localhost.com - new certificate '/tmp/ssl/fullchain.pem' received on mailserver container\""
    assert_success
    # test trigger script completion
    run repeat_until_success_or_timeout "$TEST_TIMEOUT_IN_SECONDS" sh -c "docker logs --since ${first_restart_timestamp} ${TEST_STACK_NAME}_mailserver-traefik_1 | grep -F '[INFO] mail.localhost.com - Cert update: new certificate copied into container'"
    assert_success

    # compare new ssl cert installed
    fp_mailserver_after=$( docker exec "${TEST_STACK_NAME}_mailserver_1" sha256sum /etc/postfix/ssl/cert | awk '{print $1}' )
    run echo "$fp_mailserver_after"
    refute_output "$fp_mailserver_initial"
}


@test "last" {
    skip 'only used to call teardown_file from teardown'
}

setup_file() {
  initAcmejson
  docker-compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" down -v --remove-orphans
  docker-compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" up -d -V mailserver
}

teardown_file() {
  docker-compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" down -v --remove-orphans
}
