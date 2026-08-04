#!/bin/bash
kubectl create configmap mosquitto-config \
  --from-file=configs/mosquitto.conf \
  --namespace=default \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f yamls/mosquitto.yaml

kubectl rollout restart deployment mosquitto
