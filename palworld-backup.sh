#!/bin/bash
# Configuration
BACKUP_DIR="/home/steam/palworld-backups"
SAVE_DIR="/home/steam/palworld/Pal/Saved/SaveGames"
DATE=$(date +"%Y-%m-%d_%H-%M")

# Create the backup folder if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Compress the save directory into a timestamped zip/tar file
tar -czf "$BACKUP_DIR/palworld_backup_$DATE.tar.gz" -C "$SAVE_DIR" .

# Automatically delete any backups older than 7 days
find "$BACKUP_DIR" -type f -name "palworld_backup_*.tar.gz" -mtime +7 -delete
