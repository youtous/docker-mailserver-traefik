TEST_STACK_NAME="test-mailserver-traefik"

function init_acme_traefik() {
  echo "CREATE empty acme.json file"
	rm -f ./acme.json
	touch ./acme.json
	chmod 600 ./acme.json
}