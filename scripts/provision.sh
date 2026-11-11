#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"
stage provision

if dry; then
  echo "[dry-run] provision ($TARGET)"
  sleep 1
  exit 0
fi

if [ "$TARGET" = "microk8s" ]; then
  echo "[microk8s] Using this machine as the Kubernetes server. No AWS resources are created."
  echo "127.0.0.1" > "$PLATFORM/ip.txt"
  exit 0
fi

# ---- TARGET=aws: one shared instance. First deployment creates it, later ones reuse it. ----

if [ -f "$PLATFORM/ip.txt" ]; then
  echo "Server already exists ($(cat "$PLATFORM/ip.txt")) - reusing it."
  exit 0
fi

: "${SSH_KEY_PATH:?SSH_KEY_PATH is required for TARGET=aws}"

# Derive the public key from the private SSH key.
ssh-keygen -y -f "$SSH_KEY_PATH" > "$PLATFORM/key.pub"

# Initialize Terraform.
TF=(terraform "-chdir=$ROOT/terraform")
"${TF[@]}" init -input=false

# Detect current public IP automatically.
CURRENT_IP="$(curl -4fsS https://checkip.amazonaws.com | tr -d '\r\n')"

# Allow manual override through ALLOWED_CIDR.
ALLOWED_CIDR="${ALLOWED_CIDR:-${CURRENT_IP}/32}"

echo "Using allowed CIDR: $ALLOWED_CIDR"

# Create AWS infrastructure after interactive Terraform confirmation.
"${TF[@]}" apply \
  -var "region=${AWS_REGION:-eu-north-1}" \
  -var "project_name=autodeployers-platform" \
  -var "environment=shared" \
  -var "public_key_path=$PLATFORM/key.pub" \
  -var "instance_type=${INSTANCE_TYPE:-t3.micro}" \
  -var "allowed_cidr=$ALLOWED_CIDR"

# Save the resulting public IP.
"${TF[@]}" output -raw public_ip > "$PLATFORM/ip.txt"

echo "Server IP: $(cat "$PLATFORM/ip.txt")"
