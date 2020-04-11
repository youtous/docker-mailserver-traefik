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
    skip 'only used to call setup_file from setup'
}

@test "check: when a certificate is renewed, the corresponding mailserver must receive and update the certificate" {
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

    fp_mailserver_initial=$( docker exec "${TEST_STACK_NAME}_mailserver_1" sha256sum /etc/postfix/ssl/cert | awk '{print $1}' )

    # once the a first certificate has been pushed, we must simulate a new renewal
    docker cp "$BATS_TEST_DIRNAME/fixtures/acme.v1.json" "${TEST_STACK_NAME}_traefik_1":/tmp/acme/acme.json
    assert_success
    docker exec "${TEST_STACK_NAME}_traefik_1" chmod 600 /tmp/acme/acme.json
    assert_success

    # let the magical operates
    repeat_until_success_or_timeout 45
    postfix_dovecot_restarted_regex="postfix: .*\npostfix: started\ndovecot: .*\ndovecot: started\n"
    count_lines_excepted=8

    run repeat_until_success_or_timeout 30 sh -c "docker logs ${TEST_STACK_NAME}_mailserver-traefik_1 | grep -zoP '${postfix_dovecot_restarted_regex}' | wc -l" -eq  $count_lines_excepted
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
  docker-compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" down -v --remove-orphans
  docker-compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" up -d
}

teardown_file() {
  docker-compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" down -v --remove-orphans
}
