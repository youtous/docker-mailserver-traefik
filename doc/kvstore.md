# KV Store configuration
| Variable | Description | Type | Default value | Values |
| -------- | ----------- | ---- | ------------- | ------ |
| **KV_ENDPOINTS** | endpoints to connect | *required* |  |  `address:port`, e.g.:<br>`consul:8500`<br>`etcd:2139`<br>`198.168.2.36:2139`
| **KV_PREFIX** | [prefix used](https://docs.traefik.io/v1.7/configuration/backends/consul/) in KV store | *optional* | traefik | *string*
| **KV_SUFFIX** | suffix used in KV store | *optional* | /acme/account/object | *string*
| **KV_USERNAME** | KV store username | *optional* |  | *string*
| **KV_PASSWORD** | KV store password | *optional* |  | *string*
| **KV_TIMEOUT** | connection timeout in seconds | *optional* |  |  *integer*
| **KL_TLS_ENABLED** | enable TLS encryption | *optional* | 0 | *1* or *0*
| **KV_TLS_CA** | Root CA for certificate verification if TLS is enabled | *optional* | | *string*
| **KV_TLS_CA_OPTIONAL** | set Root CA optional | *optional* | 0 | *1* or *0*
| **KV_TLS_TRUST_INSECURE** | trust unverified certificates if TLS is enabled | *optional* | 0 | *1* or *0*
| **KV_TLS_CERT** | TLS cert | *optional* |  | *string*
| **KV_TLS_KEY** | TLS key | *optional* |  | *string*

##### Consul

Specific consul options:

| Variable | Description | Type | Default value | Values |
| -------- | ----------- | ---- | ------------- | ------ |
| **KV_CONSUL_TOKEN** | token for consul | *optional* |  |  *string*

##### etcd

Specific etcd options:

| Variable | Description | Type | Default value | Values |
| -------- | ----------- | ---- | ------------- | ------ |
| **KV_ETCD_VERSION** | etcd version to use | *optional* | etcd |  `etcd` or `etcdv3`
| **KV_ETCD_SYNC_PERIOD** | sync period in seconds | *optional* | |  *integer*

##### BoltDB

Specific consul options:

| Variable | Description | Type | Default value | Values |
| -------- | ----------- | ---- | ------------- | ------ |
| **KV_BOLTDB_BUCKET** | bucket for boltdb | *optional* | traefik  |  *string*
| **KV_BOLTDB_PERSIST_CONNECTION** | persist connection for boltdb | *optional* |  0 |  *1* or *0*

##### ZooKeeper
There is no specific option for ZooKeeper.


