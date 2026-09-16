# Palworld Server Scripts

A collection of lightweight automation, backup, and live monitoring scripts designed for hosting a dedicated Palworld game server on Ubuntu Linux.

## Included Files
* `perfcheck.sh`: A real-time terminal dashboard tracking CPU threading, memory leak growth, storage health, and save/backup file integrity.
* `palworld-auto-update.sh`: Manages automated update checks and server notifications.
* `palworld-backup.sh`: Handles compressed world backups and archive verification.
* `palworld-restart-sequence.sh`: Executes safe, orderly server reboots.
* `crontab_backup.txt`: Example task scheduling configuration.

## Configuration
Copy `.env.example` to `.env` and configure your local REST API credentials before running monitoring scripts:
```bash
cp .env.example .env
nano .env
```
