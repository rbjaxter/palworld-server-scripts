#!/bin/bash
# Palworld Automated Update Script

LOG_FILE="/home/steam/palworld-auto-update.log"
echo "==================================================" >> "$LOG_FILE"
echo "$(date): Starting automated update check..." >> "$LOG_FILE"

# 0. Pre-cleanup: Kill any stray steamcmd or emulation processes to prevent CPU pinning
sudo pkill -9 -f steamcmd || true

# 1. Fetch remote build ID from SteamCMD without downloading the full game
REMOTE_BUILD=$(BOX64_NOBANNER=1 STEAM_PLATFORM=linux64 /home/steam/steamcmd/steamcmd.sh +login anonymous +app_info_update 1 +app_info_print 2394010 +quit | grep -A 20 "branches" | grep -A 5 "public" | grep "buildid" | tr -dc '0-9')

# 2. Check local build ID from the app manifest
LOCAL_BUILD_FILE="/home/steam/palworld/steamapps/appmanifest_2394010.acf"
if [ -f "$LOCAL_BUILD_FILE" ]; then
    LOCAL_BUILD=$(grep "buildid" "$LOCAL_BUILD_FILE" | tr -dc '0-9')
else
    LOCAL_BUILD="0"
fi

echo "$(date): Remote Build: $REMOTE_BUILD | Local Build: $LOCAL_BUILD" >> "$LOG_FILE"

# 3. Compare builds and execute update if a newer one exists
if [ -n "$REMOTE_BUILD" ] && [ "$REMOTE_BUILD" != "$LOCAL_BUILD" ]; then
    echo "$(date): New update detected! Triggering safe update sequence..." >> "$LOG_FILE"

    # Run pre-update backup if script exists
    if [ -f /home/steam/palworld-backup.sh ]; then
        sudo bash /home/steam/palworld-backup.sh >> "$LOG_FILE" 2>&1
    fi

    # Stop the game server cleanly
    sudo systemctl stop palworld
    sleep 30

    # Run SteamCMD update with a retry loop
    max_attempts=3
    attempt=1
    success=false

    while [ $attempt -le $max_attempts ]; do
        if BOX64_NOBANNER=1 STEAM_PLATFORM=linux64 sudo -u steam /home/steam/steamcmd/steamcmd.sh +force_install_dir /home/steam/palworld +login anonymous +app_update 2394010 +quit >> "$LOG_FILE" 2>&1; then
            success=true
            break
        else
            sudo pkill -9 -f steamcmd || true
            sleep 10
            attempt=$((attempt + 1))
        fi
    done

    if [ "$success" = true ]; then
        echo "$(date): Update successful. Restarting server." >> "$LOG_FILE"
    else
        echo "$(date): Error: SteamCMD update failed after $max_attempts attempts!" >> "$LOG_FILE"
    fi

    # Restart server service
    sudo systemctl start palworld
else
    echo "$(date): Server is already up to date." >> "$LOG_FILE"
fi
