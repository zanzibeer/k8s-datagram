FROM maven:3-jdk-8 as builder

RUN apt update -y && \
    apt upgrade -y && \
    DEBIAN_FRONTEND=noninteractive apt -yq install python3-pip krb5-config libkrb5-dev git python-is-python3 && \
    python3 -m pip install setuptools cloudpickle requests requests-kerberos flake8 flaky pytest

RUN git clone https://github.com/apache/incubator-livy.git

ADD pom.xml /incubator-livy/pom.xml

RUN cd /incubator-livy && \
    mvn package -B -V -e  \
        -DskipTests \
        -DskipITs \
        -Pspark-3.1 \
        -Dmaven.javadoc.skip=true && \
    unzip -qq "/incubator-livy/assembly/target/apache-livy-0.8.0-incubating-SNAPSHOT-bin.zip" -d /opt

FROM java:8-alpine

ENV SPARK_HOME=/opt/spark
ENV LIVY_HOME=/opt/livy
ENV SPARK_USER=spark

COPY --from=builder /opt/apache-livy-0.8.0-incubating-SNAPSHOT-bin /opt/apache-livy-0.8.0-incubating-SNAPSHOT-bin

RUN apk update && \
    apk upgrade && \
    rm -rf /var/cache/apk/*

RUN apk add --update --no-cache openssl curl bash && \
    curl -ks https://archive.apache.org/dist/spark/spark-3.1.3/spark-3.1.3-bin-hadoop3.2.tgz | tar -xz -C /opt && \
    ln -s /opt/spark-3.1.3-bin-hadoop3.2 /opt/spark && \
    ln -s /opt/apache-livy-0.8.0-incubating-SNAPSHOT-bin /opt/livy && \
    mkdir /opt/livy/logs && \
    cp /opt/livy/conf/log4j.properties.template /opt/livy/conf/log4j.properties && \
    cp /opt/livy/conf/livy.conf.template /opt/livy/conf/livy.conf && \
    cp /opt/livy/conf/livy-client.conf.template /opt/livy/conf/livy-client.conf

ADD entrypoint.sh /opt/entrypoint.sh

ENV PATH="/opt/livy/bin:${PATH}"

EXPOSE 8998

ENTRYPOINT ["/opt/entrypoint.sh"]
CMD ["livy-server"]