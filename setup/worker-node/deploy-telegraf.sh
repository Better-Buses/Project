#!/bin/bash
kubectl create configmap telegraf-config \
  --from-file=configs/telegraf.conf \
  --namespace=default \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f yamls/telegraf.yaml

kubectl rollout restart deployment telegraf
