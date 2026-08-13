#!/bin/bash
# Install K3s in server mode, Grafana, Prometheus and Falco

set -e

echo "========================================"
echo " STEP 1 — K3s (master)"
echo "========================================"
curl -sfL https://get.k3s.io | sh -

mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
chmod 600 ~/.kube/config

export KUBECONFIG=~/.kube/config

echo ""
echo ">>> Waiting for k3s API server to respond..."
until kubectl get nodes &>/dev/null; do
  sleep 2
done

echo ""
echo ">>> Nodes state K3s:"
kubectl get nodes

echo ""
echo ">>> Node toke:"
sudo cat /var/lib/rancher/k3s/server/node-token

echo "alias kctl='kubectl'" | sudo tee -a ~/.bashrc

echo "========================================"
echo " STEP 2 - Node rename"
echo "========================================"

# sudo hostnamectl set-hostname master
# echo "127.0.1.1 master" | sudo tee -a /etc/hosts

echo "========================================"
echo " STEP 3 — Helm"
echo "========================================"
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version

echo "========================================"
echo " STEP 4 — Nginx Ingress Controller"
echo "========================================"
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=NodePort \
  --set controller.service.nodePorts.http=30001

echo ""
echo ">>> Waiting for Ingress Controller..."
kubectl wait --for=condition=Ready pods --all -n ingress-nginx --timeout=120s || true


echo "========================================"
echo " STEP 5 — Prometheus + Grafana"
echo "========================================"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace monitoring

helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=30000 \
  --set grafana.adminPassword=foggy \
  --set prometheus.service.type=ClusterIP \

echo ""
echo ">>> Waiting for monitoring pods ..."
kubectl wait --for=condition=Ready pods --all -n monitoring --timeout=300s || true

echo ""
echo ">>> Grafana:    http://localhost:30000  (admin / prom-operator)"
echo ">>> Prometheus: http://localhost:30001"

echo "========================================"
echo " STEP 6 — Basic auth per Ingress"
echo "========================================"
sudo apt install -y apache2-utils

htpasswd -bc auth admin promadmin
kubectl create secret generic prometheus-basic-auth \
  --from-file=auth \
  -n monitoring
rm auth
kubectl apply -f prometheus-ingress.yaml

echo "========================================"
echo " STEP 7 — Falco"
echo "========================================"
# curl -fsSL https://falco.org/repo/falcosecurity-packages.asc \
#   | sudo gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg
 
# echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] \
# https://download.falco.org/packages/deb stable main" \
#   | sudo tee /etc/apt/sources.list.d/falcosecurity.list
 
# sudo apt update
# sudo apt install -y falco
 
# sudo systemctl enable --now falco
curl -fsSL https://falco.org/repo/falcosecurity-packages.asc \
  | sudo gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg
 
echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] \
https://download.falco.org/packages/deb stable main" \
  | sudo tee /etc/apt/sources.list.d/falcosecurity.list
 
sudo apt update
sudo apt install -y falco
 
sudo systemctl enable --now falco-modern-bpf

echo ""
echo ">>> Falco status:"
sudo systemctl status falco-modern-bpf --no-pager

echo "========================================"
echo " DONE"
echo "========================================"

# sudo reboot
