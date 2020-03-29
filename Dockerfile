FROM rabbitmq:3.8-management

MAINTAINER Pavel Lobyrin <pavel@lobyrin.ru>

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y rpl

RUN echo 'y' | rabbitmq-plugins list && \
    echo 'y' | rabbitmq-plugins enable --offline \
    rabbitmq_management_agent \
    rabbitmq_auth_backend_ldap \
    rabbitmq_auth_backend_cache \
    rabbitmq_prometheus

ADD rabbitmq.config /etc/rabbitmq/rabbitmq.config.tpl
ADD start-cluster /usr/local/bin/
ADD pre-entrypoint.sh /usr/local/bin/
RUN chmod a+x /usr/local/bin/start-cluster /usr/local/bin/pre-entrypoint.sh

ENTRYPOINT ["pre-entrypoint.sh"]

EXPOSE 15692

CMD ["start-cluster"]
