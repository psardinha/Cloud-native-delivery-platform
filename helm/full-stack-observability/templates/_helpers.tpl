{{/*
Application name.
*/}}
{{- define "full-stack-observability.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Application full name.
*/}}
{{- define "full-stack-observability.fullname" -}}
{{- default (include "full-stack-observability.name" .) .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "full-stack-observability.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ include "full-stack-observability.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "full-stack-observability.selectorLabels" -}}
app.kubernetes.io/name: {{ include "full-stack-observability.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}