load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'test_helper/common'

function setup() {
  DOCKER_FILE_TESTS="$BATS_TEST_DIRNAME/files/docker-compose.traefik.v1.multiservers.yml"
  run_setup_file_if_necessary
}

function teardown() {
  run_teardown_file_if_necessary
}

@test "first" {
    skip "only used to call setup_file from setup: $( basename $BATS_TEST_FILENAME )"
}

@test "check: each certificate is copied on different servers" {
  # test certificate is dumped
  run repeat_until_success_or_timeout "$TEST_TIMEOUT_IN_SECONDS" sh -c "docker exec ${TEST_STACK_NAME}-mailserver-traefik-1 ls /tmp/ssl | grep mail.localhost.com"
  assert_success

  # test presence of certificate
  run docker exec "${TEST_STACK_NAME}-mailserver-traefik-1" ls /tmp/ssl/mail.localhost.com/
  assert_output --partial 'fullchain.pem'
  assert_output --partial 'privkey.pem'
  # register fingerprint of certificates
  fp_mailserver=$( docker exec "${TEST_STACK_NAME}-mailserver-traefik-1" sha256sum /tmp/ssl/mail.localhost.com/fullchain.pem | awk '{print $1}' )


  # test posthook certificate is triggered on each server
  run repeat_until_success_or_timeout "$TEST_TIMEOUT_IN_SECONDS" sh -c "docker logs ${TEST_STACK_NAME}-mailserver-traefik-1 | grep -F '[INFO] server1.localhost.com - Cert update: new certificate copied into container'"
  assert_success
  run repeat_until_success_or_timeout "$TEST_TIMEOUT_IN_SECONDS" sh -c "docker logs ${TEST_STACK_NAME}-mailserver-traefik-1 | grep -F '[INFO] server2.localhost.com - Cert update: new certificate copied into container'"
  assert_success

  # test presence of certificates
  run docker exec "${TEST_STACK_NAME}-mailserver1-1" find /etc/dms/tls/ -not -empty -ls
  assert_output --partial 'cert'
  assert_output --partial 'key'
  run docker exec "${TEST_STACK_NAME}-mailserver2-1" find /etc/dms/tls/ -not -empty -ls
  assert_output --partial 'cert'
  assert_output --partial 'key'

  # compare fingerprints in mailserver container
  fp_mailserver1_target=$( docker exec "${TEST_STACK_NAME}-mailserver1-1" sha256sum /etc/dms/tls/cert | awk '{print $1}')
  assert_equal "$fp_mailserver1_target" "$fp_mailserver"
  fp_mailserver2_target=$( docker exec "${TEST_STACK_NAME}-mailserver2-1" sha256sum /etc/dms/tls/cert | awk '{print $1}' )
  assert_equal "$fp_mailserver2_target" "$fp_mailserver"
}

@test "last" {
    skip 'only used to call teardown_file from teardown'
}

setup_file() {
  initAcmejson
  docker compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" down -v --remove-orphans
  docker compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" up -d traefik pebble challtestsrv

  # wait traefik+pebble are up
  run repeat_until_success_or_timeout "$TEST_TIMEOUT_IN_SECONDS" sh -c "docker logs ${TEST_STACK_NAME}-traefik-1 | grep -F \"Adding certificate for domain(s) traefik.localhost.com\""
  assert_success

  # wait until mailservers are up
  run docker compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" up -d mailserver1 mailserver2
  assert_success
  # wait IO done
  acmejsonIOFinished

  run repeat_until_success_or_timeout "$TEST_TIMEOUT_IN_SECONDS" sh -c "docker logs ${TEST_STACK_NAME}-mailserver1-1 | grep -F 'server1.localhost.com is up and running'"
  assert_success
  run repeat_until_success_or_timeout "$TEST_TIMEOUT_IN_SECONDS" sh -c "docker logs ${TEST_STACK_NAME}-mailserver2-1 | grep -F 'server2.localhost.com is up and running'"
  assert_success
  # then up the entire stack
  run docker compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" up -d
  assert_success
}

teardown_file() {
  docker compose -p "$TEST_STACK_NAME" -f "$DOCKER_FILE_TESTS" down -v --remove-orphans
}
