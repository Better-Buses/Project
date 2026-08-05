#!/bin/bash
set -euo pipefail

ZONE="${1:?Usage: $0 <zone-index> <zone-namespace>}"
export ZONE
NAMESPACE="${2:?Usage: $0 <zone-index> <zone-namespace>}"

WORKDIR=$(mktemp -d)

# Render templates
envsubst < configs/telegraf-template.conf > "$WORKDIR/telegraf.conf"
envsubst < yamls/telegraf-template.yaml > "$WORKDIR/telegraf.yaml"

kubectl create configmap "telegraf-config" \
  --from-file="telegraf.conf=$WORKDIR/telegraf.conf" \
  --namespace="$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f "$WORKDIR/telegraf.yaml" --namespace="$NAMESPACE"

kubectl rollout restart deployment telegraf --namespace="$NAMESPACE"
