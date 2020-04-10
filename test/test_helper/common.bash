TEST_STACK_NAME="test-mailserver-traefik"
DIR="test"
# default timeout is 120 seconds
TEST_TIMEOUT_IN_SECONDS=${TEST_TIMEOUT_IN_SECONDS-30}

function init_acme_traefik() {
  echo "CREATE empty acme.json file"
	rm -f "$DIR/files/acme.json"
	touch "$DIR/files/acme.json"
	chmod 600 "$DIR/files/acme.json"
}

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
