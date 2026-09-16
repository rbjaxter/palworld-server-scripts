#!/bin/bash

# Load local environment configuration if it exists (for API credentials)
[ -f .env ] && source .env

# Visual Progress Bar Helper
draw_bar() {
    local pct=$1
    local width=20
    local num_chars=$(( pct * width / 100 ))
    local bar=""
    for ((i=0; i<num_chars; i++)); do bar="${bar}█"; done
    for ((i=num_chars; i<width; i++)); do bar="${bar}░"; done
    echo "$bar"
}

# Sparkline Character Generator
get_spark_char() {
    local val=$1
    if [ "$val" -lt 12 ]; then echo " "
    elif [ "$val" -lt 25 ]; then echo "▂"
    elif [ "$val" -lt 37 ]; then echo "▃"
    elif [ "$val" -lt 50 ]; then echo "▄"
    elif [ "$val" -lt 62 ]; then echo "▅"
    elif [ "$val" -lt 75 ]; then echo "▆"
    elif [ "$val" -lt 87 ]; then echo "▇"
    else echo "█"
    fi
}

# History arrays to hold up to 15 data points
CPU_HIST=()
RAM_HIST=()
MAX_HIST=15

# Clear terminal ONCE before starting
clear

# Real-Time Monitoring Loop (Ctrl + C to exit)
while true; do
printf "\033[H"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}${CYAN}================================================= ${NC}"
echo -e "${BOLD}${CYAN}  LIVE SYSTEM & PALWORLD PERFORMANCE DASHBOARD    ${NC}"
echo -e "${BOLD}${CYAN}             (Press Ctrl+C to Exit)              ${NC}"
echo -e "${BOLD}${CYAN}================================================= ${NC}\n"

# 1. PROCESS & SERVICE STATUS
echo -e "${BOLD}[1] PALWORLD SERVICE STATUS${NC}"
PID=$(pgrep -f PalServer-Linux-Shipping | head -n 1)

if [ -n "$PID" ]; then
    UPTIME=$(ps -p "$PID" -o etime= | tr -d ' ')
    CONN_COUNT=$(ss -un state connected sport = :8211 2>/dev/null | tail -n +2 | wc -l)
    
    # Check REST API Responsiveness using environment variables
    API_HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8212/v1/api/info -u "${PALWORLD_ADMIN_USER:-admin}:${PALWORLD_ADMIN_PASS:-password}" --max-time 2 2>/dev/null || echo "000")
    if [ "$API_HTTP_CODE" -eq 200 ]; then
        API_STATUS="${GREEN}RESPONSIVE (HTTP 200)${NC}"
    else
        API_STATUS="${RED}UNRESPONSIVE (HTTP $API_HTTP_CODE)${NC}"
    fi

    echo -e "Status: ${GREEN}ONLINE${NC} (PID: $PID)"
    echo -e "Server Uptime: $UPTIME | Connected Sessions: ${CYAN}${CONN_COUNT}${NC}"
    echo -e "REST API Status: $API_STATUS"
else
    echo -e "Status: ${RED}OFFLINE${NC} (PalServer process is not running!)"
    echo -e "${YELLOW}--> Check systemctl status or boot it up.${NC}\n"
    sleep 3
    continue
fi

# 2. CPU & CORE MULTITHREADING METRICS
echo -e "\n${BOLD}[2] CPU LOAD & THREAD DISTRIBUTION${NC}"
TOTAL_CORES=$(nproc)
LOAD_AVG=$(uptime | awk -F'load average:' '{ print $2 }')
PROC_CPU=$(ps -p "$PID" -o %cpu= | tr -d ' ')
INT_CPU=${PROC_CPU%.*}
PER_CORE_LOAD=$((INT_CPU / TOTAL_CORES))
[ "$PER_CORE_LOAD" -gt 100 ] && PER_CORE_LOAD=100

# Maintain CPU History Array
CPU_HIST+=("$PER_CORE_LOAD")
if [ "${#CPU_HIST[@]}" -gt "$MAX_HIST" ]; then
    CPU_HIST=("${CPU_HIST[@]:1}")
fi

# Render CPU Sparkline
CPU_SPARK=""
for val in "${CPU_HIST[@]}"; do
    CPU_SPARK="${CPU_SPARK}$(get_spark_char $val)"
done

BAR=$(draw_bar $PER_CORE_LOAD)
echo -e "Available OCPUs/Cores: ${CYAN}${TOTAL_CORES}${NC}"
echo -e "System Load Average (1, 5, 15 min):${YELLOW}${LOAD_AVG}${NC}"
echo -e "PalServer CPU Load: [${CYAN}${BAR}${NC}] ${YELLOW}${PROC_CPU}%${NC} (${PER_CORE_LOAD}% avg/core)"
echo -e "CPU Trend (last 30s): ${CYAN}${CPU_SPARK}${NC}"

if [ "$PER_CORE_LOAD" -gt 85 ]; then
    echo -e "${RED}⚠️ WARNING: CPU load is severe! Server is choking on world ticks/AI pathfinding.${NC}"
elif [ "$INT_CPU" -gt 350 ]; then
    echo -e "${YELLOW}⚠️ NOTICE: Cumulative CPU usage is exceptionally high across cores.${NC}"
else
    echo -e "${GREEN}✓ CPU usage is within healthy threshold.${NC}"
fi

# 3. RAM METRICS & MEMORY LEAK DIAGNOSTICS
echo -e "\n${BOLD}[3] MEMORY LEAK & RAM ANALYSIS${NC}"
MEM_TOTAL_MB=$(free -m | awk '/^Mem:/ {print $2}')
MEM_USED_MB=$(free -m | awk '/^Mem:/ {print $3}')
MEM_AVAIL_MB=$(free -m | awk '/^Mem:/ {print $7}')
PROC_RAM_MB=$(ps -p "$PID" -o rss= | awk '{print int($1/1024)}')
PROC_RAM_PCT=$(ps -p "$PID" -o %mem= | tr -d ' ')
RAM_INT=${PROC_RAM_PCT%.*}

# Maintain RAM History Array
RAM_HIST+=("$RAM_INT")
if [ "${#RAM_HIST[@]}" -gt "$MAX_HIST" ]; then
    RAM_HIST=("${RAM_HIST[@]:1}")
fi

# Render RAM Sparkline
RAM_SPARK=""
for val in "${RAM_HIST[@]}"; do
    RAM_SPARK="${RAM_SPARK}$(get_spark_char $val)"
done

RAM_BAR=$(draw_bar $RAM_INT)
echo -e "Total System RAM: ${CYAN}${MEM_TOTAL_MB} MB${NC}"
echo -e "System Memory Used: ${CYAN}${MEM_USED_MB} MB${NC} (Available: ${CYAN}${MEM_AVAIL_MB} MB${NC})"
echo -e "PalServer Process RAM: [${CYAN}${RAM_BAR}${NC}] ${YELLOW}${PROC_RAM_MB} MB${NC} (${PROC_RAM_PCT}% of total)"
echo -e "RAM Trend (last 30s): ${CYAN}${RAM_SPARK}${NC}"

if [ "$MEM_AVAIL_MB" -lt 1000 ]; then
    echo -e "${RED}⚠️ CRITICAL: Available RAM < 1GB! Memory leak crash imminent. Restart server service ASAP.${NC}"
elif [ "$MEM_AVAIL_MB" -lt 2500 ]; then
    echo -e "${YELLOW}⚠️ WARNING: Memory is getting tight. Palworld memory leak is building up.${NC}"
else
    echo -e "${GREEN}✓ RAM allocation looks stable.${NC}"
fi

# 4. SWAP METRICS (THRASHTIME DETECTOR)
echo -e "\n${BOLD}[4] SWAP MEMORY (DISK THRASHING CHECK)${NC}"
SWAP_TOTAL=$(free -m | awk '/^Swap:/ {print $2}')
SWAP_USED=$(free -m | awk '/^Swap:/ {print $3}')

if [ "$SWAP_TOTAL" -eq 0 ]; then
    echo -e "${YELLOW}Swap is disabled.${NC}"
else
    echo -e "Swap Usage: ${CYAN}${SWAP_USED} MB${NC} / ${SWAP_TOTAL} MB"
    if [ "$SWAP_USED" -gt 1000 ]; then
        echo -e "${RED}⚠️ WARNING: High Swap usage! Linux is forcing RAM onto disk. Expect rubberbanding & lag.${NC}"
    else
        echo -e "${GREEN}✓ Swap status is healthy.${NC}"
    fi
fi

# 5. STORAGE, WORLD SAVE & BACKUP HEALTH
echo -e "\n${BOLD}[5] STORAGE, SAVE & BACKUP HEALTH${NC}"
DISK_AVAIL=$(df -h / | awk 'NR==2 {print $4}')
DISK_PCT=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
DISK_BAR=$(draw_bar $DISK_PCT)

# Check last modified game save using corrected Level.sav path
LATEST_SAVE=$(ls -t /home/steam/palworld/Pal/Saved/SaveGames/*/*/Level.sav 2>/dev/null | head -n 1)
if [ -n "$LATEST_SAVE" ]; then
    SAVE_AGE_MIN=$(( ($(date +%s) - $(stat -c %Y "$LATEST_SAVE" 2>/dev/null || echo 0)) / 60 ))
    SAVE_STATUS="${GREEN}Active (Modified ${SAVE_AGE_MIN}m ago)${NC}"
else
    SAVE_STATUS="${YELLOW}No save files found${NC}"
fi

# Check latest backup archive and test archive integrity
LATEST_BACKUP=$(ls -t /home/steam/palworld-backups/*.tar.gz 2>/dev/null | head -n 1)
if [ -n "$LATEST_BACKUP" ]; then
    BACKUP_AGE_MIN=$(( ($(date +%s) - $(stat -c %Y "$LATEST_BACKUP" 2>/dev/null || echo 0)) / 60 ))
    if tar -tzf "$LATEST_BACKUP" &>/dev/null; then
        BACKUP_STATUS="${GREEN}Valid Archive (${BACKUP_AGE_MIN}m old, Integrity OK)${NC}"
    else
        BACKUP_STATUS="${RED}Corrupted Archive (Integrity test failed!)${NC}"
    fi
else
    BACKUP_STATUS="${YELLOW}No backup archives found yet${NC}"
fi

echo -e "Free Disk Space: [${CYAN}${DISK_BAR}${NC}] ${CYAN}${DISK_AVAIL}${NC} (${DISK_PCT}% used)"
echo -e "World Save Activity: $SAVE_STATUS"
echo -e "Latest Backup Check: $BACKUP_STATUS"

if [ "$DISK_PCT" -gt 88 ]; then
    echo -e "${RED}⚠️ CRITICAL: Storage is nearly full. World autosaves are at risk of failing!${NC}"
else
    echo -e "${GREEN}✓ Disk space is sufficient.${NC}"
fi

# 6. SYSTEMD & KERNEL OUT-OF-MEMORY (OOM) KILLER LOGS
echo -e "\n${BOLD}[6] RECENT SYSTEM & KERNEL ERROR EVENTS (Last 10m)${NC}"
OOM_LOGS=$(sudo dmesg -T 2>/dev/null | grep -i -E 'out of memory|killed process' | tail -n 3)
JOURNAL_ERRORS=$(journalctl -u palworld --since "10 minutes ago" -p err..emerg --no-pager 2>/dev/null | grep -v 'Logs begin at' | grep -v '\-\- No entries \-\-' | tail -n 4)

if [ -n "$OOM_LOGS" ] || [ -n "$JOURNAL_ERRORS" ]; then
    [ -n "$OOM_LOGS" ] && echo -e "${RED}⚠️ KERNEL OOM KILL DETECTED:\n$OOM_LOGS${NC}"
    [ -n "$JOURNAL_ERRORS" ] && echo -e "${RED}⚠️ SYSTEMD ERRORS DETECTED:\n$JOURNAL_ERRORS${NC}"
else
    echo -e "${GREEN}✓ No Kernel OOM kills or system crashes detected.${NC}"
fi

echo -e "\n${BOLD}${CYAN}================================================= ${NC}"

sleep 2

done
