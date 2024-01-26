{{/*
Expand the name of the chart.
*/}}
{{- define "livy.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "livy.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "livy.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "livy.labels" -}}
helm.sh/chart: {{ include "livy.chart" . }}
{{ include "livy.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "livy.selectorLabels" -}}
app.kubernetes.io/name: {{ include "livy.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "livy.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "livy.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create Apache Livy configuration
*/}}
{{- define "livy.configmap" -}}
livy.conf: |-
{{- if .Values.livyConfig }}
{{- range $k, $v := .Values.livyConfig }}
  {{ $k }} = {{ $v }}
{{- end }}
{{- else }}
  livy.spark.deploy-mode = cluster
  livy.file.local-dir-whitelist = /opt/.livy-sessions/
  livy.spark.master = k8s://http://localhost:8443
  livy.server.session.state-retain.sec = 8h
  livy.repl.enableHiveContext = true
{{- end }}
{{- end }}

{{/*
Create Apache Spark configuration
*/}}
{{- define "spark.configmap" -}}
spark-defaults.conf: |-
{{- if .Values.sparkDefaultsConfig }}
{{- range $k, $v := .Values.sparkDefaultsConfig }}
  {{ $k }} {{ $v }}
{{- end }}
{{- if not (hasKey .Values.sparkDefaultsConfig "spark.kubernetes.authenticate.driver.serviceAccountName") }}
  spark.kubernetes.authenticate.driver.serviceAccountName {{ include "livy.serviceAccountName" . }}
{{- end }}
{{- if not (hasKey .Values.sparkDefaultsConfig "spark.kubernetes.namespace") }}
  spark.kubernetes.namespace {{ .Release.Namespace }}
{{- end }}
{{- if not (hasKey .Values.sparkDefaultsConfig "spark.kubernetes.container.image") }}
  spark.kubernetes.container.image apache/spark:v3.1.3
{{- end }}
{{- if not (hasKey .Values.sparkDefaultsConfig "spark.kubernetes.driverEnv.HADOOP_USER_NAME") }}
  spark.kubernetes.driverEnv.HADOOP_USER_NAME spark
{{- end }}
{{- else }}
  spark.kubernetes.container.image apache/spark:v3.1.3
  spark.kubernetes.authenticate.driver.serviceAccountName {{ include "livy.serviceAccountName" . }}
  spark.kubernetes.namespace {{ .Release.Namespace }}
  spark.kubernetes.driverEnv.HADOOP_USER_NAME spark
{{- end }}
{{- end }}

{{/*
Create Hadoop configuration
*/}}
{{- define "hadoop.configmap" -}}
core-site.xml: |-
  <?xml version="1.0" encoding="UTF-8"?>
  <?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

  <configuration>
    {{- range $name, $value := .Values.hadoopConfig.coreSite }}
    <property>
      <name>{{ $name }}</name>
      <value>{{ $value }}</value>
    </property>
    {{- end }}
  </configuration>
{{- end }}

{{/*
Create Hive configuration
*/}}
{{- define "hive.configmap" -}}
hive-site.xml: |-
  <?xml version="1.0" encoding="UTF-8"?>
  <?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

  <configuration>
    {{- range $name, $value := .Values.hadoopConfig.hiveSite }}
    <property>
      <name>{{ $name }}</name>
      <value>{{ $value }}</value>
    </property>
    {{- end }}
  </configuration>
{{- end }}