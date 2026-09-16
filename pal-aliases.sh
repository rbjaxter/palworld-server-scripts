# ==========================================
# PALWORLD SERVER CLI MANAGEMENT TOOLKIT
# ==========================================

# /help - Displays the full list of available server management commands
/help() {
    echo "=================================================="
    echo "        PALWORLD SERVER COMMAND CHEAT SHEET     "
    echo "=================================================="
    echo "  /help             - Show this help menu"
    echo "  /status           - Check if the Palworld service is running"
    echo "  /version          - Query server version via REST API"
    echo "  /perfcheck        - Run Palworld deep health & performance check"
    echo "  /performance      - Launch live Task Manager style monitor"
    echo "  /start            - Start the Palworld server service"
    echo "  /stop             - Gracefully stop the Palworld server service"
    echo "  /restart          - Restart the Palworld server service"
    echo "  /reboot           - Stop Palworld safely, then reboot Oracle host"
    echo "  /logs             - Stream live server logs (Ctrl+C to exit)"
    echo "  /update           - Safely backup, update via SteamCMD, and restart"
    echo "  /updatemap        - Pull and restart the live map container"
    echo "  /backup           - Run a manual server backup script"
    echo "  /listbackups      - List all saved backup archives"
    echo "  /deletebackups    - Permanently delete all backup archives"
    echo "  /resetworld       - Wipe the world save to regenerate a fresh world"
    echo "  /serverip         - Show public IP and port configuration"
    echo "  /cron             - Check active system crontab tasks"
    echo "=================================================="
}

# /status - Check systemd service status
/status() {
    sudo systemctl status palworld --no-pager
}

# /version - Query server version and metadata from REST API
/version() {
    echo "Querying Palworld server version..."
    [ -f ~/palworld-server-scripts/.env ] && source ~/palworld-server-scripts/.env
    curl -s http://localhost:8212/v1/api/info -u "${PALWORLD_ADMIN_USER:-admin}:${PALWORLD_ADMIN_PASS:-password}"
    echo ""
}

# /perfcheck - Launch live Palworld performance & health dashboard
/perfcheck() {
    /usr/local/bin/perfcheck "$@"
}

# /performance - Real-time task manager interface (Press 'q' to exit)
/performance() {
    if command -v htop &> /dev/null; then
        htop
    else
        top
    fi
}

# /start - Power on server
/start() {
    echo "Starting Palworld server service..."
    sudo systemctl start palworld
}

# /stop - Gracefully stop server with flush pause
/stop() {
    echo "Stopping Palworld server service..."
    sudo systemctl stop palworld
    echo "Waiting 30 seconds for world data to completely save..."
    sleep 30
}

# /restart - Gracefully restart server with save flush
/restart() {
    echo "Gracefully restarting Palworld server service..."
    sudo systemctl stop palworld
    echo "Waiting 30 seconds for world data to completely save..."
    sleep 30
    sudo systemctl start palworld
    echo "Palworld server restarted successfully."
}

# /reboot - Gracefully stop Palworld server with flush, then reboot Oracle host
/reboot() {
    echo "=================================================="
    echo "  🔄 INITIATING GRACEFUL SYSTEM REBOOT"
    echo "=================================================="
    echo "Stopping Palworld server service..."
    sudo systemctl stop palworld

    echo "Waiting 30 seconds for world data to completely save..."
    sleep 30

    echo "Rebooting Ubuntu host machine..."
    sudo reboot
}

# /logs - Stream live logs
/logs() {
    sudo journalctl -u palworld -f
}

# /update - Safely backup, purge stale steamcmd, update, and restart
/update() {
    echo "=================================================="
    echo "  🛡️  INITIATING SAFE PALWORLD SERVER UPDATE"
    echo "=================================================="

    # 0. Kill any lingering or stuck steamcmd processes first
    echo "Step 0/5: Cleaning up any stale background steamcmd tasks..."
    sudo pkill -9 -f steamcmd || true

    # 1. Run backup first if the backup script exists
    if [ -f /home/steam/palworld-backup.sh ]; then
        echo "Step 1/5: Running pre-update server backup..."
        sudo bash /home/steam/palworld-backup.sh
    else
        echo "Warning: Backup script not found at /home/steam/palworld-backup.sh, skipping backup!"
    fi

    # 2. Gracefully stop the server so state is written safely
    echo "Step 2/5: Stopping Palworld server service..."
    sudo systemctl stop palworld

    # 3. Wait 30 seconds for world states to fully flush and save
    echo "Step 3/5: Waiting 30 seconds for world data to completely save..."
    sleep 30

    # 4. Run SteamCMD update with a retry loop (up to 3 attempts)
    echo "Step 4/5: Updating Palworld server via SteamCMD..."
    local max_attempts=3
    local attempt=1
    local success=false

    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt of $max_attempts..."
        if BOX64_NOBANNER=1 STEAM_PLATFORM=linux64 sudo -u steam /home/steam/steamcmd/steamcmd.sh +force_install_dir /home/steam/palworld +login anonymous +app_update 2394010 +quit; then
            success=true
            break
        else
            echo "Warning: SteamCMD update attempt $attempt failed or hung. Retrying in 10 seconds..."
            sudo pkill -9 -f steamcmd || true
            sleep 10
            attempt=$((attempt + 1))
        fi
    done

    if [ "$success" = false ]; then
        echo "Error: SteamCMD failed after $max_attempts attempts!"
        echo "Aborting server restart to prevent running outdated or corrupted binaries."
        return 1
    fi

    # 5. Restart the service
    echo "Step 5/5: Restarting Palworld server service..."
    sudo systemctl start palworld

    echo "=================================================="
    echo "  ✅ UPDATE COMPLETE & SERVER RESTARTED"
    echo "=================================================="
}

# /updatemap - Pull latest map image from ghcr.io and recreate the live map container cleanly
/updatemap() {
    if [ -d /home/ubuntu/palworld-map ]; then
        echo "Updating palworld-live-map container..."
        cd /home/ubuntu/palworld-map
        docker-compose pull
        docker rm -f palworld-map 2>/dev/null || true
        docker-compose up -d
        echo "Live map update complete!"
    else
        echo "Error: Map directory /home/ubuntu/palworld-map not found."
    fi
}

# /backup - Execute manual backup script
/backup() {
    if [ -f /home/steam/palworld-backup.sh ]; then
        sudo bash /home/steam/palworld-backup.sh
    else
        echo "Backup script not found at /home/steam/palworld-backup.sh"
    fi
}

# /listbackups - Show contents of backup directory
/listbackups() {
    sudo ls -lh /home/steam/palworld-backups/ 2>/dev/null || sudo ls -lh /home/steam/ | grep backup
}

# /deletebackups - Delete all server backup archives with confirmation
/deletebackups() {
    echo "=================================================="
    echo "  ⚠️  DANGER: BACKUP DELETION INITIATED"
    echo "=================================================="
    echo "This will permanently delete all saved server backup archives!"
    read -p "Are you sure you want to delete all backups? Type 'YES' to confirm: " confirm

    if [ "$confirm" != "YES" ]; then
        echo "Backup deletion cancelled."
        return
    fi

    echo "Deleting backup archives..."
    sudo bash -c 'rm -rf /home/steam/palworld-backups/*'
    echo "All backups have been permanently cleared."
}

# /resetworld - Wipe the world save and optionally clear backups to start fresh
/resetworld() {
    echo "=================================================="
    echo "  ⚠️  DANGER: WORLD WIPE INITIATED"
    echo "=================================================="
    echo "This will permanently delete your current Palworld world save!"
    read -p "Are you absolutely sure you want to do this? Type 'YES' to confirm: " confirm

    if [ "$confirm" != "YES" ]; then
        echo "World reset cancelled."
        return
    fi

    echo "Stopping Palworld server service..."
    sudo systemctl stop palworld
    echo "Waiting 30 seconds for shutdown stabilization..."
    sleep 30

    echo "Deleting world save files..."
    sudo rm -rf /home/steam/palworld/Pal/Saved/SaveGames/0

    read -p "Do you also want to delete all server backups? (y/N): " backup_confirm
    if [[ "$backup_confirm" =~ ^[Yy]$ ]]; then
        echo "Deleting backup directory..."
        sudo bash -c 'rm -rf /home/steam/palworld-backups/*'
        echo "Backups cleared."
    else
        echo "Backups preserved."
    fi

    echo "Restarting Palworld server service with a fresh world..."
    sudo systemctl start palworld
    echo "Done! A fresh world has been generated."
}

# /serverip - Display connection details
/serverip() {
    echo "Public IP:   $(curl -s ifconfig.me)"
}

# /cron - View current user/root cron jobs
/cron() {
    sudo crontab -l
}

# /settings - Display current Palworld server configuration settings
/settings() {
    cat /home/steam/palworld/Pal/Saved/Config/LinuxServer/PalWorldSettings.ini
}

