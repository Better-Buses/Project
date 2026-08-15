#!/bin/bash

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

ZONES="${1:?Usage: $0 <zones>}"
TEMPLATE_FILE="worker-template.one"
export START_SCRIPT_B64=$(base64 -w0 start-script.sh)

WORKDIR=$(mktemp -d)
envsubst '${START_SCRIPT_B64}' < $TEMPLATE_FILE > "$WORKDIR/$TEMPLATE_FILE"

sudo cp "$WORKDIR/$TEMPLATE_FILE" "/tmp/$TEMPLATE_FILE"
sudo chmod 644 "/tmp/$TEMPLATE_FILE"

TEMPLATE_ID=$(sudo -iu oneadmin onetemplate create "/tmp/$TEMPLATE_FILE" | grep -oP 'ID:\s*\K[0-9]+')
echo ">>> Template created: ID $TEMPLATE_ID"

for (( ZONE=1; ZONE <= $ZONES; ++ZONE )) do
    VM_NAME="Worker-$ZONE"
    VM_ID=$(sudo -iu oneadmin onetemplate instantiate "$TEMPLATE_ID" --name "$VM_NAME" | grep -oP 'ID:\s*\K[0-9]+')
    echo ">>> VM instantiated: ID $VM_ID"

    echo ">>> Waiting for VM to be RUNNING..."
    until sudo -iu oneadmin onevm show "$VM_ID" | grep -q "STATE.*RUNNING"; do
      sleep 3
  done
done

echo ">>> Done. VM ID: $VM_ID"
