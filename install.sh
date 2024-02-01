#!/bin/bash
#set -euo pipefail
#set -x

CWD=$( cd "$( dirname "$0" )" && pwd )

#K8S_CLUSTER_EXTERNAL_DNS="k8s-apps.example.com"
K8S_CLUSTER_EXTERNAL_DNS="example.com"
K8S_CLUSTER_INTERNAL_DNS="cluster.local"
K8S_HDFS_NAME="hdfs"
K8S_HDFS_NAMESPACE="apache-hdfs"
K8S_AIRFLOW_NAME="airflow"
K8S_AIRFLOW_NAMESPACE="apache-airflow"
K8S_LIVY_NAME="livy"
K8S_LIVY_NAMESPACE="apache-livy"
K8S_SPARK_HISTORY_SERVER_NAME="spark-history-server"
K8S_SPARK_HISTORY_SERVER_NAMESPACE="apache-livy"
K8S_SPARK_THRIFT_SERVER_NAME="spark-thrift-server"
K8S_SPARK_THRIFT_SERVER_NAMESPACE="spark-thrift"
K8S_HIVE_NAME="hive-metastore"
K8S_HIVE_NAMESPACE="apache-hive"
HIVE_METASTORE_POSTGRESQL_PASSWORD="chAngE_Me"
K8S_DATAGRAM_NAME="datagram"
K8S_DATAGRAM_NAMESPACE="neoflex-datagram"
K8S_DATAGRAM_GIT_REPO="git/default"
K8S_DATAGRAM_GIT_DAGS_LOCATION="sources/WorkflowDeployment"
DATAGRAM_USERNAME="admin"
DATAGRAM_PASSWORD="admin"
DATAGRAM_POSTGRESQL_PASSWORD="chAngE_Me"
DATAGRAM_SHARED_LIBS_PATH="/datagram/sharedlibs"
SPARK_DRIVER_REQ_CPU="100m"
SPARK_DRIVER_LIMIT_CPU="1"
SPARK_EXECUTOR_REQ_CPU="100m"
SPARK_EXECUTOR_LIMIT_CPU="1"
SPARK_DRIVER_MEMORY="512M"
SPARK_EXECUTOR_MEMORY="512M"
K8S_EFK_NAME="efk"
K8S_EFK_NAMESPACE="logging"
K8S_EFK_KIBANA_NAME="kibana"
K8S_ADMINCONSOLE_NAME="admin-console"
K8S_ADMINCONSOLE_NAMESPACE="admin-console"
ADMINCONSOLE_POSTGRESQL_PASSWORD="postgres"


REQUIRED_CHARTS_PATHS=("${CWD}/helm/hdfs" "${CWD}/helm/livy" "${CWD}/helm/spark-history-server" "${CWD}/helm/datagram")

function check_binary {
  bin_name=$1
  if [ "$(which ${bin_name})x" == "x" ]
  then
    echo "Binary \"${bin_name}\" not found in PATH: $PATH"
    exit 1
  fi

}

function check_path {
  req_path=$1
  if [ ! -d "${req_path}" ]
  then
    echo "Directory \"${req_path}\" does not exist"
    exit 1
  fi
}

function check_requirements {
  for BIN in kubectl helm
  do
    check_binary "${BIN}"
  done

  for RP in ${REQUIRED_CHARTS_PATHS[@]}
  do
    check_path "${RP}"
  done
}

function wait_ingress {
  K8S_INGRESS_NAMESPACE=$1
  K8S_INGRESS_NAME=$2

  INGRESS_IP=""
  while [ "${INGRESS_IP}x" == "x" ]
  do
    sleep 5
    INGRESS_IP=$(kubectl -n ${K8S_INGRESS_NAMESPACE} get ingress ${K8S_INGRESS_NAME} -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    if [ "${INGRESS_IP}x" == "x" ]
    then
      sleep 5
    fi
  done
  echo "${INGRESS_IP}"
}

check_requirements

cat<<EOF

=======================
Installing Apache HDFS...
=======================

EOF

cat<<EOF
# Before you begin:
# 1. Mark namenodes and datanodes with following labels:
kubectl label nodes YOUR-CLUSTER-NODE hdfs-namenode-selector=hdfs-namenode
kubectl label nodes YOUR-CLUSTER-NODE hdfs-datanode-selector=hdfs-datanode
# 2. Create on these nodes paths "/hdfs-name" and "/hdfs-data":
mkdir /{hdfs-name,hdfs-data}
chmod 0777 /{hdfs-name,hdfs-data}

EOF

read -p "Press [ENTER] for continue..."

kubectl create namespace apache-hdfs
kubectl label ns apache-hdfs security.deckhouse.io/pod-policy=privileged

helm repo add bitnami https://charts.bitnami.com/bitnami

helm dependency build ./helm/hdfs/charts/hdfs-k8s

helm upgrade --install ${K8S_HDFS_NAME} ${CWD}/helm/hdfs/charts/hdfs-k8s \
  --namespace=${K8S_HDFS_NAMESPACE} --create-namespace \
  --set tags.ha="false" \
  --set tags.simple="true" \
  --set global.namenodeHAEnabled="false" \
  --set hdfs-simple-namenode-k8s.webuiIngress.enabled="true" \
  --set hdfs-simple-namenode-k8s.webuiIngress.hosts[0].host="${K8S_HDFS_NAME}-web.${K8S_CLUSTER_EXTERNAL_DNS}" \
  --set hdfs-simple-namenode-k8s.webuiIngress.hosts[0].paths[0].path="/" \
  --set hdfs-simple-namenode-k8s.webuiIngress.hosts[0].paths[0].pathType="Prefix" \
  --set global.clusterDns="${K8S_CLUSTER_INTERNAL_DNS}" \
  --set hdfs-simple-namenode-k8s.nodeSelector.hdfs-namenode-selector=hdfs-namenode \
  --set hdfs-datanode-k8s.nodeSelector.hdfs-datanode-selector=hdfs-datanode \

cat<<EOF

=======================
Wait until Datanode is up...
=======================

EOF

DNRN=""
while [ "${DNRN}x" = "x" ]
do
  echo -n "."
  sleep 5
  DNRN=$(kubectl -n ${K8S_HDFS_NAMESPACE} get pods --no-headers -l app.kubernetes.io/name=hdfs-datanode,app.kubernetes.io/instance=${K8S_HDFS_NAME} | grep -E '1\/\w\ *Running')
  echo -n "="
done

cat<<EOF

${DNRN}
EOF

cat<<EOF

=======================
Create HDFS's folders for Spark...
=======================

EOF

HDFS_CLIENT_POD=""
while [ "${HDFS_CLIENT_POD}x" == "x" ]
do
  HDFS_CLIENT_POD=$(kubectl -n ${K8S_HDFS_NAMESPACE} get pods --no-headers -l app.kubernetes.io/name=hdfs-client,app.kubernetes.io/instance=${K8S_HDFS_NAME} | grep -E '1\/\w\ *Running' | awk '{print $1}')
  sleep 5
done

kubectl -n ${K8S_HDFS_NAMESPACE} exec ${HDFS_CLIENT_POD} -- hadoop fs -mkdir -p /shared/spark-logs
kubectl -n ${K8S_HDFS_NAMESPACE} exec ${HDFS_CLIENT_POD} -- hadoop fs -mkdir -p /tmp
kubectl -n ${K8S_HDFS_NAMESPACE} exec ${HDFS_CLIENT_POD} -- hadoop fs -chmod 0777 /shared/spark-logs
kubectl -n ${K8S_HDFS_NAMESPACE} exec ${HDFS_CLIENT_POD} -- hadoop fs -chmod 0777 /tmp
kubectl -n ${K8S_HDFS_NAMESPACE} exec ${HDFS_CLIENT_POD} -- hadoop fs -ls /

cat<<EOF



=======================
Installing Neoflex Datagram Metaserver with PostgreSQL...
=======================

EOF


helm repo add bitnami https://charts.bitnami.com/bitnami 

helm dependency build ${CWD}/helm/datagram

helm upgrade --install ${K8S_DATAGRAM_NAME} ${CWD}/helm/datagram --namespace ${K8S_DATAGRAM_NAMESPACE} --create-namespace \
  --set postgresql.auth.password="${DATAGRAM_POSTGRESQL_PASSWORD}" \
  --set ingress.enabled="true" \
  --set ingress.hosts[0].host="${K8S_DATAGRAM_NAME}.${K8S_CLUSTER_EXTERNAL_DNS}" \
  --set ingress.hosts[0].paths[0].path="/" \
  --set ingress.hosts[0].paths[0].pathType="Prefix"

cat<<EOF

=======================
Add Neoflex Datagram's shared libs for Spark...
=======================

EOF

SHARED_LIBS_PATH_PARRENT_DIR=$(echo "${DATAGRAM_SHARED_LIBS_PATH}" | awk -F'/' '{print $2}')

CLIENT_POD=$(kubectl -n ${K8S_HDFS_NAMESPACE} get pods --no-headers -l app.kubernetes.io/name=hdfs-client,app.kubernetes.io/instance=${K8S_HDFS_NAME} -o name)

kubectl -n ${K8S_HDFS_NAMESPACE} exec ${CLIENT_POD} -- hadoop fs -mkdir -p ${DATAGRAM_SHARED_LIBS_PATH}
kubectl -n ${K8S_HDFS_NAMESPACE} exec ${CLIENT_POD} -- hadoop fs -chmod -R 0777 /${SHARED_LIBS_PATH_PARRENT_DIR}
kubectl -n ${K8S_HDFS_NAMESPACE} exec ${CLIENT_POD} -- hadoop fs -ls /


# Try to resolve location
HDFS_NAMENODE_POD="$(kubectl -n ${K8S_HDFS_NAMESPACE} get pods --no-headers -l app.kubernetes.io/name=hdfs-namenode,app.kubernetes.io/instance=${K8S_HDFS_NAME} -o jsonpath='{.items[0].metadata.name}')"
HDFS_NAMENODE_SERVICE="$(kubectl -n ${K8S_HDFS_NAMESPACE} get services --no-headers -l app.kubernetes.io/name=hdfs-namenode,app.kubernetes.io/instance=${K8S_HDFS_NAME} -o jsonpath='{.items[0].metadata.name}')"
HDFS_NAMENODE_ADDRESS="${HDFS_NAMENODE_POD}.${HDFS_NAMENODE_SERVICE}.${K8S_HDFS_NAMESPACE}.svc.${K8S_CLUSTER_INTERNAL_DNS}"
PING_RESULT=""

echo $HDFS_NAMENODE_ADDRESS

while [ -z "${PING_RESULT}" ]
do
  LOCATION_HOSTNAME="$(curl --silent --include --request PUT --url "http://${HDFS_NAMENODE_ADDRESS}:50070/webhdfs/v1/tmp/testfile?op=CREATE" | grep -E '^Location:' | awk '{print $2}' | sed -e 's~http://~~g' -e 's~:.*~~g' )"
  echo $LOCATION_HOSTNAME
  PING_RESULT=$(ping -c 4 -q ${LOCATION_HOSTNAME} | grep 'packet loss')
  if [ -z "${PING_RESULT}" ]
  then
    K8S_NODE_ADDRESS="$(kubectl get nodes ${LOCATION_HOSTNAME} -o jsonpath='{.status.addresses[0].address}')"
    cat<<EOF
# Hostname "${LOCATION_HOSTNAME}" of k8s cluster's node is not resolved.
# Add record with pair IP-address and hostname to /etc/hosts for example:
${K8S_NODE_ADDRESS} ${LOCATION_HOSTNAME}
EOF
    read -p "Press [ENTER] for continue..."
  fi
done

DGTMP=$(mktemp -d -t dg-git-tmp-XXXXXXXXXX)

git clone https://${GITHUB_TOKEN}@github.com/neoflex-consulting/datagram ${DGTMP}

EXTRALIB_BASE="${DGTMP}/bd-runtime/bd-base/extralib/"

HDFS_NAMENODE_POD="$(kubectl -n ${K8S_HDFS_NAMESPACE} get pods --no-headers -l app.kubernetes.io/name=hdfs-namenode,app.kubernetes.io/instance=${K8S_HDFS_NAME} -o jsonpath='{.items[0].metadata.name}')"
HDFS_NAMENODE_SERVICE="$(kubectl -n ${K8S_HDFS_NAMESPACE} get services --no-headers -l app.kubernetes.io/name=hdfs-namenode,app.kubernetes.io/instance=${K8S_HDFS_NAME} -o jsonpath='{.items[0].metadata.name}')"
HDFS_NAMENODE_ADDRESS="${HDFS_NAMENODE_POD}.${HDFS_NAMENODE_SERVICE}.${K8S_HDFS_NAMESPACE}.svc.${K8S_CLUSTER_INTERNAL_DNS}"

for EXTRALIB_JAR in $(find "${EXTRALIB_BASE}" -type f)
do
  LIB_NAME="$(basename ${EXTRALIB_JAR})"

  cat<<EOF
Copy "${LIB_NAME}" to HDFS...
EOF

  HDFS_LOCATION="$(curl --silent --include --request PUT --url "http://${HDFS_NAMENODE_ADDRESS}:50070/webhdfs/v1${DATAGRAM_SHARED_LIBS_PATH}/${LIB_NAME}?op=CREATE" | grep -oP 'Location: \K.*' | sed -e 's/\r//g')"

  curl --silent --request PUT --upload-file "${EXTRALIB_JAR}" --url "${HDFS_LOCATION}" &>/dev/null
done

rm -rf ${DGTMP}


cat<<EOF

=======================
Wait until Datagram is up...
=======================

EOF

DNRN=""
while [ "${DNRN}x" = "x" ]
do
  echo -n "."
  sleep 5
  DNRN=$(kubectl -n ${K8S_DATAGRAM_NAMESPACE} get pods --no-headers -l app.kubernetes.io/name=${K8S_DATAGRAM_NAME},app.kubernetes.io/instance=${K8S_DATAGRAM_NAME} | grep -E '1\/\w\ *Running')
  echo -n "="
done

cat<<EOF

${DNRN}
EOF

cat<<EOF
=======================
Add Livy and Airflow connections to Datagram...
=======================
EOF

curl --user $DATAGRAM_USERNAME:$DATAGRAM_PASSWORD --request POST --header "Content-Type: application/json" --data-binary @- "http://${K8S_DATAGRAM_NAME}.${K8S_DATAGRAM_NAMESPACE}.svc.${K8S_CLUSTER_INTERNAL_DNS}/api/teneo/rt.LivyServer" << EOD
{
"mode": "cluster",
"_type_": "rt.LivyServer",
"isDefault": true,
"name": "k8s_livy",
"http": "http://${K8S_LIVY_NAME}.${K8S_LIVY_NAMESPACE}.svc.${K8S_CLUSTER_INTERNAL_DNS}:8998/",
"webhdfs": "http://${HDFS_NAMENODE_ADDRESS}:50070/webhdfs/v1",
"user": "root",
"home": "/user",
"master": "k8s://http://localhost:8443"
}
EOD
EOD

curl --user $DATAGRAM_USERNAME:$DATAGRAM_PASSWORD --request POST --header "Content-Type: application/json" --data-binary @- "http://${K8S_DATAGRAM_NAME}.${K8S_DATAGRAM_NAMESPACE}.svc.${K8S_CLUSTER_INTERNAL_DNS}/api/teneo/rt.Airflow"<<EOD
{
"isKerberosEnabled": false,
"livyConnId": "livy_svc",
"webhdfs": "http://${HDFS_NAMENODE_ADDRESS}:50070/webhdfs/v1",
"apiPassword": "admin",
"apiUser": "admin",
"home": "/user",
"_type_": "rt.Airflow",
"isDefault": true,
"name": "airflow",
"http": "http://${K8S_AIRFLOW_NAME}-webserver.${K8S_AIRFLOW_NAMESPACE}.svc.${K8S_CLUSTER_INTERNAL_DNS}:8080",
"runOnLivy": true,
"user": "root"
}

EOD
EOD


cat<<EOF


=======================
Installing Apache Airflow...
=======================

EOF

helm repo add apache-airflow https://airflow.apache.org

helm upgrade --install ${K8S_AIRFLOW_NAME} apache-airflow/airflow --version 1.7.0 \
  --namespace ${K8S_AIRFLOW_NAMESPACE} --create-namespace \
  --set config.webserver.expose_config="true" \
  --set ingress.web.enabled="true" \
  --set ingress.web.hosts[0].name="${K8S_AIRFLOW_NAME}.${K8S_CLUSTER_EXTERNAL_DNS}" \
  --set dags.gitSync.enabled="true" \
  --set dags.gitSync.repo="http://${K8S_DATAGRAM_NAME}.${K8S_DATAGRAM_NAMESPACE}.svc.${K8S_CLUSTER_INTERNAL_DNS}/${K8S_DATAGRAM_GIT_REPO}" \
  --set dags.gitSync.branch="master" \
  --set dags.gitSync.subPath="${K8S_DATAGRAM_GIT_DAGS_LOCATION}" \
  --set dags.gitSync.credentialsSecret="airflow-git-creds" \
  --set config.api.auth_backends="airflow.api.auth.backend.basic_auth" \
  --values ${CWD}/helm/airflow/override.yaml \
  --set images.airflow.repository=neoflexdatagram/k8s-airflow \
  --set images.airflow.tag=2.4.1 \
  --set labels."app\.kubernetes\.io\/instance"=${K8S_AIRFLOW_NAME} \
  --set labels."app\.kubernetes\.io\/managed-by"="Helm"

#  --set "extraSecrets.airflow_my_secret.stringData=AIRFLOW_CONN_OTHER: 'other_conn'
#          AIRFLOW_CONN_OTHER1: 'other_conn'" \



cat<<EOF

=======================
Create Livy connection for Airflow...
=======================

EOF

AIRFLOW_WORKER_POD=""
while [ "${AIRFLOW_WORKER_POD}x" == "x" ]
do
  AIRFLOW_WORKER_POD=$(kubectl -n ${K8S_AIRFLOW_NAMESPACE} get pods --no-headers -l component=worker,release=${K8S_AIRFLOW_NAME} | grep -m 1 'Running' | awk '{print $1}')
  sleep 5
done

kubectl -n ${K8S_AIRFLOW_NAMESPACE} exec ${AIRFLOW_WORKER_POD} -c worker -- airflow connections add 'livy_svc' --conn-uri "livy://${K8S_LIVY_NAME}.${K8S_LIVY_NAMESPACE}.svc.${K8S_CLUSTER_INTERNAL_DNS}:8998"

cat<<EOF

=======================
Installing Apache Livy...
=======================

EOF

helm upgrade --install ${K8S_LIVY_NAME} ${CWD}/helm/livy --namespace ${K8S_LIVY_NAMESPACE} --create-namespace \
  --set sparkDefaultsConfig."spark\.kubernetes\.file\.upload\.path"="hdfs://${K8S_HDFS_NAME}-namenode-0.${K8S_HDFS_NAME}-namenode.${K8S_HDFS_NAMESPACE}.svc.${K8S_CLUSTER_INTERNAL_DNS}:8020/tmp/" \
  --set sparkDefaultsConfig."spark\.eventLog\.enabled"="true" \
  --set sparkDefaultsConfig."spark\.eventLog\.dir"="hdfs://${K8S_HDFS_NAME}-namenode-0.${K8S_HDFS_NAME}-namenode.${K8S_HDFS_NAMESPACE}.svc.${K8S_CLUSTER_INTERNAL_DNS}:8020/shared/spark-logs" \
  --set sparkDefaultsConfig."spark\.driver\.extraClassPath"="${DATAGRAM_SHARED_LIBS_PATH}/*" \
  --set sparkDefaultsConfig."spark\.executor\.extraclasspath"="${DATAGRAM_SHARED_LIBS_PATH}/*" \
  --set sparkDefaultsConfig."spark\.kubernetes\.driverEnv\.HADOOP_USER_NAME"="nobody" \
  --set sparkDefaultsConfig."spark\.kubernetes\.driverEnv\.SPARK_USER"="nobody" \
  --set sparkDefaultsConfig."spark\.hadoop\.fs\.defaultFS"="hdfs://${K8S_HDFS_NAME}-namenode-0.${K8S_HDFS_NAME}-namenode.${K8S_HDFS_NAMESPACE}.svc.${K8S_CLUSTER_INTERNAL_DNS}:8020" \
  --set sparkDefaultsConfig."spark\.kubernetes\.driver\.request\.cores"="${SPARK_DRIVER_REQ_CPU}" \
  --set sparkDefaultsConfig."spark\.kubernetes\.driver\.limit\.cores"="${SPARK_DRIVER_LIMIT_CPU}" \
  --set sparkDefaultsConfig."spark\.kubernetes\.executor\.request\.cores"="${SPARK_EXECUTOR_REQ_CPU}" \
  --set sparkDefaultsConfig."spark\.kubernetes\.executor\.limit\.cores"="${SPARK_EXECUTOR_LIMIT_CPU}" \
  --set sparkDefaultsConfig."spark\.driver\.memory"="${SPARK_DRIVER_MEMORY}" \
  --set sparkDefaultsConfig."spark\.executor\.memory"="${SPARK_EXECUTOR_MEMORY}" \
  --set sparkDefaultsConfig."spark\.kubernetes\.driverEnv\.HDFS_EXTRA_CLASSPATH"="http://${HDFS_NAMENODE_ADDRESS}:50070/webhdfs/v1${DATAGRAM_SHARED_LIBS_PATH}" \
  --set sparkDefaultsConfig."spark\.executorEnv\.HDFS_EXTRA_CLASSPATH"="http://${HDFS_NAMENODE_ADDRESS}:50070/webhdfs/v1${DATAGRAM_SHARED_LIBS_PATH}" \
  --set hadoopConfig.coreSite."fs\.defaultFS"="hdfs://${K8S_HDFS_NAME}-namenode-0.${K8S_HDFS_NAME}-namenode.${K8S_HDFS_NAMESPACE}.svc.${K8S_CLUSTER_INTERNAL_DNS}:8020" \
  --set hadoopConfig.hiveSite."hive\.metastore\.uris"="thrift://${K8S_HIVE_NAME}.${K8S_HIVE_NAMESPACE}.svc.${K8S_CLUSTER_INTERNAL_DNS}:9083" \
  --set hadoopConfig.hiveSite."hive\.metastore\.warehouse\.dir"="hdfs://${K8S_HDFS_NAME}-namenode-0.${K8S_HDFS_NAME}-namenode.${K8S_HDFS_NAMESPACE}.svc.${K8S_CLUSTER_INTERNAL_DNS}:8020" \
  --set ingress.enabled="true" \
  --set ingress.hosts[0].host="${K8S_LIVY_NAME}.${K8S_CLUSTER_EXTERNAL_DNS}" \
  --set ingress.hosts[0].paths[0].path="/" \
  --set ingress.hosts[0].paths[0].pathType="Prefix"

cat<<EOF

=======================
Installing Apache Spark History Server...
=======================

EOF

helm upgrade --install ${K8S_SPARK_HISTORY_SERVER_NAME} ${CWD}/helm/spark-history-server --namespace ${K8S_SPARK_HISTORY_SERVER_NAMESPACE} --create-namespace \
  --set logPath="hdfs://${K8S_HDFS_NAME}-namenode-0.${K8S_HDFS_NAME}-namenode.${K8S_HDFS_NAMESPACE}.svc.${K8S_CLUSTER_INTERNAL_DNS}:8020/shared/spark-logs" \
  --set ingress.enabled="true" \
  --set ingress.hosts[0].host="${K8S_SPARK_HISTORY_SERVER_NAME}.${K8S_CLUSTER_EXTERNAL_DNS}" \
  --set ingress.hosts[0].paths[0].path="/" \
  --set ingress.hosts[0].paths[0].pathType="Prefix"



cat<<EOF

=======================
Installing Apache Hive...
=======================

EOF
helm repo add bitnami https://charts.bitnami.com/bitnami 

helm dependency build ${CWD}/helm/hive-metastore


helm upgrade --install ${K8S_HIVE_NAME} ${CWD}/helm/hive-metastore --namespace ${K8S_HIVE_NAMESPACE} --create-namespace \
  --set postgresql.auth.password="${HIVE_METASTORE_POSTGRESQL_PASSWORD}" \
#  --set ingress.enabled="true" \
#  --set ingress.hosts[0].host="${K8S_HIVE_NAME}.${K8S_CLUSTER_EXTERNAL_DNS}" \
#  --set ingress.hosts[0].paths[0].path="/" \
#  --set ingress.hosts[0].paths[0].pathType="Prefix"

APACHE_HIVE_METASTORE_POD=""
while [ "${APACHE_HIVE_METASTORE_POD}x" == "x" ]
do
  APACHE_HIVE_METASTORE_POD=$(kubectl -n ${K8S_HIVE_NAMESPACE} get pods --no-headers -l app=${K8S_HIVE_NAME} | grep -m 1 'Running' | awk '{print $1}')
  sleep 5
done

cat<<EOF

=======================
Installing Apache Spark Thrift Server...
=======================

EOF

helm upgrade --install ${K8S_SPARK_THRIFT_SERVER_NAME} ${CWD}/helm/spark-thrift-server --namespace ${K8S_SPARK_THRIFT_SERVER_NAMESPACE} --create-namespace \
  --set logPath="hdfs://${K8S_HDFS_NAME}-namenode-0.${K8S_HDFS_NAME}-namenode.${K8S_HDFS_NAMESPACE}.svc.${K8S_CLUSTER_INTERNAL_DNS}:8020/shared/spark-logs" \
  --set hadoopConfig.hiveSite."fs\.defaultFS"="hdfs://${K8S_HDFS_NAME}-namenode-0.${K8S_HDFS_NAME}-namenode.${K8S_HDFS_NAMESPACE}.svc.${K8S_CLUSTER_INTERNAL_DNS}:8020" \
  --set hadoopConfig.hiveSite."hive\.metastore\.uris"="thrift://${K8S_HIVE_NAME}.${K8S_HIVE_NAMESPACE}.svc.${K8S_CLUSTER_INTERNAL_DNS}:9083" \
  --set hadoopConfig.hiveSite."hive\.metastore\.warehouse\.dir"="hdfs://${K8S_HDFS_NAME}-namenode-0.${K8S_HDFS_NAME}-namenode.${K8S_HDFS_NAMESPACE}.svc.${K8S_CLUSTER_INTERNAL_DNS}:8020" \
  --set ingress.enabled="true" \
  --set ingress.hosts[0].host="${K8S_SPARK_THRIFT_SERVER_NAME}.${K8S_CLUSTER_EXTERNAL_DNS}" \
  --set ingress.hosts[0].paths[0].path="/" \
  --set ingress.hosts[0].paths[0].pathType="Prefix"



cat<<EOF

=======================
Installing Elasticsearch...
=======================

EOF

kubectl create namespace logging
kubectl label ns logging security.deckhouse.io/pod-policy=privileged

helm upgrade --install ${K8S_EFK_NAME} bitnami/elasticsearch --namespace ${K8S_EFK_NAMESPACE} --create-namespace \
  --set global.kibanaEnabled="true" \
  --set kibana.ingress.enabled="true" \
  --set kibana.ingress.hostname="${K8S_EFK_KIBANA_NAME}.${K8S_CLUSTER_EXTERNAL_DNS}" \
  --set kibana.ingress.pathType="Prefix"

helm upgrade --install ${K8S_EFK_NAME}-fluentd bitnami/fluentd --namespace ${K8S_EFK_NAMESPACE} --create-namespace \
  --values ${CWD}/helm/efk/override.yaml 

ELASTIC_FLUENTD_POD=""
while [ "${ELASTIC_FLUENTD_POD}x" == "x" ]
do
  ELASTIC_FLUENTD_POD=$(kubectl -n ${K8S_EFK_NAMESPACE} get pods --no-headers -l app.kubernetes.io/name=fluentd | grep -m 1 'Running' | awk '{print $1}')
  sleep 5
done

cat<<EOF

=======================
Installing Neoflex Datagram admin-console with PostgreSQL...
=======================

EOF


helm dependency build ${CWD}/helm/ac

helm upgrade --install ${K8S_ADMINCONSOLE_NAME} ${CWD}/helm/ac --namespace ${K8S_ADMINCONSOLE_NAMESPACE} --create-namespace \
  --set postgresql.auth.password="${ADMINCONSOLE_POSTGRESQL_PASSWORD}" \
  --set ingress.enabled="true" \
  --set ingress.hosts[0].host="ac.${K8S_CLUSTER_EXTERNAL_DNS}" \
  --set ingress.hosts[0].paths[0].path="/" \
  --set ingress.hosts[0].paths[0].pathType="Prefix"

ADMINCONSOLE_POD=""
while [ "${ADMINCONSOLE_POD}x" == "x" ]
do
  ADMINCONSOLE_POD=$(kubectl -n ${K8S_ADMINCONSOLE_NAMESPACE} get pods --no-headers -l app.kubernetes.io/name=${K8S_ADMINCONSOLE_NAME} | grep -m 1 'Running' | awk '{print $1}')
  sleep 5
done

cat<<EOF

=======================
Wait until HDFS's WebUI ingress gets it's IPs...
=======================

EOF

HDFS_WEB_IP="$(wait_ingress ${K8S_HDFS_NAMESPACE} ${K8S_HDFS_NAME}-namenode)"

cat<<EOF

=======================
Wait until Livy's ingress gets it's IPs...
=======================

EOF

LIVY_WEB_IP="$(wait_ingress ${K8S_LIVY_NAMESPACE} ${K8S_LIVY_NAME})"

cat<<EOF

=======================
Wait until Spark History Server's ingress gets it's IPs...
=======================

EOF

SHS_WEB_IP="$(wait_ingress ${K8S_SPARK_HISTORY_SERVER_NAMESPACE} ${K8S_SPARK_HISTORY_SERVER_NAME})"

cat<<EOF

=======================
Wait until Neoflex Datagram's ingress gets it's IPs...
=======================

EOF

NDG_WEB_IP="$(wait_ingress ${K8S_DATAGRAM_NAMESPACE} ${K8S_DATAGRAM_NAME})"

cat<<EOF


# "hosts" file path on Linux: /etc/hosts
# "hosts" file path on Windows: C:\Windows\System32\drivers\etc\hosts
#
# For DNS resolution add following strings inside "hosts" file on your computer:
${HDFS_WEB_IP}  ${K8S_HDFS_NAME}-web.${K8S_CLUSTER_EXTERNAL_DNS}
${LIVY_WEB_IP}  ${K8S_LIVY_NAME}.${K8S_CLUSTER_EXTERNAL_DNS}
${SHS_WEB_IP}  ${K8S_SPARK_HISTORY_SERVER_NAME}.${K8S_CLUSTER_EXTERNAL_DNS}
${NDG_WEB_IP}  ${K8S_DATAGRAM_NAME}.${K8S_CLUSTER_EXTERNAL_DNS}

EOF
