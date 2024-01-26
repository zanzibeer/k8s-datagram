{{/*
Expand the name of the chart.
*/}}
{{- define "datagram.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "datagram.fullname" -}}
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
{{- define "datagram.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "datagram.labels" -}}
helm.sh/chart: {{ include "datagram.chart" . }}
{{ include "datagram.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "datagram.selectorLabels" -}}
app.kubernetes.io/name: {{ include "datagram.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "datagram.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "datagram.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "datagram.configmap" -}}
ldap.properties: |
{{- if not (empty .Values.datagram.config.ldapProperties) }}
  {{ .Values.datagram.config.ldapProperties }}
{{- else }}
  ldap.domain=xxxxx.ru
  ldap.host=dc1.xxxxx.ru
  ldap.port=389
  ldap.base=CN=Users,DC=xxxxx,DC=ru
  ldap.always_admin=true
{{- end }}
application.properties: |
{{- if not (empty .Values.datagram.config.applicationProperties) }}
  {{ .Values.datagram.config.applicationProperties }}
{{- else }}
  server.port={{ .Values.datagram.serverPort }}
  deploy.dir={{ printf "%s/%s" .Values.datagram.datagramHome .Values.datagram.deployDir }}
  maven.home={{ .Values.datagram.mavenHome }}
  ldap.enabled={{ .Values.datagram.ldapEnabled }}
  ldap.always_admin=true
{{- end }}
{{- end }}
