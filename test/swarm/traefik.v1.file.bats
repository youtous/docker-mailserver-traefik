load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../test_helper/common'


function setup() {
  DOCKER_FILE_TESTS="$BATS_TEST_DIRNAME/../files/docker-compose.swarm.traefik.v1.file.yml"
  run_setup_file_if_necessary
}

function teardown() {
  run_teardown_file_if_necessary
}

@test "first" {
    skip "only used to call setup_file from setup: SWARM $( basename $BATS_TEST_FILENAME )"
}

@test "check: initial pull certificates in mailserver with 1 mailserver" {
    cert_renewer_id=$(getFirstContainerOfServiceName "cert-renewer")
    mailserver_id=$(getFirstContainerOfServiceName "mailserver")

    # test certificates are dumped
    run repeat_until_success_or_timeout "$TEST_TIMEOUT_IN_SECONDS" sh -c "docker exec ${cert_renewer_id} ls /tmp/ssl | grep mail.localhost.com"
    assert_success

    # test posthook certificate is triggered
    run repeat_until_success_or_timeout "$TEST_TIMEOUT_IN_SECONDS" sh -c "docker logs ${cert_renewer_id} | grep -F '[INFO] ${mailserver_id} - Cert update: new certificate copied into container'"
    assert_success

    # test presence of certificates
    run docker exec "${mailserver_id}" find /etc/dms/tls/ -not -empty -ls
    assert_output --partial 'cert'
    assert_output --partial 'key'
}

@test "check: valid openssl certificate mail.localhost.com valid on 993,465,25,587" {
    mailserver_id=$(getFirstContainerOfServiceName "mailserver")
    mailserver_certrenewer_id=$(getFirstContainerOfServiceName "cert-renewer")

    # ensure postfix and dovecot are restarted
    postfix_dovecot_restarted_regex="postfix: .*\npostfix: started\ndovecot: .*\ndovecot: started"

    run repeat_until_success_or_timeout "$TEST_TIMEOUT_IN_SECONDS" sh -c "docker logs ${mailserver_certrenewer_id} | grep -zoP '${postfix_dovecot_restarted_regex}'"
    assert_success

    # wait some time for slow services (dovecot, postfix) to restart
    sleep 15

    # postfix
    run docker exec "${mailserver_id}" sh -c "printf 'quit\n' | openssl s_client -connect localhost:25 -starttls smtp | openssl x509 -noout"
    assert_output --partial 'CN = mail.localhost.com'

    run docker exec "${mailserver_id}" sh -c "printf 'quit\n' | openssl s_client -connect localhost:587 -starttls smtp | openssl x509 -noout"
    assert_output --partial 'CN = mail.localhost.com'

    # dovecot
    run docker exec "${mailserver_id}" sh -c "printf 'quit\n' | openssl s_client -connect localhost:465 | openssl x509 -noout"
    assert_output --partial 'CN = mail.localhost.com'

    run docker exec "${mailserver_id}" sh -c "printf 'quit\n' | openssl s_client -connect localhost:993 | openssl x509 -noout"
    assert_output --partial 'CN = mail.localhost.com'
}

@test "last" {
    skip 'only used to call teardown_file from teardown'
}

setup_file() {
  docker stack rm "$TEST_STACK_NAME"
  waitSwarmStackDown
  autoCleanSwarmStackVolumes

  initSwarmAcmejson
  docker stack deploy --compose-file "$DOCKER_FILE_TESTS" "$TEST_STACK_NAME"
  waitUntilStackCountRunningServices 5
  waitUntilTraefikReady
  statusStack
}

teardown_file() {
  docker stack rm "$TEST_STACK_NAME"
  waitSwarmStackDown
  autoCleanSwarmStackVolumes
}

