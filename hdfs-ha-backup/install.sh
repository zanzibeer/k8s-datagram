### HDFS HA ###

kubectl label node kube-wrk02 hdfs-datanode-exclude=yes

helm upgrade --install ${K8S_HDFS_NAME} ${CWD}/helm/hdfs/charts/hdfs-k8s   --namespace=${K8S_HDFS_NAMESPACE} --create-namespace   --set hdfs-namenode-k8s.webuiIngress.enabled="true"   --set hdfs-namenode-k8s.webuiIngress.hosts[0].host="${K8S_HDFS_NAME}-web.${K8S_CLUSTER_EXTERNAL_DNS}"   --set hdfs-namenode-k8s.webuiIngress.hosts[0].paths[0].path="/"   --set hdfs-namenode-k8s.webuiIngress.hosts[0].paths[0].pathType="Prefix"   --set global.clusterDns="${K8S_CLUSTER_INTERNAL_DNS}"



### Spark History Server ###
helm upgrade --install ${K8S_SPARK_HISTORY_SERVER_NAME} ${CWD}/helm/spark-history-server --namespace ${K8S_SPARK_HISTORY_SERVER_NAMESPACE} --create-namespace   --set ingress.enabled="true"   --set ingress.hosts[0].host="${K8S_SPARK_HISTORY_SERVER_NAME}.${K8S_CLUSTER_EXTERNAL_DNS}"   --set ingress.hosts[0].paths[0].path="/"   --set ingress.hosts[0].paths[0].pathType="Prefix"

