#!/usr/bin/env python3
import os
import json
import time
import requests

# Optional: load KEY=VALUE from a local .env file (no extra libraries needed)
def load_dotenv(path: str) -> None:
    if not os.path.exists(path):
        return
    with open(path, "r", encoding="utf-8") as f:
        for raw in f:
            line = raw.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            k = k.strip()
            v = v.strip().strip('"').strip("'")
            os.environ.setdefault(k, v)

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
load_dotenv(os.path.join(SCRIPT_DIR, ".env"))

DASHBOARD_URL = os.environ.get("DASHBOARD_URL", "http://127.0.0.1:5000/api/wazuh")
API_KEY = os.environ.get("API_KEY", "CHANGE_ME")

ALERTS_FILE = os.environ.get("ALERTS_FILE", "/var/ossec/logs/alerts/alerts.json")
POLL_SLEEP = float(os.environ.get("POLL_SLEEP", "0.2"))
REQ_TIMEOUT = float(os.environ.get("REQ_TIMEOUT", "3"))

HEADERS = {
    "X-API-Key": API_KEY,
    "Content-Type": "application/json"
}

def follow(file):
    file.seek(0, 2)
    while True:
        line = file.readline()
        if not line:
            time.sleep(POLL_SLEEP)
            continue
        yield line

def main():
    with open(ALERTS_FILE, "r", encoding="utf-8") as f:
        for line in follow(f):
            try:
                alert = json.loads(line.strip())
                r = requests.post(
                    DASHBOARD_URL,
                    headers=HEADERS,
                    json=alert,
                    timeout=REQ_TIMEOUT
                )
                print("Sent alert:", r.status_code)
            except Exception as e:
                print("Push failed:", e)

if __name__ == "__main__":
    main()
