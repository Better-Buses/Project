#!/bin/bash
set -euo pipefail

chmod +x deploy-mosquitto.sh
chmod +x deploy-telegraf.sh

ZONES=2
for (( ZONE=1; ZONE <= $ZONES; ++ZONE )) do
  kubectl label nodes worker-$ZONE zone=$ZONE --overwrite

  NAMESPACE="zone-$ZONE"
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

  bash deploy-mosquitto.sh $ZONE $NAMESPACE
  bash deploy-telegraf.sh $ZONE $NAMESPACE

  kubectl apply -f yamls/falco-monitor.yaml

  export ZONE
  envsubst < yamls/network-policies.yaml | kubectl apply -f -
done