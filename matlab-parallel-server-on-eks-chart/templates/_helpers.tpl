{{- define "mjs-eks-refarch.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "mjs-eks-refarch.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "mjs-eks-refarch.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "mjs-eks-refarch.name" . -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "mjs-eks-refarch.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mjs-eks-refarch.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "mjs-eks-refarch.labels" -}}
helm.sh/chart: {{ include "mjs-eks-refarch.chart" . }}
{{ include "mjs-eks-refarch.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
app.kubernetes.io/part-of: "mjs-eks-refarch"
{{- with .Values.componentLabel }}
app.kubernetes.io/component: {{ . | quote }}
{{- end }}
{{- end -}}