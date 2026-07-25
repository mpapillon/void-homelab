#!/bin/bash
#
# .motd.sh - quick server status overview at login.
# Run (not sourced) from .bash_profile, so LC_ALL=C only applies to
# this process and does not affect the locale of the interactive session.

export LC_ALL=C

echo ""
echo "Lithos - ${USER}@$(hostname -f 2>/dev/null || hostname)"
echo ""

# - Uptime and load average
UPTIME_STR=$(uptime -p 2>/dev/null | sed 's/^up //')
LOAD_STR=$(cut -d' ' -f1-3 /proc/loadavg)

printf "%-16s%s\n" "Uptime" "$UPTIME_STR"
printf "%-16s%s\n" "Load average" "$LOAD_STR"

# - Memory (RAM / Swap)
read -r _ MEM_TOTAL MEM_USED _ < <(free -h | awk '/^Mem:/ {print $1, $2, $3}')
read -r _ SWAP_TOTAL SWAP_USED _ < <(free -h | awk '/^Swap:/ {print $1, $2, $3}')

MEM_PCT=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2*100}')
if [ "$(free | awk '/^Swap:/ {print $2}')" -gt 0 ]; then
    SWAP_PCT=$(free | awk '/^Swap:/ {printf "%.0f", $3/$2*100}')
else
    SWAP_PCT=0
fi

printf "%-16s%s / %s   (%s%%)\n" "RAM" "$MEM_USED" "$MEM_TOTAL" "$MEM_PCT"
printf "%-16s%s / %s   (%s%%)\n" "Swap" "$SWAP_USED" "$SWAP_TOTAL" "$SWAP_PCT"

# - Disks
while read -r _ TOTAL USED _ PCT MOUNT; do
    MOUNT_LABEL="${MOUNT#/mnt/}"
    printf "%-16s%s / %s     (%s)\n" "Disque $MOUNT_LABEL" "$USED" "$TOTAL" "$PCT"
done < <(df -h --output=source,size,used,avail,pcent,target 2>/dev/null | grep -E "(^/dev|/mnt/storage|/mnt/backup)")

# - Pending updates
# The xbps cache is synced daily by /etc/cron.daily/xbps-sync (root),
# this script just reads that cache without needing root.
if command -v xbps-install >/dev/null 2>&1; then
    UPDATES_COUNT=$(xbps-install -un 2>/dev/null | wc -l)
    printf "%-16s%s paquets\n" "MAJ en attente" "$UPDATES_COUNT"
fi

# - Last logins
echo ""
echo "Dernières connexions"
if command -v last >/dev/null 2>&1; then
    last -n 3 -F 2>/dev/null | grep -v '^$' | grep -v '^wtmp' | while read -r line; do
        echo "  $line"
    done
fi

echo ""
