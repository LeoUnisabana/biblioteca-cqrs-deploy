{{/*
Expand the name of the chart.
*/}}
{{- define "biblioteca-cqrs.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "biblioteca-cqrs.fullname" -}}
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
{{- define "biblioteca-cqrs.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "biblioteca-cqrs.labels" -}}
helm.sh/chart: {{ include "biblioteca-cqrs.chart" . }}
{{ include "biblioteca-cqrs.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "biblioteca-cqrs.selectorLabels" -}}
app.kubernetes.io/name: {{ include "biblioteca-cqrs.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
PostgreSQL labels
*/}}
{{- define "biblioteca-cqrs.postgresql.labels" -}}
helm.sh/chart: {{ include "biblioteca-cqrs.chart" . }}
{{ include "biblioteca-cqrs.postgresql.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
PostgreSQL selector labels
*/}}
{{- define "biblioteca-cqrs.postgresql.selectorLabels" -}}
app.kubernetes.io/name: {{ include "biblioteca-cqrs.name" . }}-postgres
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: database
{{- end }}

{{/*
PostgreSQL service name
*/}}
{{- define "biblioteca-cqrs.postgresql.servicename" -}}
{{- printf "%s-postgres" (include "biblioteca-cqrs.fullname" .) }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "biblioteca-cqrs.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "biblioteca-cqrs.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Database connection URL
*/}}
{{- define "biblioteca-cqrs.database.url" -}}
{{- if .Values.postgresql.enabled }}
jdbc:postgresql://{{ include "biblioteca-cqrs.postgresql.servicename" . }}:{{ .Values.postgresql.service.port }}/{{ .Values.postgresql.auth.database }}
{{- else }}
{{- .Values.postgresql.externalUrl }}
{{- end }}
{{- end }}
