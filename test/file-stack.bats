load 'test_helper/common'

function setup_file() {
    docker-compose "$TEST_STACK_NAME" -f ./files/docker-compose.file.yml up -d
}

function teardown_file() {
    docker-compose "$TEST_STACK_NAME" -f ./files/docker-compose.file.yml down
    docker-compose "$TEST_STACK_NAME" -f ./files/docker-compose.file.yml rm
}


@test "check: missing certificates on mailserver" {
  run docker exec "${TEST_STACK_NAME}_mailserver_1" ls /etc/postfix/ssl
  assert_failed
}