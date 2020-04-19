TEST_STACK_NAME="test-mailserver-traefik"
# default timeout is 50 seconds
TEST_TIMEOUT_IN_SECONDS=${TEST_TIMEOUT_IN_SECONDS-50}

function repeat_until_success_or_timeout {
    if ! [[ "$1" =~ ^[0-9]+$ ]]; then
        echo "First parameter for timeout must be an integer, recieved \"$1\""
        return 1
    fi
    TIMEOUT=$1
    STARTTIME=$SECONDS
    shift 1
    until "$@"
    do
        sleep 5
        if [[ $(($SECONDS - $STARTTIME )) -gt $TIMEOUT ]]; then
            echo "Timed out on command: $@"
            return 1
        fi
    done
}

function log() {
  local -r log="log-${BATS_TEST_FILENAME##*/}"
  echo "$@" >> "$log"
}

SETUP_FILE_MARKER="$BATS_TMPDIR/`basename \"$BATS_TEST_FILENAME\"`.setup_file"
# use in setup() in conjunction with a `@test "first" {}` to trigger setup_file reliably
function run_setup_file_if_necessary() {
    if [ "$BATS_TEST_NAME" == 'test_first' ]; then
        # prevent old markers from marking success or get an error if we cannot remove due to permissions
        rm -f "$SETUP_FILE_MARKER"

        setup_file

        touch "$SETUP_FILE_MARKER"
    else
        if [ ! -f "$SETUP_FILE_MARKER" ]; then
            skip "setup_file failed"
            return 1
        fi
    fi
}

# use in teardown() in conjunction with a `@test "last" {}` to trigger teardown_file reliably
function run_teardown_file_if_necessary() {
    if [ "$BATS_TEST_NAME" == 'test_last' ]; then
        # cleanup setup file marker
        rm -f "$SETUP_FILE_MARKER"
        teardown_file
    fi
}

function initAcmejson() {
  echo "CREATE empty acme.json file"
	rm -f "$BATS_TEST_DIRNAME/files/acme.json"
	touch "$BATS_TEST_DIRNAME/files/acme.json"
	chmod 600 "$BATS_TEST_DIRNAME/files/acme.json"
}
function initSwarmAcmejson() {
  echo "CREATE empty acme.json file"
	rm -f "$BATS_TEST_DIRNAME/../files/acme.json"
	touch "$BATS_TEST_DIRNAME/../files/acme.json"
	chmod 600 "$BATS_TEST_DIRNAME/../files/acme.json"
}

function cleanSwarmStackVolumes() {
  for volume in $(docker volume ls -q) ; do
    if [ "$(docker inspect $volume --format '{{ index .Labels "com.docker.stack.namespace" }}')" == "$TEST_STACK_NAME" ] ; then
      repeat_until_success_or_timeout "$TEST_TIMEOUT_IN_SECONDS" docker volume rm $volume ;
    fi ;
  done
}

function acmejsonSingleIOFinished() {
  repeat_until_success_or_timeout "$TEST_TIMEOUT_IN_SECONDS" sh -c "[ \"\$(du "${BATS_TEST_DIRNAME}"/files/acme.json | awk '{print \$1}')\" -gt \"10\" ]"
}
function acmejsonIOFinished() {
  repeat_until_success_or_timeout "$TEST_TIMEOUT_IN_SECONDS" sh -c "[ \"\$(du "${BATS_TEST_DIRNAME}"/files/acme.json | awk '{print \$1}')\" -gt \"15\" ]"
}

function autoCleanSwarmStackVolumes() {
    repeat_until_success_or_timeout "$TEST_TIMEOUT_IN_SECONDS" cleanSwarmStackVolumes
}

function cleanSwarmStackNetworks() {
    networks=($(docker network ls --filter="name=${TEST_STACK_NAME}" --format="{{.ID}}"))
    for network in "${networks[@]}" ; do
      docker network rm "$network"
    done
}

function waitSwarmStackDown() {
    repeat_until_success_or_timeout "$TEST_TIMEOUT_IN_SECONDS" sh -c "docker stack ps $TEST_STACK_NAME && false || true"
}

function statusStack() {
  echo "# $(docker stack ps $TEST_STACK_NAME)" >&3
}

function waitUntilStackCountRunningServices() {
    repeat_until_success_or_timeout "$TEST_TIMEOUT_IN_SECONDS" [ "$(docker stack ps $TEST_STACK_NAME --filter='desired-state=running' | wc -l)" == "$(($@+1))" ]
    echo "stack $TEST_STACK_NAME is up!" >&3
}

function waitUntilTraefikReady() {
    repeat_until_success_or_timeout "$TEST_TIMEOUT_IN_SECONDS" curl https://localhost -v4 --insecure
    echo "stack $TEST_STACK_NAME: traefik is ready!" >&3
}

function getFirstContainerOfServiceName() {
    name="$@"

    container_id=$( docker ps --filter="name=$(docker service ps "$(docker service ls --filter="name=${TEST_STACK_NAME}_${name}" --format='{{.ID}}')" --filter='desired-state=running'  --format="{{.ID}}")" --filter="status=running" --format="{{.ID}}")

    TIMEOUT=$TEST_TIMEOUT_IN_SECONDS
    STARTTIME=$SECONDS

    while [ -z "$container_id" ]; do
      if [[ $(($SECONDS - $STARTTIME )) -gt $TIMEOUT ]]; then
            echo "Timed out on get container_id: $@"
            return 1
      fi

      container_id=$( docker ps --filter="name=$(docker service ps "$(docker service ls --filter="name=${TEST_STACK_NAME}_${name}" --format='{{.ID}}')"  --filter='desired-state=running' --format="{{.ID}}")"  --filter="status=running" --format="{{.ID}}")

      if [ -z "$container_id" ]; then
          sleep 3
      fi
    done

    echo "$container_id"
}