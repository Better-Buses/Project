#!/bin/bash

set -euo pipefail

TEMPLATE_FILE="master-template.one"
VM_NAME="Master"
SG_NAME="Master-SG"

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

# EXPECTED_SG=$(sudo -iu oneadmin onesecgroup show "$SG_NAME" --xml | grep -oP '(?<=<ID>)[0-9]+' | head -1)
# echo ">>> $SG_NAME resolved to ID $EXPECTED_SG"

# CURRENT_SGS=$(sudo -iu oneadmin onevm show "$VM_ID" --xml | grep -oP '(?<=<SECURITY_GROUPS><!\[CDATA\[)[^\]]+')
# echo ">>> Current SGs: $CURRENT_SGS"

# if [ "$CURRENT_SGS" != "$EXPECTED_SG" ]; then
#   echo ">>> Fixing SGs to only $EXPECTED_SG"
#   echo "SECURITY_GROUPS = \"$EXPECTED_SG\"" | sudo -iu oneadmin onevm nic-update "$VM_ID" 0
# else
#   echo ">>> SG already correct"
# fi

echo ">>> Done. VM ID: $VM_ID"
