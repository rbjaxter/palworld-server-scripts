#!/bin/bash

# Load environment variables
if [ -f "$(dirname "$0")/.env" ]; then
    export $(cat "$(dirname "$0")/.env" | xargs)
fi

# API Configuration
ADMIN_USER="${PALWORLD_ADMIN_USER:-admin}"
ADMIN_PASS="${PALWORLD_ADMIN_PASS:-password}"
API_URL="http://localhost:8212/v1/api"

send_announcement() {
    curl -s -u "${ADMIN_USER}:${ADMIN_PASS}" -X POST "${API_URL}/announce" \
         -H "Content-Type: application/json" \
         -d "{\"message\": \"$1\"}"
}

# 1. 5-minute warning (Runs at T-minus 5:00)
send_announcement "[Server] Restarting in 5 minutes for scheduled maintenance!"
sleep 240

# 2. 1-minute warning (Runs at T-minus 1:00)
send_announcement "[Server] Restarting in 1 minute! Please wrap up."
sleep 45

# 3. Dedicated Save step (Runs at T-minus 15s to allow disk flush)
send_announcement "[Server] Saving world data to disk..."
curl -s -u "${ADMIN_USER}:${ADMIN_PASS}" -X POST "${API_URL}/save" \
     -H "Content-Type: application/json"
sleep 10

# 4. Final countdown and graceful API shutdown (Runs at T-minus 5s)
send_announcement "[Server] Shutting down now!"
curl -s -u "${ADMIN_USER}:${ADMIN_PASS}" -X POST "${API_URL}/shutdown" \
     -H "Content-Type: application/json" \
     -d '{"waittime": 0}'

# Give the API process a generous 15 seconds to exit cleanly on its own
sleep 15

# 5. Service wrap-up and restart (Handled via smart auto-update cron)
sudo systemctl stop palworld
sleep 5
sudo systemctl start palworld