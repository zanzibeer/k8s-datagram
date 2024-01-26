FROM docker.io/apache/spark:v3.1.3

USER root

RUN apt-get update && \
    apt-get install -y curl jq && \
    rm -rf /var/lib/apt/lists/*

ADD entrypoint.sh /opt/entrypoint.sh
ADD --chmod=655 YandexCA.crt /usr/local/share/ca-certificates/Yandex/YandexCA.crt

USER ${spark_uid}