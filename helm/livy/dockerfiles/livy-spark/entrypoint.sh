#!/bin/bash
set -x

if [ "$K8S_API_HOST" ]
then
  sed -i -e "s~# livy.spark.master =.*~livy.spark.master = k8s://http://${K8S_API_HOST}:8443~" /opt/livy/conf/livy.conf
  sed -i -e "s/# livy.spark.deploy-mode =.*/livy.spark.deploy-mode = cluster/" /opt/livy/conf/livy.conf
  sed -i -e "s~# livy.file.local-dir-whitelist =.*~livy.file.local-dir-whitelist = /opt/.livy-sessions/~" /opt/livy/conf/livy.conf
  sed -i -e "s/# livy.server.session.state-retain.sec =.*/livy.server.session.state-retain.sec = 8h/" /opt/livy/conf/livy.conf
fi

sed -i -e "s/# livy.rsc.rpc.server.address =.*/livy.rsc.rpc.server.address = $(hostname -i)/" /opt/livy/conf/livy-client.conf

exec "$@"
