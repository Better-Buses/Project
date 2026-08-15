#!/bin/bash
# Install K3s in server mode, Grafana, Prometheus and Falco

set -e
cd "$(dirname "${BASH_SOURCE[0]}")"

echo "Provisioning in progress — do not interrupt." > /etc/nologin

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
echo " STEP 2 — Helm"
echo "========================================"
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version

echo "========================================"
echo " STEP 3 — Nginx Ingress Controller"
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
echo " STEP 4 — Prometheus + Grafana"
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
  --set grafana.sidecar.dashboards.enabled=true \
  --set grafana.sidecar.dashboards.label=grafana_dashboard \
  --set grafana.sidecar.dashboards.folderAnnotation=grafana_folder \
  --set grafana.sidecar.dashboards.provider.foldersFromFilesStructure=true

echo ""
echo ">>> Waiting for monitoring pods ..."
kubectl wait --for=condition=Ready pods --all -n monitoring --timeout=300s || true

echo ""
echo ">>> Grafana:    http://localhost:30000  (admin / prom-operator)"
echo ">>> Prometheus: http://localhost:30001"

echo "========================================"
echo " STEP 5 — Import Grafana dashboards"
echo "========================================"

DASHBOARD_DIR="grafana"
FOLDER="Better Buses"

for f in "$DASHBOARD_DIR"/*.json; do
  base=$(basename "$f" .json)
  cm_name="grafana-dashboard-${base}"

  kubectl create configmap "$cm_name" \
    --from-file="$f" \
    --namespace monitoring \
    --dry-run=client -o yaml \
  | kubectl label --local -f - grafana_dashboard=1 -o yaml \
  | kubectl apply -f -

  kubectl annotate configmap "$cm_name" \
    --namespace monitoring \
    grafana_folder="$FOLDER" --overwrite
done

echo ">>> Dashboards imported into folder '$FOLDER'"

echo "========================================"
echo " STEP 6 — Basic auth per Ingress"
echo "========================================"
sudo apt install -y apache2-utils

htpasswd -bc auth admin promadmin
kubectl create secret generic prometheus-basic-auth \
  --from-file=auth \
  -n monitoring
rm auth
kubectl apply -f yamls/prometheus-ingress.yaml

echo "========================================"
echo " STEP 7 — Falco"
echo "========================================"
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
 
kubectl create namespace falco 2>/dev/null || true
 
helm install falco falcosecurity/falco \
  --namespace falco \
  --set driver.kind=modern_ebpf \
  --set falcosidekick.enabled=true \
  --set falcosidekick.config.prometheus.enabled=true \
  --set falco.http_output.enabled=true \
  --set falco.http_output.url=http://falco-falcosidekick:2801/ \
  --set falco.json_output=true \
  --set falco.json_include_output_property=true \
  --set falcosidekick.securityContext.runAsNonRoot=true \
  --set falcosidekick.securityContext.runAsUser=1000 \
  --set falcosidekick.securityContext.readOnlyRootFilesystem=true \
  --set falcosidekick.securityContext.allowPrivilegeEscalation=false \
  --set falcosidekick.securityContext.capabilities.drop[0]=ALL \
  --set-file customRules."falco-rules\.yaml"=yamls/falco-rules.yaml

echo ""
echo ">>> Waiting for falco..."
kubectl wait --for=condition=Ready pods --all -n falco --timeout=180s || true

echo "========================================"
echo " DONE"
echo "========================================"

rm -f /etc/nologin
echo "Provisioning complete." > /root/.provisioning-complete

# sudo hostnamectl set-hostname master
# echo "127.0.1.1 master" | sudo tee -a /etc/hosts

# sudo reboot
