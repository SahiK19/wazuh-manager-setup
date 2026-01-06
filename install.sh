#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TS="$(date +%Y%m%d_%H%M%S)"

echo "[INFO] Repo dir: $REPO_DIR"

if [[ "${EUID}" -ne 0 ]]; then
  echo "[ERROR] Run as root: sudo ./install.sh"
  exit 1
fi

# --- OS deps ---
echo "[INFO] Installing prerequisites..."
apt update -y
apt install -y curl ca-certificates python3 python3-pip git

# --- Install Wazuh (skip if already installed) ---
if systemctl list-unit-files | grep -q "^wazuh-manager\.service"; then
  echo "[INFO] Wazuh appears installed (wazuh-manager.service exists). Skipping quickstart install."
else
  echo "[INFO] Installing Wazuh using official quickstart installer..."
  cd /root
  # Quickstart command from Wazuh docs:
  # curl -sO https://packages.wazuh.com/4.14/wazuh-install.sh && sudo bash ./wazuh-install.sh -a
  curl -sO https://packages.wazuh.com/4.14/wazuh-install.sh
  bash ./wazuh-install.sh -a
fi

# --- Backup existing Wazuh configs ---
echo "[INFO] Backing up existing Wazuh configs to /root/wazuh-backup-$TS ..."
mkdir -p "/root/wazuh-backup-$TS"
[[ -f /var/ossec/etc/ossec.conf ]] && cp -v /var/ossec/etc/ossec.conf "/root/wazuh-backup-$TS/ossec.conf"
[[ -f /var/ossec/etc/rules/local_rules.xml ]] && cp -v /var/ossec/etc/rules/local_rules.xml "/root/wazuh-backup-$TS/local_rules.xml"
[[ -f /var/ossec/etc/decoders/local_decoder.xml ]] && cp -v /var/ossec/etc/decoders/local_decoder.xml "/root/wazuh-backup-$TS/local_decoder.xml"

# --- Deploy repo configs into Wazuh ---
echo "[INFO] Deploying repo configs into Wazuh..."
install -m 0644 "$REPO_DIR/configs/wazuh/local_rules.xml" /var/ossec/etc/rules/local_rules.xml

if [[ -f "$REPO_DIR/configs/wazuh/ossec.conf" ]]; then
  install -m 0644 "$REPO_DIR/configs/wazuh/ossec.conf" /var/ossec/etc/ossec.conf
fi

if [[ -f "$REPO_DIR/configs/wazuh/local_decoder.xml" ]]; then
  install -m 0644 "$REPO_DIR/configs/wazuh/local_decoder.xml" /var/ossec/etc/decoders/local_decoder.xml
fi

# Restart wazuh-manager to apply rules/config
echo "[INFO] Restarting wazuh-manager..."
systemctl enable --now wazuh-manager || true
systemctl restart wazuh-manager || true

# --- Install push script into /opt/wazuh-push ---
echo "[INFO] Installing push script to /opt/wazuh-push ..."
mkdir -p /opt/wazuh-push
install -m 0755 "$REPO_DIR/scripts/wazuh_push.py" /opt/wazuh-push/wazuh_push.py
install -m 0644 "$REPO_DIR/scripts/requirements.txt" /opt/wazuh-push/requirements.txt

# Create .env only if missing (do NOT overwrite user's config)
if [[ ! -f /opt/wazuh-push/.env ]]; then
  install -m 0644 "$REPO_DIR/scripts/.env.example" /opt/wazuh-push/.env
  echo "[INFO] Created /opt/wazuh-push/.env (edit this file for DASHBOARD_URL/API_KEY)."
else
  echo "[INFO] /opt/wazuh-push/.env already exists, not overwriting."
fi

echo "[INFO] Installing Python dependencies..."
python3 -m pip install --upgrade pip
python3 -m pip install -r /opt/wazuh-push/requirements.txt

# --- Deploy systemd services ---
echo "[INFO] Deploying systemd unit files..."
install -m 0644 "$REPO_DIR/systemd/wazuh-http-server.service" /etc/systemd/system/wazuh-http-server.service
install -m 0644 "$REPO_DIR/systemd/wazuh-push.service" /etc/systemd/system/wazuh-push.service

echo "[INFO] Enabling services..."
systemctl daemon-reload
systemctl enable --now wazuh-http-server
systemctl enable --now wazuh-push

echo "[INFO] Installation complete."
echo "Next steps:"
echo "  1) Edit: nano /opt/wazuh-push/.env"
echo "  2) Check: systemctl status wazuh-http-server wazuh-push --no-pager -l"
echo "  3) Test HTTP: curl http://<MANAGER_PUBLIC_IP>:8000/alerts.json"
