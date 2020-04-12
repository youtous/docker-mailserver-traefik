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