# !/bin/bash
#set -euo pipefail
#set -x

CWD=$( cd "$( dirname "$0" )" && pwd )

#K8S_CLUSTER_EXTERNAL_DNS="k8s-apps.example.com"
K8S_CLUSTER_EXTERNAL_DNS="ru-central1.internal"
K8S_CLUSTER_INTERNAL_DNS="cluster.local"
K8S_HDFS_NAME="hdfs"
K8S_HDFS_NAMESPACE="apache-hdfs"
HDFS_NAMENODE_SERVICE="${K8S_HDFS_NAME}-namenode.${K8S_HDFS_NAMESPACE}.svc.${K8S_CLUSTER_INTERNAL_DNS}"
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


function check_file {
  req_file=$1
  if [ ! -f "${req_file}" ]
  then
    echo "File \"${req_file}\" does not exist"
    exit 1
  fi
}

check_file $2


case $1 in 
  hdfs)
    cat<<EOF

    =======================
    Updating Apache HDFS...
    =======================

EOF

    helm repo add bitnami https://charts.bitnami.com/bitnami

    helm dependency build ./helm/hdfs/charts/hdfs-k8s

    helm upgrade ${K8S_HDFS_NAME} ${CWD}/helm/hdfs/charts/hdfs-k8s \
      --namespace=${K8S_HDFS_NAMESPACE}  \
      --values $2 \
      --reuse-values
    ;;

  datagram)
    cat<<EOF

    =======================
    Updating Neoflex Datagram Metaserver with PostgreSQL...
    =======================

EOF


    helm repo add bitnami https://charts.bitnami.com/bitnami 

    helm dependency build ${CWD}/helm/datagram

    helm upgrade ${K8S_DATAGRAM_NAME} ${CWD}/helm/datagram --namespace ${K8S_DATAGRAM_NAMESPACE} \
      --values $2 \
      --reuse-values

    ;;

  airflow)

cat<<EOF

=======================
Updating Apache Airflow...
=======================

EOF

helm repo add apache-airflow https://airflow.apache.org

helm upgrade ${K8S_AIRFLOW_NAME} apache-airflow/airflow --namespace ${K8S_AIRFLOW_NAMESPACE}  \
  --values $2 \
  --reuse-values

    ;;

  livy)

cat<<EOF

=======================
Updating Apache Livy...
=======================

EOF

helm upgrade ${K8S_LIVY_NAME} ${CWD}/helm/livy --namespace ${K8S_LIVY_NAMESPACE}  \
  --values $2 \
  --reuse-values
  
  ;;

  spark-history)
cat<<EOF

=======================
Updating Apache Spark History Server...
=======================

EOF

helm upgrade ${K8S_SPARK_HISTORY_SERVER_NAME} ${CWD}/helm/spark-history-server --namespace ${K8S_SPARK_HISTORY_SERVER_NAMESPACE} \
  --values $2 \
  --reuse-values

    ;;

  hive)
cat<<EOF

=======================
Updating Apache Hive...
=======================

EOF
helm repo add bitnami https://charts.bitnami.com/bitnami 

helm dependency build ${CWD}/helm/hive-metastore


helm upgrade  ${K8S_HIVE_NAME} ${CWD}/helm/hive-metastore --namespace ${K8S_HIVE_NAMESPACE} \
  --values $2 \
  --reuse-values

    ;;

  spark-thrift)
cat<<EOF

=======================
Updating Apache Spark Thrift Server...
=======================

EOF

helm upgrade ${K8S_SPARK_THRIFT_SERVER_NAME} ${CWD}/helm/spark-thrift-server --namespace ${K8S_SPARK_THRIFT_SERVER_NAMESPACE} \
  --values $2 \
  --reuse-values
    ;;

  elastic)
cat<<EOF

=======================
Updating Elasticsearch...
=======================

EOF

helm upgrade ${K8S_EFK_NAME} bitnami/elasticsearch --namespace ${K8S_EFK_NAMESPACE} \
  --values $2 \
  --reuse-values  
    ;;

  fluentd)

cat<<EOF

=======================
Updating Fluentd...
=======================

EOF

helm upgrade ${K8S_EFK_NAME}-fluentd bitnami/fluentd --namespace ${K8S_EFK_NAMESPACE}  \
  --values $2  \
  --reuse-values

    ;;


  *)
    echo -n "Unknown component first argument should be one of (hdfs|datagram|airflow|livy|spark-history|spark-thrift|hive|elastic|fluentd)"
    ;;
esac

