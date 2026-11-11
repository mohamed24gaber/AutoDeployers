#!/usr/bin/env bash
set -euo pipefail

# TARGET=aws: destroys the shared AWS infrastructure.
PROJECT_NAME=_destroy
source "$(dirname "$0")/common.sh"

if [ "$TARGET" = "microk8s" ]; then
  echo "TARGET=microk8s: nothing on AWS to destroy."
  echo "To remove an app from MicroK8s: microk8s kubectl delete namespace <environment>"
  exit 0
fi

TF=(terraform "-chdir=$ROOT/terraform")

if [ -f "$PLATFORM/terraform.tfstate" ]; then

  echo "Creating Terraform state backup..."
  cp "$PLATFORM/terraform.tfstate" \
     "$PLATFORM/terraform.tfstate.backup.$(date +%Y%m%d-%H%M%S)"

  "${TF[@]}" init -input=false

  echo "Review the resources before confirming destruction."

  "${TF[@]}" destroy -input=false \
    -var "region=eu-north-1" \
    -var "project_name=autodeployers-platform" \
    -var "environment=shared" \
    -var "public_key_path=$PLATFORM/key.pub" \
    -var "instance_type=${INSTANCE_TYPE:-t3.micro}"

  rm -f "$PLATFORM/ip.txt"

  echo "AWS infrastructure destroyed successfully."
  echo "Terraform state and backup preserved."

elif [ -f "$PLATFORM/ip.txt" ]; then

  echo "ERROR: Server IP exists but Terraform state is missing."
  echo "Keeping workspace files. Verify AWS resources manually."
  exit 1

else
  echo "No Terraform state or existing server IP found."
fi
