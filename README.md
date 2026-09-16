# Palworld Server Management Toolkit & Scripts

A smorgasbord of automation scripts, maintenance routines, and terminal CLI management tools designed to run and maintain a dedicated Palworld game server on Ubuntu (optimized for Oracle Cloud Infrastructure environments).

This whole process is a fever dream so I probably can't help with any of this, but may it prove useful to someone.

---

## Environment Architecture

* **Host OS:** Ubuntu Linux running on a dedicated cloud instance.
    * Originally using oracle free plan (2 OCPUs/12GB RAM but upgraded to 4 OCPUs for 4+ players)
* **Game Server Service:** Managed via systemd (`palworld.service`) running under a dedicated `steam` system user.
* **Update Engine:** Automated SteamCMD integration with a lightweight build-ID tracker and safe process cleanup.
* **Live Map Integration:** Integrated with a containerized Docker setup (`palworld-live-map` using a custom container image mapping player coordinates and game data): https://github.com/LukeHollandDev/palworld-live-map/
* **Configuration:** Environment variables managed securely via a local `.env` file (`.gitignore` protected).

---

## Repository File Structure

* `pal-aliases.sh` — Terminal CLI management toolkit containing custom shell functions/aliases (e.g., `/status`, `/update`, `/restart`, `/perfcheck`).
* `palworld-auto-update.sh` — Checks for remote Steam builds, executes a safety backup, and performs a clean SteamCMD application update with retry logic.
* `palworld-backup.sh` — Creates timestamped tarball archives of the world save directory (`/home/steam/palworld/Pal/Saved/SaveGames`) and rotates/deletes archives older than 7 days.
* `palworld-restart-sequence.sh` — Gracefully broadcasts in-game chat warnings via the REST API, triggers a manual world save, shuts down the API cleanly, and restarts the service.
* `perfcheck.sh` — Real-time performance dashboard tracking CPU thread load, memory leak growth, disk space, swap thrashing, and systemd OOM/kernel errors.
* `.env.example` — Template file for defining local administrative REST API credentials.

---

## Terminal CLI Management Toolkit (`pal-aliases.sh`)

Once sourced in your shell profile (`~/.bashrc`), these helper commands are available:

| Command | Description |
| :--- | :--- |
| `/help` | Displays the full list of available server management commands. |
| `/status` | Checks if the Palworld systemd service is actively running. |
| `/version` | Queries the server version and metadata securely via the REST API. |
| `/perfcheck` | Runs the deep health and performance diagnostics script. |
| `/performance` | Launches a live task manager (`htop`/`top`) style resource monitor. |
| `/start` | Powers on the Palworld server service. |
| `/stop` | Gracefully stops the server service with a 30-second save/flush pause. |
| `/restart` | Safely restarts the server service with a world data save flush. |
| `/reboot` | Stops Palworld safely and reboots the entire Ubuntu host machine. |
| `/logs` | Streams live server logs via `journalctl` (Ctrl+C to exit). |
| `/update` | Safely runs a pre-update backup, stops the server, updates via SteamCMD, and restarts. |
| `/updatemap` | Pulls the latest container image from `ghcr.io` and safely recreates the **palworld-live-map** Docker container. |
| `/backup` | Triggers a manual server backup archive script. |
| /`listbackups` | Lists all saved server backup tarball archives. |
| `/deletebackups` | Permanently clears all backup archives (requires confirmation). |
| `/resetworld` | Wipes the current world save to regenerate a fresh world. |
| `/serverip` | Displays the public IP and port configuration. |
| `/cron` | Checks active system crontab tasks. |
| `/settings` | Displays current configuration values from `PalWorldSettings.ini`. |

good luck and godspeed o7
