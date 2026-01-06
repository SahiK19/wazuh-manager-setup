Yes — you definitely should. Here’s a **clean, end-user friendly README** you can drop straight into your repo, plus the exact commands to add/commit it.

---

## 1) Create/overwrite `README.md` in your repo

Run this on the EC2 (inside `/opt/wazuh-manager-setup-repo`):

```bash
cat > /opt/wazuh-manager-setup-repo/README.md <<'EOF'
# Wazuh Manager Setup Repo (Custom Rules + HTTP `alerts.json` + Push Service)

This repository automates a reproducible Wazuh Manager setup with:
- ✅ Custom Wazuh rules (`local_rules.xml`)
- ✅ HTTP server exposing Wazuh `alerts.json` over port **8000**
- ✅ Push service that streams Wazuh alerts to an external dashboard API (configurable via `.env`)

> This repo is designed for Ubuntu/Debian servers.

---

## Folder Structure

```

configs/wazuh/
local_rules.xml          # Custom detection rules (required)
ossec.conf               # Optional manager config overrides
local_decoder.xml        # Optional decoders

systemd/
wazuh-http-server.service # Serves /var/ossec/logs/alerts over HTTP (port 8000)
wazuh-push.service        # Pushes alerts to dashboard endpoint

scripts/
wazuh_push.py             # Env-based push script (repo-safe)
requirements.txt          # Python dependency (requests)
.env.example              # One-file configuration template

install.sh                  # Main installer (end user runs this)

````

---

## What This Setup Does

### 1) Wazuh Quickstart install
`install.sh` installs Wazuh using the official quickstart installer (all-in-one).

### 2) Applies custom rules
Your repo’s `configs/wazuh/local_rules.xml` is copied into:
- `/var/ossec/etc/rules/local_rules.xml`

Optional files (if present in repo):
- `/var/ossec/etc/ossec.conf`
- `/var/ossec/etc/decoders/local_decoder.xml`

### 3) Enables HTTP exposure of alerts
A systemd service starts:
- `python3 -m http.server 8000`  
Serving directory:
- `/var/ossec/logs/alerts`

So the file becomes available at:
- `http://<MANAGER_IP>:8000/alerts.json`

### 4) Pushes alerts to your dashboard API
`wazuh-push` tails Wazuh `alerts.json` and sends each JSON alert to your dashboard API endpoint.
The endpoint and API key are set in **ONE file**:
- `/opt/wazuh-push/.env`

---

## Install (End User)

### 1) Clone
```bash
git clone https://github.com/SahiK19/wazuh-manager-setup.git
cd wazuh-manager-setup
````

### 2) Run installer

```bash
chmod +x install.sh
sudo ./install.sh
```

### 3) Configure push destination (ONE file)

```bash
sudo nano /opt/wazuh-push/.env
```

Example:

```env
DASHBOARD_URL=http://CHANGE_ME:5000/api/wazuh
API_KEY=CHANGE_ME
ALERTS_FILE=/var/ossec/logs/alerts/alerts.json
POLL_SLEEP=0.2
REQ_TIMEOUT=3
```

### 4) Restart services

```bash
sudo systemctl restart wazuh-http-server wazuh-push
```

---

## Verify

### Services running

```bash
systemctl status wazuh-http-server wazuh-push --no-pager -l
```

### HTTP alerts working

```bash
curl http://<MANAGER_IP>:8000/alerts.json
```

---

## Required Firewall / Security Group Rules

Open inbound:

* **8000/tcp** (for HTTP alerts.json)
* Wazuh agent ports as needed (depends on your environment)

Recommended:

* Restrict `8000/tcp` to your dashboard server IP only (don’t expose to the whole internet).

---

## Troubleshooting

### `wazuh-push` fails with connection errors

Check:

```bash
sudo journalctl -u wazuh-push -n 200 --no-pager
```

Most common reasons:

* wrong `DASHBOARD_URL`
* dashboard server is not reachable
* API key mismatch

### HTTP server works but `alerts.json` is empty

Wazuh might not be generating alerts yet. Trigger a test event or check Wazuh logs.

### Services not found after install

Run:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now wazuh-http-server wazuh-push
```

---

## Notes

* This repo does NOT commit any real secrets. Users must configure `.env` locally.
* `.env` is ignored via `.gitignore`.
  EOF

````

---

## 2) Confirm the README exists
```bash
ls -lah /opt/wazuh-manager-setup-repo/README.md
````

---

## 3) Commit README into git

```bash
cd /opt/wazuh-manager-setup-repo
git add README.md
git commit -m "Add README with setup and usage instructions"
```

---

