#!/bin/bash
set -euo pipefail

kubectl label nodes worker-1 worker-2 role=worker --overwrite

chmod +x deploy-mosquitto.sh
chmod +x deploy-telegraf.sh

NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
ZONES=$((NODE_COUNT - 1))

for (( ZONE=1; ZONE <= $ZONES; ++ZONE )) do
  kubectl label nodes worker-$ZONE zone=$ZONE --overwrite

  NAMESPACE="zone-$ZONE"
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

  bash deploy-mosquitto.sh $ZONE $NAMESPACE
  bash deploy-telegraf.sh $ZONE $NAMESPACE

  export ZONE
  envsubst < yamls/network-policies.yaml | kubectl apply -f -
done

kubectl apply -f yamls/falco-monitor.yaml
