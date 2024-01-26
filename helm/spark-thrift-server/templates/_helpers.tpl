{{/*
Expand the name of the chart.
*/}}
{{- define "spark-thrift.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "spark-thrift.fullname" -}}
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
{{- define "spark-thrift.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "spark-thrift.labels" -}}
helm.sh/chart: {{ include "spark-thrift.chart" . }}
{{ include "spark-thrift.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "spark-thrift.selectorLabels" -}}
app.kubernetes.io/name: {{ include "spark-thrift.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "spark-thrift.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "spark-thrift.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
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
{{- if not (hasKey .Values.sparkDefaultsConfig "spark.kubernetes.namespace") }}
  spark.kubernetes.namespace {{ .Release.Namespace }}
{{- end }}
{{- if not (hasKey .Values.sparkDefaultsConfig "spark.driver.host") }}
  spark.driver.host {{ include "spark-thrift.name" . }}
{{- end }}
{{- if not (hasKey .Values.sparkDefaultsConfig "spark.kubernetes.container.image") }}
  spark.kubernetes.container.image apache/spark:v3.3.0
{{- end }}
{{- else }}
  spark.kubernetes.container.image apache/spark:v3.3.0
  spark.kubernetes.namespace {{ .Release.Namespace }}
  spark.driver.host {{ include "spark-thrift.name" . }}
{{- end }}
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