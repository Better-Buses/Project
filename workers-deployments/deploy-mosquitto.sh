#!/bin/bash
set -euo pipefail

ZONE="${1:?Usage: $0 <zone-index> <zone-namespace>}"
export ZONE
NAMESPACE="${2:?Usage: $0 <zone-index> <zone-namespace>}"
NODE_PORT=$((30183 + ZONE))
export NODE_PORT

WORKDIR=$(mktemp -d)

# Render templates
envsubst < configs/mosquitto.conf > "$WORKDIR/mosquitto.conf"
envsubst < yamls/mosquitto-template.yaml > "$WORKDIR/mosquitto.yaml"

kubectl create configmap mosquitto-config \
  --from-file="mosquitto.conf=$WORKDIR/mosquitto.conf" \
  --namespace="$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f "$WORKDIR/mosquitto.yaml" --namespace="$NAMESPACE"

kubectl rollout restart deployment mosquitto --namespace="$NAMESPACE"
