# k8s-datagram

Данный репозиторий предоставляет набор Helm Charts для быстрого развёртывания внутри Kubernetes следующих компонентов:

# Оглавление

- [Требования](#требования)
- [Версии компонентов](#версии-компонентов)
- [Apache HDFS](#apache-hdfs)
  - [Подготовка](#подготовка)
  - [Базовая установка](#базовая-установка)
  - [Упрощённая установка](#упрощённая-установка)
  - [Удаление](#удаление)
- [Apache Airflow](#apache-airflow)
  - [Установка](#установка)
  - [Удаление](#удаление-1)
- [Neoflex Datagram](#neoflex-datagram)
  - [Установка](#установка-1)
  - [После установки](#после-установки)
  - [Удаление](#удаление-2)
- [Apache Livy](#apache-livy)
  - [Установка](#установка-3)
  - [Проверка установки](#проверка-установки)
- [Apache Spark History Server](#apache-spark-history-server)
- [Установка скриптом](#установка-скриптом)
- [Offline установка](#offline-установка)

![k8s-datagram](https://user-images.githubusercontent.com/68422048/177973099-954b3591-f536-4644-84b0-9bf3359faa10.png)

# Требования

- Кластер Kubernetes 1.20+
- Helm 3.2+
- Поставщик физического хранилища внутри кластера (provisioner)
- DNS resolve "изнутри наружу", т.е. изнутри pod'ов Kubernetes адреса нод Kubernetes должны преобразовываться в IP, т.к. компоненты HDFS используют **hostNetwork**.
- Настроенный default ingress class

# Версии компонентов

### Apache HDFS:

**Helm Chart: 0.1.0**

| Компонент | Версия | Образ:тег |
| --- | --- | --- |
| NameNode | 2.7.2 | uhopper/hadoop-namenode:2.7.2 |
| DataNode | 2.7.2 | uhopper/hadoop-datanode:2.7.2 |
| JournalNode | 2.7.2 | uhopper/hadoop-namenode:2.7.2 |
| Client | 2.7.2 | uhopper/hadoop:2.7.2 |
| ZooKeeper | 3.8.0 | bitnami/zookeeper:3.8.0-debian-11-r11 |

### Apache Airflow:

**Helm Chart: 1.6.0**

| Компонент | Версия | Образ:тег |
| --- | --- | --- |
| Airflow Scheduler | 2.3.0 | apache/airflow:2.3.0 |
| Airflow Triggerer | 2.3.0 | apache/airflow:2.3.0 |
| Airflow Webserver | 2.3.0 | apache/airflow:2.3.0 |
| Airflow Worker | 2.3.0 | apache/airflow:2.3.0 |
| PostgreSQL | 11.12.0 | bitnami/postgresql:11.12.0-debian-10-r44 |
| Redis | 6.2.7 | redis:6-bullseye |
| StatsD Exporter | 0.17.0 | apache/airflow:airflow-statsd-exporter-2021.04.28-v0.17.0 |

### Apache Datagram:

**Helm Chart: 0.1.0**

| Компонент | Версия | Образ:тег |
| --- | --- | --- |
| Datagram Metaserver | spark3-2.0.0-SNAPSHOT | neoflexdatagram/datagram:latest |
| PostgreSQL | 9.6.24 | bitnami/postgresql:9.6-debian-10 |

### Apache Livy:

**Helm Chart: 0.1.0**

| Компонент | Версия | Образ:тег |
| --- | --- | --- |
| Livy + Spark | 0.8.0-incubating + 3.1.3 | harbor.alfatell.ru/ashohin/livy-spark:0.8.0-3.1.3 |
| Spark | 3.1.3 | apache/spark:v3.1.3 |

### Apache Spark History Server:

**Helm Chart: 0.1.0**

| Компонент | Версия | Образ:тег |
| --- | --- | --- |
| Spark | 3.3.0 | apache/spark:v3.3.0 |

# Установка

## Apache HDFS

За основу взят репозиторий [apache-spark-on-k8s/kubernetes-HDFS](https://github.com/apache-spark-on-k8s/kubernetes-HDFS).

На текущий момент репозиторий не обновлялся с 31.05.2019, поэтому здесь представлена обновлённая версия 
(обновлены API манифестов, удалены неработающие тесты).

### Подготовка

Перед началом установки необходимо добавить репозиторий incubator и собрать все зависимости:

```
helm repo add bitnami https://charts.bitnami.com/bitnami
helm dependency build ./helm/hdfs/charts/hdfs-k8s
```

### Базовая установка

Перед началом установки необходимо создать на нодах, где будут размещаться **DataNode**, директории, в которых позднее будут размещаться данные HDFS. 
По умолчанию: `/hdfs-data`.

**DataNode** устанавливается как `DaemonSet` поэтому размещается на всех нодах кластера, доступных для планирования.

Чтобы этого избежать, необходимо пометить ноды, недоступные для **DataNode**, меткой `hdfs-datanode-exclude`:

```
kubectl label node YOUR-CLUSTER-NODE hdfs-datanode-exclude=yes
```

Если необходимо установить Apache HDFS в режиме HA, то достаточно просто указать имя релиза (в нашем примере **my-hdfs**), 
путь к родительскому Helm Chart и пространство имён для установки:

```
helm upgrade --install my-hdfs ./helm/hdfs/charts/hdfs-k8s --namespace apache-hdfs --create-namespace
```
, где:
- **my-hdfs** - имя Helm Release. Можно указать любое имя, но следует учесть, что все сущности, созданные этим Helm Chart будут начинаться с этого имени. Например, под `namenode-0` будет называться `my-hdfs-namenode-0`, а, например, сервис `namenode`, будет называться `my-hdfs-namenode`.
- **apache-hdfs** - пространство имён, в которое будет установлен Helm Release.

В данном режиме будут установлены 2 экземпляра **NameNode**, 3 экземпляра **JournalNode**, 3 экземпляра **Zookeeper**, 
1 pod **hdfs-client** и **DataNode** по количеству доступных для планирования нод (т.е. не помеченных меткой `hdfs-datanode-exclude`).

:exclamation: **ВНИМАНИЕ!** Без указания пространства имён все компоненты будут установлены в пространство имён **default**.

Чтобы этого избежать нужно использовать флаг `--namespace`.

Так же можно использовать дополнительный флаг `--create-namespace`, если указываемое пространство имён не существует.

### Упрощённая установка

Если нужно установить Apache HDFS без поддержки HA, то необходимо переопределить ряд параметров, с помощью флагов `--set`.

Перед началом установки требуется создать на ноде кластера, на которой будет размещаться **NameNode**, директорию `/name-data` и пометить ноду меткой:

```
kubectl label nodes YOUR-CLUSTER-NODE hdfs-namenode-selector=hdfs-namenode-0
```

Далее нужно использовать эту метку и путь к директории в качестве дополнительных параметров:

```
helm upgrade --install my-hdfs ./helm/hdfs/charts/hdfs-k8s \
  --namespace apache-hdfs --create-namespace \
  --set tags.ha=false \
  --set tags.simple=true \
  --set global.namenodeHAEnabled=false \
  --set hdfs-simple-namenode-k8s.nodeSelector.hdfs-namenode-selector=hdfs-namenode-0 \
  --set hdfs-simple-namenode-k8s.nameNodeHostPath="/name-data"
```

Подробнее с вариантами установки, переопределяемыми параметрами, а так же с командами для проверки после установки 
можно ознакомиться в [README.md Helm Chart](./helm/hdfs/charts/README.md).

### Удаление

```
helm uninstall my-hdfs --namespace apache-hdfs
```

## Apache Airflow

Данный репозиторий здесь не представлен, т.к. на текущий момент он активно развивается и поддерживается сообществом.

- [Helm Chart на GitHub](https://github.com/apache/airflow/tree/main/chart).
- [Описание Helm Chart на официальном сайте](https://airflow.apache.org/docs/helm-chart/stable/index.html)
- [Подробное описание переопределяемых параметров](https://airflow.apache.org/docs/helm-chart/stable/parameters-ref.html)

### Установка

Достаточно добавить репозиторий и запустить установку следующими командами:

```
helm repo add apache-airflow https://airflow.apache.org
helm upgrade --install my-airflow apache-airflow/airflow --namespace apache-airflow --create-namespace
```

### Удаление
```
helm uninstall my-airflow --namespace apache-airflow
```

## Neoflex Datagram

### Установка

Данный Helm Chart устанавливает Neoflex Datagram и PostgreSQL 9.x как вспомогательную БД.

Для начала установки нужно задать имя пользователя (по умолчанию `datagram`), имя базы данных (по умолчанию `datagram`) 
и пароль в файле [./helm/datagram/values.yaml](./helm/datagram/values.yaml).

Так же можно просто задать пароль через входящий параметр `postgresql.auth.password`:

```
helm upgrade --install my-datagram ./helm/datagram --namespace neoflex-datagram --create-namespace \
  --set postgresql.auth.password="My_5EcRet_PA5sW0rD_HerE"
```

### После установки

После установки необходимо скопировать дополнительные библиотеки для Spark:
1. Требуется создать в HDFS папку для дополнительных библиотек Spark:
```
CLIENT_POD=$(kubectl -n apache-hdfs get pods --no-headers -l app=hdfs-client,release=my-hdfs -o name)

kubectl exec $CLIENT_POD -- hadoop fs -mkdir -p /datagram/sharedlibs
kubectl exec $CLIENT_POD -- hadoop fs -chmod -R 0777 /datagram
```
:exclamation: **ВНИМАНИЕ!** Необходимо запомнить созданный путь, т.к. его нужно будет указать при установке Livy.

2. Необходимо склонировать Git-репозиторий Datagram:
```
git clone https://github.com/neoflex-consulting/datagram.git
```

3. Нужно скопировать из папки репозитория `./datagram/bd-runtime/bd-base/extralib` дополнительные библиотеки в HDFS.
Сделать это можно, например, через WebHDFS:
    1. Нужно сделать запрос на получение ссылки для копирования на внутренний адрес NameNode'ы HDFS. 
    Внутренний адрес NameNode формируется по принципу `<имя_pod>.<имя сервиса>.<пространство_имён>.svc.<домен_кластера>`. Например, если вы установили hdfs с именем `my-hdfs`, в пространство имён `apache-hdfs`, и внутреннее DNS-имя кластера - `cluster.local` (значение по умолчанию), то адрес NameNode HDFS будет `my-hdfs-namenode-0.my-hdfs-namenode.apache-hdfs.svc.cluster.local`.
    ```
    curl --silent \
      --include \
      --request PUT \
      --url "http://my-hdfs-namenode-0.my-hdfs-namenode.apache-hdfs.svc.cluster.local:50070/webhdfs/v1/datagram/sharedlibs/${LIB_NAME}?op=CREATE"
    ```
    , где `${LIB_NAME}` - имя копируемого файла. Пример:
    ```
    curl --silent \
      --include \
      --request PUT \
      --url "http://my-hdfs-namenode-0.my-hdfs-namenode.apache-hdfs.svc.cluster.local:50070/webhdfs/v1/datagram/sharedlibs/postgresql-42.2.12.jre6.jar?op=CREATE"
    ```
    В ответ придёт заголовок `Location`, в котором будет указан URL для загрузки. Пример ответа:
    ```
    HTTP/1.1 307 TEMPORARY_REDIRECT
    Location: http://k8s-worker02.example.com:50075/webhdfs/v1/datagram/sharedlibs/postgresql-42.2.12.jre6.jar?op=CREATE&namenoderpcaddress=my-hdfs-namenode-0.my-hdfs-namenode.apache-hdfs.svc.cluster.local:8020&overwrite=false
    Content-Type: application/octet-stream
    Content-Length: 0
    ```
    2. Использовать значение заголовка `Location` как URL для загрузки, добавив ключ `--upload-file ` и путь до файла. Например:
    ```
    curl --silent \
      --request PUT \
      --upload-file "./datagram/bd-runtime/bd-base/extralib/postgresql-42.2.12.jre6.jar" \
      --url "http://k8s-worker02.example.com:50075/webhdfs/v1/datagram/sharedlibs/postgresql-42.2.12.jre6.jar?op=CREATE&namenoderpcaddress=my-hdfs-namenode-0.my-hdfs-namenode.apache-hdfs.svc.cluster.local:8020&overwrite=false"
    ```


### Удаление
```
helm uninstall my-datagram --namespace neoflex-datagram
```


## Apache Livy

### Установка

Чтобы Spark писал свои логи в HDFS, в папку `/shared/spark-logs`, необходимо:
1. Создать папку для логов в HDFS через pod `hdfs-client`:
```
CLIENT_POD=$(kubectl -n apache-hdfs get pods --no-headers -l app=hdfs-client,release=my-hdfs -o name)

kubectl exec $CLIENT_POD -- hadoop fs -mkdir -p /shared/spark-logs
kubectl exec $CLIENT_POD -- hadoop fs -chmod 0777 /shared/spark-logs
```
2. Определить адрес HDFS NameNode. Внутренний FQDN адрес Pod'а строится по принципу:
`<имя_pod>.<имя сервиса>.<пространство_имён>.svc.<домен_кластера>`. 
Например: `my-hdfs-namenode-0.hdfs-namenode.apache-hdfs.svc.cluster.local`.
Порт сервиса по умолчанию - `8020`.

При установке необходимо переопределить ряд параметров:
1. Указать (`spark.kubernetes.file.upload.path`);
2. Включить логирование (`spark.eventLog.enabled`) и указать путь к логам в HDFS (`spark.eventLog.dir`);
3. Указать путь к дополнительным библиотекам для Spark-драйвера (`spark.driver.extraClassPath`) и Spark-исполнителя (`spark.executor.extraClassPath`);
4. (Опционально) Указать внешний адрес (`ingress.hosts[0].host`) для Livy, чтобы можно было открыть UI Livy снаружи кластера и отслеживать состояние запущенных заданий и сессий. Для правильного указания адреса у администратора кластера необходимо уточнить внешний DNS wildcard для кластера Kubernetes. В примере это будет `*.k8s-apps.example.com`.

Пример:
```
helm upgrade --install my-livy ./helm/livy --namespace apache-livy --create-namespace \
  --set sparkDefaultsConfig."spark\.kubernetes\.file\.upload\.path"="hdfs://my-hdfs-namenode-0.hdfs-namenode.apache-hdfs.svc.cluster.local:8020/tmp/" \
  --set sparkDefaultsConfig."spark\.eventLog\.enabled"="true" \
  --set sparkDefaultsConfig."spark\.eventLog\.dir"="hdfs://my-hdfs-namenode-0.hdfs-namenode.apache-hdfs.svc.cluster.local:8020/shared/spark-logs" \
  --set sparkDefaultsConfig."spark\.driver\.extraClassPath"="/datagram/sharedlibs/" \
  --set sparkDefaultsConfig."spark\.executor\.extraClassPath"="/datagram/sharedlibs/" \
  --set sparkDefaultsConfig."spark\.kubernetes\.driverEnv\.HADOOP_USER_NAME"="spark" \
  --set hadoopConfig.coreSite."fs\.defaultFS"="hdfs://my-hdfs-namenode-0.hdfs-namenode.apache-hdfs.svc.cluster.local:8020" \
  --set ingress.enabled="true" \
  --set ingress.hosts[0].host="livy.k8s-apps.example.com" \
  --set ingress.hosts[0].paths[0].path="/" \
  --set ingress.hosts[0].paths[0].pathType="Prefix"
```

:exclamation: **ВНИМАНИЕ!** Следует обратить внимание, что, т.к. в именах параметров Spark присутствуют точки, то они должны быть 
заэкранированы, а само имя параметра должно быть взято в кавычки.

[Список всех доступных параметров Helm Chart Livy](./helm/livy/values.yaml)

### Проверка установки

FQDN адрес сервиса формируется по принципу `<имя_сервиса>.<пространство_имён>.svc.<dns_имя_кластера>` .

Если Helm Chart установлен с именем `my-livy`, в пространство имён `apache-livy` и внутреннее DNS-имя кластера - `cluster.local` 
(значение по умолчанию), то FQDN сервиса будет следующим: `my-livy.apache-livy.svc.cluster.local`.

Необходимо отправить пакетное выполнение Spark-примера (вычисление числа Пи) из образа `apache/spark:v3.3.0` через Livy API `batches` ([Параметры API "batches" Apache Livy](https://livy.apache.org/docs/latest/rest-api.html#post-batches)):
```
curl \
  -X POST \
  -H "Content-Type: application/json" \
  --url "http://my-livy.apache-livy.svc.cluster.local:8998/batches" \
  --data '{
    "name": "test-livy-local-file",
    "conf":{
      "spark.kubernetes.container.image":"apache/spark:v3.3.0"
    },
    "args":["10"],
    "className": "org.apache.spark.examples.SparkPi", 
    "file": "local:///opt/spark/examples/jars/spark-examples_2.12-3.3.0.jar"
  }'
```
, где:
- **name** - имя задания Livy;
- **conf** - дополнительные параметры Spark. В данном примере указывается только параметр `spark.kubernetes.container.image`, указывающий - из какого образа будет 
запускаться контейнер Spark. Подробнее о параметрах Spark можно узнать в документации: 
  - [Общие параметры Spark](https://spark.apache.org/docs/latest/configuration.html)
  - [Параметры Spark для Kubernetes](https://spark.apache.org/docs/latest/running-on-kubernetes.html#configuration)
- **args** - аргументы, передаваемые исполняемому коду;
- **className** - имя вызываемого Java-класса;
- **file** - путь к файлу. `local://` означает, что файл находится внутри образа.

Выполнение задания делится на несколько этапов:
1. После вызова API сервер Livy выполняет `spark-submit`, передавая задание в Kubernetes;
2. В кластере Kubernetes создаётся pod **spark-driver**;
3. В свою очередь **spark-driver** создаёт pod(-ы) **spark-executor**;
4. Pod(-ы) **spark-executor** выполняют задание и возвращают результаты pod'у **spark-driver** и завершает(-ют) свою работу;
5. Pod **spark-submit** получает результаты задания, удаляет поды **spark-executor** и завершает свою работу, переходя в статус `Completed`.

Контроль выполнения проверочного задания:
1. Чтобы найти имя пода `spark-driver` необходимо выполнить команду `kubectl -n apache-livy get pods`. Пример вывода:
```
# kubectl -n apache-livy get pods
NAME                                           READY   STATUS    RESTARTS   AGE
livy-549b599d5-rmnsr                           2/2     Running   0          3m46s
spark-pi-49771b82258b234a-exec-1               1/1     Running   0          5s
spark-pi-49771b82258b234a-exec-2               1/1     Running   0          5s
test-livy-local-file-50f2d782258aef49-driver   1/1     Running   0          20s
```
2. Нужно дождаться окончания выполнения задания, когда под `test-livy-local-file-50f2d782258aef49-driver` перейдёт в статус `Completed`:
```
# kubectl -n apache-livy get pods
NAME                                           READY   STATUS      RESTARTS   AGE
livy-549b599d5-rmnsr                           2/2     Running     0          6m50s
test-livy-local-file-50f2d782258aef49-driver   0/1     Completed   0          3m24s
```
3. Теперь можно посмотреть логи пода командой `kubectl -n apache-livy logs test-livy-local-file-50f2d782258aef49-driver`. При успешном выполнении в логах драйвера должна быть строка результатов вида "`Pi is roughly 3.1396031396031394`":
```
# kubectl -n apache-livy logs test-livy-local-file-50f2d782258aef49-driver | grep 'Pi is roughly'
Pi is roughly 3.1396031396031394
```

### Удаление
```
helm uninstall my-livy --namespace apache-livy
```

## Apache Spark History Server

Так как для успешной работы **Apache Spark History Server** требуется совместный доступ к логам Spark, то необходимо 
определить общее место хранения этих логов (в текущей установке это "`hdfs:///shared/spark-logs`") и задать его в параметре `logPath` 
([список доступных параметров Helm Chart Spark](./helm/spark-history-server/values.yaml)):
1. Необходимо определить адрес HDFS NameNode. Внутренний FQDN адрес Pod'а строится по принципу:
`<имя_pod>.<имя сервиса>.<пространство_имён>.svc.<домен_кластера>`. 
Например: `my-hdfs-namenode-0.hdfs-namenode.apache-hdfs.svc.cluster.local`.
Порт сервиса по умолчанию - `8020`.
2. (Опционально) Указать внешний адрес (`ingress.hosts[0].host`) для Spark History Server, чтобы можно было открыть UI Spark History Server снаружи кластера и отслеживать состояние запущенных и законченных заданий и сессий. Для правильного указания адреса у администратора кластера необходимо уточнить внешний DNS wildcard для кластера Kubernetes. В примере это будет `*.k8s-apps.example.com`.
3. Установить Apache Spark History Server, задав путь к логам, через параметр `logPath` и адрес ingress, если это необходимо:
```
helm upgrade --install my-spark-history-server ./helm/spark-history-server --namespace apache-livy \
  --set logPath="hdfs://my-hdfs-namenode-0.hdfs-namenode.apache-hdfs.svc.cluster.local:8020/shared/spark-logs" \
  --set ingress.enabled="true" \
  --set ingress.hosts[0].host="shs.k8s-apps.example.com" \
  --set ingress.hosts[0].paths[0].path="/" \
  --set ingress.hosts[0].paths[0].pathType="Prefix"
```

Теперь можно проверить отображение задач в UI Apache Spark History Server.

* Если `ingress` был настроен, то необходимо перейти по адресу, указанному в `ingress`:

![Spark History Server example.com](https://neogit.neoflex.ru/ashohin/markdown/-/raw/bf4d4bc9d12cefadf5775665d7d35824fdaebdf8/src/common/images/spark-history-example.png)

* Если `ingress` не настраивался, то сначала необходимо перенаправить порт Spark History Server на локальный порт:
```
kubectl -n apache-livy port-forward svc/spark-history-server 8080:80
```
Теперь можно открыть адрес http://localhost:8080/ :

![Spark History Server localhost](https://neogit.neoflex.ru/ashohin/markdown/-/raw/bf4d4bc9d12cefadf5775665d7d35824fdaebdf8/src/common/images/spark-history-local.png)

### Удаление

```
helm uninstall --namespace apache-livy my-spark-history-server
```

# Установка скриптом

Установка всех компонентов может быть произведена скриптом install.sh, находящемся в данном репозитории.
Скрипт должен запускаться с машины на которой
* Установлены kubectl и helm
* В kubectl настроен доступ в kubernetes кластер с правами администратора
* Есть доступ в интернет
* Настроен DNS резолвинг имен в kubernetes кластере 


# Offline установка

### Подготовка образов

Для offline-установки потребуется скачать все образы контейнеров, используемые для установки и последующего использования продукта.
