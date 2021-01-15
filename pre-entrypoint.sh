#!/bin/bash

##
# Checks all required environment variables, dies if something missed
check_all_required_variables() {
  if
    [[ -z ${LDAP_BIND_USER} ]] || [[ -z ${LDAP_BIND_PASS} ]] || [[ -z ${LDAP_ADMIN_GROUP} ]] || \
    [[ -z ${LDAP_DN_LOOKUP_BASE} ]] || [[ -z ${LDAP_GROUP_LOOKUP_BASE} ]] || [[ -z ${LDAP_USER_ACCESS_GROUP} ]] || \
    [[ -z ${LDAP_SERVERS} ]] || [[ -z ${LDAP_PORT} ]] || [[ -z ${LDAP_SSL} ]] || [[ -z ${LDAP_DOMAIN} ]]
  then
    echo "You must provide all the necessary variables for integration with LDAP. See documentation."
    exit 0
  fi
}

##
# Split array of LDAP servers, add quotes and join again
# Example: ldap1.server.com,ldap2.server.com turns into "ldap1.server.com","ldap2.server.com"
add_quotes_to_hosts() {
  RES=""
  for i in $(echo "$LDAP_SERVERS" | tr "," "\n"); do
    RES="${RES},\"$i\""
  done
  LDAP_SERVERS="${RES:1}"
}

##
# To work with LDAP, we need the user for binding and some other parameters passed through environment variables
insert_ldap_credentials() {
  CONFIG_FILE=/etc/rabbitmq/rabbitmq.config
  cp /etc/rabbitmq/rabbitmq.config.tpl ${CONFIG_FILE}
  chmod u+rw /etc/rabbitmq/rabbitmq.config
  add_quotes_to_hosts
  rpl -q "<LDAP_SERVERS>" "${LDAP_SERVERS}" ${CONFIG_FILE}
  rpl -q "<LDAP_PORT>" "${LDAP_PORT}" ${CONFIG_FILE}
  rpl -q "<LDAP_SSL>" "${LDAP_SSL}" ${CONFIG_FILE}
  rpl -q "<LDAP_BIND_USER>" "${LDAP_BIND_USER}" ${CONFIG_FILE}
  rpl -q "<LDAP_BIND_PASS>" "${LDAP_BIND_PASS}" ${CONFIG_FILE}
  rpl -q "<LDAP_DN_LOOKUP_BASE>" "${LDAP_DN_LOOKUP_BASE}" ${CONFIG_FILE}
  rpl -q "<LDAP_GROUP_LOOKUP_BASE>" "${LDAP_GROUP_LOOKUP_BASE}" ${CONFIG_FILE}
  rpl -q "<LDAP_USER_ACCESS_GROUP>" "${LDAP_USER_ACCESS_GROUP}" ${CONFIG_FILE}
  rpl -q "<LDAP_ADMIN_GROUP>" "${LDAP_ADMIN_GROUP}" ${CONFIG_FILE}
  rpl -q "<LDAP_DOMAIN>" "${LDAP_DOMAIN}" ${CONFIG_FILE}
}

##
# To work in a cluster we need a file with cookie, create it and write a cookie from the environment variable into there
create_cookie_file() {
  cookieFile='/var/lib/rabbitmq/.erlang.cookie'
  touch "$cookieFile"
  if [[ "$ERLANG_COOKIE" ]]; then
    echo "$ERLANG_COOKIE" >"$cookieFile"
  else
    echo "ERLANGCOOKIE" >"$cookieFile"
  fi
  chmod 400 "$cookieFile"
  chown rabbitmq:rabbitmq "$cookieFile"
}

##
# To increase security, we create a file with the ephemeral Diffie–Hellman key
# http://ezgr.net/increasing-security-erlang-ssl-cowboy/
create_dh_key() {
  FILE=/ssl/dh-params.pem
  if [[ ! -f "$FILE" ]]; then
    openssl dhparam -out ${FILE} 2048
  fi
}

check_all_required_variables
create_cookie_file
create_dh_key
insert_ldap_credentials

chown -R rabbitmq:rabbitmq /var/lib/rabbitmq
exec gosu rabbitmq docker-entrypoint.sh "$@"
