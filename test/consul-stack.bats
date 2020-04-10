load 'test_helper/common'

function setup_file() {
    docker-compose "$TEST_STACK_NAME" -f ./files/docker-compose.file.yml up -d
}

function teardown_file() {
    docker-compose "$TEST_STACK_NAME" -f ./files/docker-compose.file.yml down
    docker-compose "$TEST_STACK_NAME" -f ./files/docker-compose.file.yml rm
}

# @test "check: "