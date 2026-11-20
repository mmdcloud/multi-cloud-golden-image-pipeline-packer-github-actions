#!/usr/bin/env bash
# ==============================================================================
# Golden Image Bootstrapping Script
# Prepares the target instance by installing Python, Ansible, and Goss for testing
# ==============================================================================
set -euo pipefail

echo "==> [Bootstrap] Starting system initialization on builder: ${BUILDER_TYPE:-unknown}..."

# Wait for apt lock release (especially on cloud instances running cloud-init)
echo "==> [Bootstrap] Waiting for apt locks to release..."
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
    echo "Waiting for other package management processes to finish..."
    sleep 3
done

# Configure apt for non-interactive execution
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

echo "==> [Bootstrap] Updating package repository cache..."
apt-get update -y

echo "==> [Bootstrap] Installing essential utilities & prerequisites..."
apt-get install -y --no-install-recommends \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    python3 \
    python3-pip \
    python3-apt \
    unzip \
    jq

# Install Ansible locally for running local provisioners
echo "==> [Bootstrap] Installing Ansible..."
if ! command -v ansible &>/dev/null; then
    apt-get install -y ansible
fi

# Install Goss (Server validation and compliance tool)
GOSS_VERSION="v0.4.9"
GOSS_URL="https://github.com/goss-org/goss/releases/download/${GOSS_VERSION}/goss-linux-amd64"
echo "==> [Bootstrap] Installing Goss test runner (${GOSS_VERSION})..."
curl -sSL -o /usr/local/bin/goss "${GOSS_URL}"
chmod +rx /usr/local/bin/goss

echo "==> [Bootstrap] System bootstrap completed successfully."
