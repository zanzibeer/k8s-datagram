# Helm Chart for Apache Livy

По умолчанию для работы используются образы `ashokhin/livy-spark:0.7.1-3.3.0` ([Dockerfile](./dockerfiles/livy-spark/Dockerfile)) и `ashokhin/kubectl-sidecar:1.24.2` ([Dockerfile](./dockerfiles/kubectl-sidecar/Dockerfile)).

### Установка

```
helm upgrade --install my-livy ./ --namespace apache-livy --create-namespace
```

### Удаление

```
helm uninstall my-livy --namespace apache-livy
```
