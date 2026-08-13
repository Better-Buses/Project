#!/bin/bash

set -euo pipefail

TEMPLATE_FILE="sensors-template.one"
VM_NAME="Sensors"

sudo cp "$TEMPLATE_FILE" "/tmp/$TEMPLATE_FILE"
sudo chmod 644 "/tmp/$TEMPLATE_FILE"

TEMPLATE_ID=$(sudo -iu oneadmin onetemplate create "/tmp/$TEMPLATE_FILE" | grep -oP 'ID:\s*\K[0-9]+')
echo ">>> Template created: ID $TEMPLATE_ID"

VM_ID=$(sudo -iu oneadmin onetemplate instantiate "$TEMPLATE_ID" --name "$VM_NAME" | grep -oP 'ID:\s*\K[0-9]+')
echo ">>> VM instantiated: ID $VM_ID"

echo ">>> Waiting for VM to be RUNNING..."
until sudo -iu oneadmin onevm show "$VM_ID" | grep -q "STATE.*RUNNING"; do
  sleep 3
done

echo ">>> Done. VM ID: $VM_ID"
