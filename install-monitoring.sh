# !/bin/bash
#set -euo pipefail
#set -x

CWD=$( cd "$( dirname "$0" )" && pwd )

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack --version 36.2.1 --namespace monitoring --create-namespace \
    --set grafana.persistence.enabled="true"
    --values ${CWD}/helm/prometheus/alertManager.yaml \
    --values ${CWD}/helm/prometheus/alertRules.yaml
