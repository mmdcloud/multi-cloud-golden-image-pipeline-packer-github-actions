#!/usr/bin/env bash
# ==============================================================================
# Golden Image Sanitization & De-provisioning Script
# Removes all machine identities, credentials, temporary files, and cloud-init state
# Prevents secret leakage and ensures unique identity generation upon deployment.
# ==============================================================================
set -euo pipefail

echo "======================================================================"
echo " Starting Image Sanitization and De-provisioning for: ${BUILDER_TYPE:-generic}"
echo "======================================================================"

# 1. Stop Logging & Services to allow clean log truncations
echo "==> Stopping logging services..."
systemctl stop systemd-journald 2>/dev/null || true
systemctl stop rsyslog 2>/dev/null || true
systemctl stop auditd 2>/dev/null || true

# 2. Cloud-specific agent de-provisioning
case "${BUILDER_TYPE:-}" in
    *azure*)
        echo "==> [Azure] Deprovisioning Azure Linux Agent (waagent)..."
        if command -v waagent &>/dev/null; then
            waagent -force -deprovision+user || true
            rm -rf /var/lib/waagent
        fi
        ;;
    *googlecompute*)
        echo "==> [GCP] Cleaning Google Guest Agent cache..."
        rm -rf /var/lib/google/* 2>/dev/null || true
        ;;
    *amazon*)
        echo "==> [AWS] Cleaning AWS SSM & EC2 credentials cache..."
        rm -rf /var/lib/amazon/ssm/* 2>/dev/null || true
        ;;
esac

# 3. Clean Cloud-Init State & Seeds
echo "==> Resetting cloud-init state..."
if command -v cloud-init &>/dev/null; then
    cloud-init clean --logs --seed || true
fi
rm -rf /var/lib/cloud/*

# 4. Remove Unique Machine IDs (forces regeneration on first boot of cloned image)
echo "==> Resetting unique machine IDs..."
truncate -s 0 /etc/machine-id
if [[ -f /var/lib/dbus/machine-id ]]; then
    rm -f /var/lib/dbus/machine-id
    ln -s /etc/machine-id /var/lib/dbus/machine-id
fi

# 5. Clean SSH Host Keys & User Keys
echo "==> Removing SSH host keys & authorized keys (will regenerate on boot)..."
rm -f /etc/ssh/ssh_host_*
rm -f /root/.ssh/authorized_keys
rm -f /home/*/.ssh/authorized_keys 2>/dev/null || true

# Remove temporary packer user if created
if id "packer" &>/dev/null; then
    echo "==> Removing temporary packer build user..."
    userdel -r -f packer 2>/dev/null || true
fi

# 6. Clean Package Manager caches & temporary files
echo "==> Cleaning apt and temporary caches..."
apt-get clean
apt-get autoremove -y --purge
rm -rf /var/lib/apt/lists/*
rm -rf /tmp/* /var/tmp/* /usr/local/bin/goss

# 7. Truncate System & Audit Logs (never leave build logs in production golden image)
echo "==> Truncating system logs..."
find /var/log -type f -exec truncate -s 0 {} +

# 8. Clear Shell History & Credentials
echo "==> Clearing shell history and environment..."
rm -f /root/.bash_history
rm -f /home/*/.bash_history 2>/dev/null || true
history -c || true

# 9. Sync filesystem to disk
echo "==> Syncing filesystems..."
sync

echo "======================================================================"
echo " Sanitization and De-provisioning complete. Image is ready for seal. "
echo "======================================================================"
