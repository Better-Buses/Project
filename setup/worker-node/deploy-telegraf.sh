#!/bin/bash
set -euo pipefail

ZONE="${1:?Usage: $0 <zone-index> <zone-namespace>}"
export ZONE
NAMESPACE="${2:?Usage: $0 <zone-index> <zone-namespace>}"

WORKDIR=$(mktemp -d)

# Render templates
envsubst < configs/telegraf-template.conf > "$WORKDIR/telegraf.conf"
envsubst < yamls/telegraf-workload-template.yaml > "$WORKDIR/telegraf-workload.yaml"
envsubst < yamls/telegraf-monitor-template.yaml > "$WORKDIR/telegraf-monitor.yaml"

kubectl create configmap "telegraf-config" \
  --from-file="telegraf.conf=$WORKDIR/telegraf.conf" \
  --namespace="$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f "$WORKDIR/telegraf-workload.yaml" --namespace="$NAMESPACE"

kubectl apply -f "$WORKDIR/telegraf-monitor.yaml" --namespace="monitoring"

kubectl rollout restart deployment telegraf --namespace="$NAMESPACE"
