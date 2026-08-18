#!/bin/bash

set -e
cd "$(dirname "${BASH_SOURCE[0]}")"

echo "Provisioning in progress — do not interrupt." > /etc/nologin

echo "========================================"
echo " STEP 1 — K3s (master)"
echo "========================================"
sudo hostnamectl set-hostname master
echo "127.0.1.1 master" | sudo tee -a /etc/hosts

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

GRAFANA_URL="http://localhost:30000"
GRAFANA_ADMIN_USER="admin"
GRAFANA_ADMIN_PASS="foggy"
 
GRULLO_PASSWORD="trento"
BROLLO_PASSWORD="trento"
 
GRULLO_LOGIN="grullo"
GRULLO_NAME="Grullo Broms"
 
BROLLO_LOGIN="brollo"
BROLLO_NAME="Brollo Gons"
 
DATA_DASHBOARD_JSON="./grafana/control-panel.json"
ALERT_DASHBOARD_JSON="./grafana/falco.json"

TEAM_NAME="TrentinoTrasporti"

AUTH="-u ${GRAFANA_ADMIN_USER}:${GRAFANA_ADMIN_PASS}"
API="${GRAFANA_URL}/api"

call() {
  local method=$1
  local path=$2
  local body=${3:-}
  if [ -n "$body" ]; then
    curl -s -X "$method" $AUTH -H "Content-Type: application/json" \
      -d "$body" "${API}${path}"
  else
    curl -s -X "$method" $AUTH "${API}${path}"
  fi
}

# The special uid "general" always refers to the root/General folder in Grafana's API
call POST "/folders/general/permissions" '{"items": []}' > /dev/null
echo ">>> General folder permissions: Admin only (Viewer/Editor removed)"

GRULLO=$(call POST /admin/users "$(jq -n \
  --arg name "$GRULLO_NAME" \
  --arg login "$GRULLO_LOGIN" \
  --arg password "$GRULLO_PASSWORD" \
  '{name: $name, login: $login, password: $password, OrgId: 1}')")
GRULLO_ID=$(echo "$GRULLO" | jq -r '.id')
echo ">>> User created: ${GRULLO_LOGIN} (id=$GRULLO_ID)"
 
# org-wide role: None — with Viewer/Editor, users get implicit read access to
# every folder by default, which defeats folder-level restrictions. Setting
# "None" means access comes ONLY from explicit folder/team permissions below.
call PATCH "/org/users/${GRULLO_ID}" '{"role":"None"}' > /dev/null
 
BROLLO=$(call POST /admin/users "$(jq -n \
  --arg name "$BROLLO_NAME" \
  --arg login "$BROLLO_LOGIN" \
  --arg password "$BROLLO_PASSWORD" \
  '{name: $name, login: $login, password: $password, OrgId: 1}')")
BROLLO_ID=$(echo "$BROLLO" | jq -r '.id')
echo ">>> User created: ${BROLLO_LOGIN} (id=$BROLLO_ID)"
 
# org-wide role: None — same reasoning as above. brollo's real "admin" power
# comes from being Team Admin (step 3) and folder Edit permissions, not from
# an org-wide role.
call PATCH "/org/users/${BROLLO_ID}" '{"role":"None"}' > /dev/null

TEAM=$(call POST /teams "$(jq -n --arg name "$TEAM_NAME" '{name: $name}')")
TEAM_ID=$(echo "$TEAM" | jq -r '.teamId')
echo ">>> Team created: ${TEAM_NAME} (id=$TEAM_ID)"
 
# Grafana automatically adds the API caller (admin) as a team Admin on creation — remove it,
# the global admin should not appear as a team member
ADMIN_ID=$(call GET "/users/lookup?loginOrEmail=${GRAFANA_ADMIN_USER}" | jq -r '.id')
call DELETE "/teams/${TEAM_ID}/members/${ADMIN_ID}" > /dev/null
echo ">>> Removed '${GRAFANA_ADMIN_USER}' from the team (was auto-added as owner)"
 
# add grullo as a regular member
call POST "/teams/${TEAM_ID}/members" "$(jq -n --argjson uid "$GRULLO_ID" '{userId: $uid}')" > /dev/null
echo ">>> ${GRULLO_LOGIN} added to the team (member)"
 
# add brollo as a member
call POST "/teams/${TEAM_ID}/members" "$(jq -n --argjson uid "$BROLLO_ID" '{userId: $uid}')" > /dev/null
 
# promote brollo to TEAM admin (not org-wide) — permission 4 = Admin within the team
call PUT "/teams/${TEAM_ID}/members/${BROLLO_ID}" '{"permission":4}' > /dev/null
echo ">>> ${BROLLO_LOGIN} added to the team as Team Admin"

FOLDER_DATA=$(call POST /folders '{"title":"Data"}')
FOLDER_DATA_UID=$(echo "$FOLDER_DATA" | jq -r '.uid')
echo ">>> Folder created: Data (uid=$FOLDER_DATA_UID)"
 
if [ -f "$DATA_DASHBOARD_JSON" ]; then
  DASH_JSON=$(jq 'del(.id) | del(.uid)' "$DATA_DASHBOARD_JSON")
  PAYLOAD=$(jq -n --argjson dashboard "$DASH_JSON" --arg folderUid "$FOLDER_DATA_UID" \
    '{dashboard: $dashboard, folderUid: $folderUid, overwrite: true}')
  call POST /dashboards/db "$PAYLOAD" > /dev/null
  echo ">>> Dashboard imported into Data from $DATA_DASHBOARD_JSON"
else
  echo ">>> WARNING: $DATA_DASHBOARD_JSON not found, import skipped"
fi
 
# permissions: team = View, brollo.gons = Edit (only the team admin can modify)
PERMS_DATA=$(jq -n --argjson teamId "$TEAM_ID" --argjson userId "$BROLLO_ID" '{
  items: [
    {teamId: $teamId, permission: 1},
    {userId: $userId, permission: 2}
  ]
}')
call POST "/folders/${FOLDER_DATA_UID}/permissions" "$PERMS_DATA" > /dev/null
echo ">>> Data folder permissions: team=View, ${BROLLO_LOGIN}=Edit"

FOLDER_ALERT=$(call POST /folders '{"title":"Alert"}')
FOLDER_ALERT_UID=$(echo "$FOLDER_ALERT" | jq -r '.uid')
echo ">>> Folder created: Alert (uid=$FOLDER_ALERT_UID)"
 
if [ -f "$ALERT_DASHBOARD_JSON" ]; then
  DASH_JSON=$(jq 'del(.id) | del(.uid)' "$ALERT_DASHBOARD_JSON")
  PAYLOAD=$(jq -n --argjson dashboard "$DASH_JSON" --arg folderUid "$FOLDER_ALERT_UID" \
    '{dashboard: $dashboard, folderUid: $folderUid, overwrite: true}')
  call POST /dashboards/db "$PAYLOAD" > /dev/null
  echo ">>> Dashboard imported into Alert from $ALERT_DASHBOARD_JSON"
else
  echo ">>> WARNING: $ALERT_DASHBOARD_JSON not found, import skipped"
fi
 
# permissions: ONLY brollo.gons (Edit) — the team has NO access
PERMS_ALERT=$(jq -n --argjson userId "$BROLLO_ID" '{
  items: [
    {userId: $userId, permission: 2}
  ]
}')
call POST "/folders/${FOLDER_ALERT_UID}/permissions" "$PERMS_ALERT" > /dev/null
echo ">>> Alert folder permissions: only ${BROLLO_LOGIN}=Edit (team excluded)"

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
  --set falcosidekick.nodeSelector.role=worker \
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

sudo reboot
