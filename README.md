
# Wazuh Manager Setup Repo (Custom Rules + HTTP `alerts.json` + Push Service)

This repository automates a reproducible Wazuh Manager setup with:
- ✅ Custom Wazuh rules (`local_rules.xml`)
- ✅ HTTP server exposing Wazuh `alerts.json` over port **8000**
- ✅ Push service that streams Wazuh alerts to an external dashboard API (configurable via `.env`)

> Designed for Ubuntu/Debian servers.

---

## Folder Structure

```text
configs/wazuh/
  local_rules.xml           # Custom detection rules (required)
  ossec.conf                # Optional manager config overrides
  local_decoder.xml         # Optional decoders

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

### 1) Installs Wazuh (Quickstart)

`install.sh` installs Wazuh using the official quickstart installer (all-in-one), if Wazuh is not already installed.

### 2) Applies custom rules

Your repo’s `configs/wazuh/local_rules.xml` is copied into:

* `/var/ossec/etc/rules/local_rules.xml`

Optional files (if present in the repo) can also be applied:

* `/var/ossec/etc/ossec.conf`
* `/var/ossec/etc/decoders/local_decoder.xml`

### 3) Enables HTTP exposure of alerts

A systemd service starts:

* `python3 -m http.server 8000`

Serving directory:

* `/var/ossec/logs/alerts`

So `alerts.json` becomes available at:

* `http://<MANAGER_IP>:8000/alerts.json`

### 4) Pushes alerts to your dashboard API

`wazuh-push` tails Wazuh `alerts.json` and sends each JSON alert to your dashboard API endpoint.

The endpoint and API key are set in **ONE file**:

* `/opt/wazuh-push/.env`

---

## Install (End User)

### 1) Clone

```bash
git clone https://github.com/SahiK19/wazuh-manager-setup.git
cd wazuh-manager-setup
```

### 2) Run installer

```bash
chmod +x install.sh
sudo ./install.sh
```

### 3) Configure push destination (ONE file)

Edit:

```bash
sudo nano /opt/wazuh-push/.env
```

Example:

```env
DASHBOARD_URL=http://CHANGE_ME:5000/api/wazuh   #put the ip of your dashboard ec2
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

## Environment Configuration (`.env`)

### Where the `.env` lives

* Installer creates: **`/opt/wazuh-push/.env`**
* Repo template: **`scripts/.env.example`**
* `.env` is ignored by git via `.gitignore` (do not commit secrets)

### Variables explained

| Variable        | Required | Meaning                                      | Example                                |
| --------------- | -------: | -------------------------------------------- | -------------------------------------- |
| `DASHBOARD_URL` |        ✅ | Where Wazuh alerts are POSTed to             | `http://<DASHBOARD_IP>:5000/api/wazuh` |
| `API_KEY`       |        ✅ | Shared secret expected by your dashboard API | `your_api_key_here`                    |
| `ALERTS_FILE`   | Optional | Alerts file to follow                        | `/var/ossec/logs/alerts/alerts.json`   |
| `POLL_SLEEP`    | Optional | Sleep time when there is no new log line     | `0.2`                                  |
| `REQ_TIMEOUT`   | Optional | HTTP request timeout (seconds)               | `3`                                    |

### Apply `.env` changes

After editing `.env`, restart push service:

```bash
sudo systemctl restart wazuh-push
sudo systemctl status wazuh-push --no-pager -l
```

### Test dashboard connectivity (recommended)

Send a test JSON payload to your dashboard endpoint:

```bash
DASHBOARD_URL="$(grep '^DASHBOARD_URL=' /opt/wazuh-push/.env | cut -d= -f2-)"
API_KEY="$(grep '^API_KEY=' /opt/wazuh-push/.env | cut -d= -f2-)"

curl -i -X POST "$DASHBOARD_URL" \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"test":"hello-from-wazuh-manager"}'
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

### View push logs

```bash
sudo journalctl -u wazuh-push -n 200 --no-pager
```

---

## Required Firewall / Security Group Rules

Open inbound (as needed):

* **8000/tcp** for HTTP `alerts.json`

Recommended:

* Restrict **8000/tcp** to your dashboard server IP only (avoid exposing alerts publicly).

---

## Troubleshooting

### `wazuh-push` fails with connection errors

Check:

```bash
sudo journalctl -u wazuh-push -n 200 --no-pager
```

Common reasons:

* wrong `DASHBOARD_URL`
* dashboard server is not reachable
* API key mismatch

### HTTP server works but `alerts.json` is empty

Wazuh might not be generating alerts yet. Trigger activity on an agent or review Wazuh logs.

### Services not found after install

Run:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now wazuh-http-server wazuh-push
```

---

## Notes

* This repo does **not** commit real secrets. Users must configure `.env` locally.
* `.env` should remain ignored via `.gitignore`.
  EOF

````

Then confirm it:
```bash
head -n 40 /opt/wazuh-manager-setup-repo/README.md
````

