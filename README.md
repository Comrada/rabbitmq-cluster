## RabbitMQ Cluster

Docker image to run RabbitMQ cluster. It extends the official RabbitMQ management image with configuration scripts.
The configuration of this cluster contains the following plugins: authorization via LDAP, authorization cache,
export of metrics to Prometheus.

> **Disclaimer:** The creation of an AMQP cluster is a very specific task, strongly related to the corporate
> infrastructure and organization specifics. Therefore, this configuration can only be considered as one of many
> examples.

Initial requirements:
- The cluster must consist of at least 2 nodes
- The system must have one local "admin" user with full rights
- Authorization must be done using an existing LDAP server (ActiveDirectory)
- In order not to load the AD server, a short-term caching of results is required
- User access to the virtual host is regulated using the appropriate group in LDAP
- User access to the web-based management interface is regulated using the appropriate group in the LDAP
- Self-signed server and client certificates are used.
- Servers have only 5671 ports with SSL encryption open. Communication between nodes is carried out in a secure private
network.
- The cluster must be able to export metrics to Prometheus

## Installation
* Install Docker and Docker Compose
* Create a folder with SSL certificates on the host file system
* Open following ports in the firewall: for client working 5671, for clustering 4369, 25672, for management 15672
* Create docker-compose.yaml file (or stack in Portainer) on each machine with the content below.
* Run docker with command `docker-compose up -d`

Docker configuration for master node:
```yaml
version: '2'
 
services:
  rabbit-master:
    image: comrada/rabbitmq-cluster
    hostname: amqp1.company-site.com
    network_mode: host
    volumes:
      - /ssl/cacert.pem:/ssl/cacertfile.pem
      - /ssl/cert.pem:/ssl/certfile.pem
      - /ssl/key.pem:/ssl/keyfile.pem
      - mnesia:/var/lib/rabbitmq/mnesia
    ports:
      - 5671:5671
      - 15672:15672
      - 4369:4369
      - 25672:25672
    environment:
      RABBITMQ_USE_LONGNAME: 'true'
      DEFAULT_USER: myuser
      DEFAULT_PASS: mypass
      CLUSTER_NAME: amqp-cluster-live
      ERLANG_COOKIE: abcdefg
      LDAP_SERVERS: ldap.eng.megacorp.local,ldap.eu.megacorp.local
      LDAP_PORT: 10636
      LDAP_SSL: 'true'
      LDAP_DOMAIN: domain.com
      LDAP_BIND_USER: ad_bind_user
      LDAP_BIND_PASS: ad_bind_user_pass
      LDAP_DN_LOOKUP_BASE: DC=gopivotal,DC=com
      LDAP_GROUP_LOOKUP_BASE: ou=groups,dc=example,dc=com
      LDAP_USER_ACCESS_GROUP: CN=amqp-users,OU=Groups,OU=ORG,DC=ORG,DC=com
      LDAP_ADMIN_GROUP: CN=amqp-admins,OU=Groups,OU=ORG,DC=ORG,DC=com
    restart: always
volumes:
  mnesia:
    driver: local
```
* 5671: used by AMQP 0-9-1 and 1.0 clients with TLS
* 25672: used for inter-node and CLI tools communication (Erlang distribution server port)
* 4369: Erlang Port Mapper Daemon - a peer discovery service used by RabbitMQ nodes and CLI tools
* 15672: HTTP API clients, management UI and rabbitmqadmin (only if the management plugin is enabled)

Docker configuration for slave node:
```yaml
version: '2'
 
services:
  rabbit-node1:
    image: comrada/rabbitmq-cluster
    hostname: amqp2.company-site.com
    network_mode: host
    volumes:
      - /ssl/cacert.pem:/ssl/cacertfile.pem
      - /ssl/cert.pem:/ssl/certfile.pem
      - /ssl/key.pem:/ssl/keyfile.pem
      - mnesia:/var/lib/rabbitmq/mnesia
    environment:
      RABBITMQ_USE_LONGNAME: 'true'
      CLUSTER_WITH: amqp1.company-site.com
      ERLANG_COOKIE: abcdefg
      LDAP_SERVERS: ldap.eng.megacorp.local,ldap.eu.megacorp.local
      LDAP_PORT: 10636
      LDAP_SSL: 'true'
      LDAP_DOMAIN: domain.com
      LDAP_BIND_USER: ad_bind_user
      LDAP_BIND_PASS: ad_bind_user_pass
      LDAP_DN_LOOKUP_BASE: DC=gopivotal,DC=com
      LDAP_GROUP_LOOKUP_BASE: ou=groups,dc=example,dc=com
      LDAP_USER_ACCESS_GROUP: CN=amqp-users,OU=Groups,OU=ORG,DC=ORG,DC=com
      LDAP_ADMIN_GROUP: CN=amqp-admins,OU=Groups,OU=ORG,DC=ORG,DC=com
    ports:
      - 5672:5671
      - 4369:4369
      - 25672:25672
    restart: always
volumes:
  mnesia:
    driver: local
```
> **P.S.** Be careful when entering passwords in an environment variable, if they contain a dollar sign, it must be
> escaped with a dollar. For example, if we have a password `Qwerty$Password` it should be entered as `Qwerty$$Password`.

If your servers are connected by a local network or VLAN, then the configuration can be simplified a little
```yaml
version: '2'
 
services:
  rabbit-master:
    image: comrada/rabbitmq-cluster
    hostname: amqp1
    network_mode: host
    extra_hosts:
      - "amqp1:192.168.100.1"
      - "amqp2:192.168.100.2"
    volumes:
      - /ssl/cacert.pem:/ssl/cacertfile.pem
      - /ssl/cert.pem:/ssl/certfile.pem
      - /ssl/key.pem:/ssl/keyfile.pem
      - mnesia:/var/lib/rabbitmq/mnesia
    ports:
      - 5671:5671
      - 15672:15672
      - 4369:4369
      - 25672:25672
    environment:
      DEFAULT_USER: myuser
      DEFAULT_PASS: mypass
      CLUSTER_NAME: amqp-cluster-live
      ERLANG_COOKIE: abcdefg
      LDAP_SERVERs: ldap.eng.megacorp.local,ldap.eu.megacorp.local
      LDAP_PORT: 10636
      LDAP_SSL: 'true'
      LDAP_DOMAIN: domain.com
      LDAP_BIND_USER: ad_bind_user
      LDAP_BIND_PASS: ad_bind_user_pass
      LDAP_DN_LOOKUP_BASE: DC=gopivotal,DC=com
      LDAP_GROUP_LOOKUP_BASE: ou=groups,dc=example,dc=com
      LDAP_USER_ACCESS_GROUP: CN=amqp-users,OU=Groups,OU=ORG,DC=ORG,DC=com
      LDAP_ADMIN_GROUP: CN=amqp-admins,OU=Groups,OU=ORG,DC=ORG,DC=com
    restart: always
volumes:
  mnesia:
    driver: local
```

## Generation of SSL certificates
To work with a RabbitMQP cluster, you can generate your own server and client certificates. You need to have three
folders: `cacert`, `server` and `client`
### Generation of root key and certificate:
```shell script
cd cacert
openssl req -x509 -config openssl.cnf -newkey rsa:4096 -days 36524 -out cacert.pem -outform PEM -subj "/C=US/ST=CA/L=San Francisco/O=GitHub/CN=github.com/" -nodes
openssl x509 -in cacert.pem -out cacert.cer -outform DER
cd ../server
```
### Server key and request generation:
```shell script
openssl genrsa -out key.pem 4096
openssl req -new -key key.pem -out req.pem -outform PEM -subj "/C=US/ST=CA/L=San Francisco/O=GitHub/CN=github.com" -nodes
cd ../cacert
```
### Generating a server certificate, signing it with a root one and saving it in a trust store:
```shell script
openssl ca -config openssl.cnf -in ../server/req.pem -out ../server/cert.pem -notext -batch -extensions server_ca_extensions
cd ../server
openssl pkcs12 -export -out server_keycert.p12 -in cert.pem -inkey key.pem -passout pass:MySecretPassword
cd ../client
```
### Client Key and Request Generation:
```shell script
openssl genrsa -out key.pem 4096
openssl req -new -key key.pem -out req.pem -outform PEM -subj "/C=US/ST=CA/L=San Francisco/O=GitHub/CN=github.com" -nodes
cd ../cacert
```
### Generating a client certificate, signing it with a root one and saving it in a trust store:
```shell script
openssl ca -config openssl.cnf -in ../client/req.pem -out ../client/cert.pem -notext -batch -extensions client_ca_extensions
cd ../client
openssl pkcs12 -export -out keycert.p12 -in cert.pem -inkey key.pem -passout pass:MySecretPassword
```
