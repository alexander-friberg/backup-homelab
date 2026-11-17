#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"

read -r -d '' CHECKS <<'EOF'
FAIL=0
ok()   { echo "  OK    $*"; }
bad()  { echo "  FAIL  $*"; FAIL=1; }
warn() { echo "  WARN  $*"; }

SCRIPT=/usr/local/sbin/backup-and-update.sh
DIR="{{ remote_backup_dir }}"
LOG="{{ cron_log }}"

# 1. cron service
SVC=""
for s in cron crond cronie; do systemctl is-active --quiet "$s" 2>/dev/null && SVC=$s; done
if [ -n "$SVC" ]; then
  ok "cron service '$SVC' is running"
  systemctl is-enabled --quiet "$SVC" && ok "cron service is enabled at boot" || bad "cron service is not enabled at boot"
else
  bad "no cron service is running"
fi

# 2. crontab entry
ENTRY=$(crontab -l -u root 2>/dev/null | grep -A1 '^#Ansible: weekly backup and update' | tail -n 1)
if echo "$ENTRY" | grep -q "$SCRIPT"; then
  ok "root crontab: $ENTRY"
else
  bad "weekly job missing from root crontab"
fi

# 3. the script itself
if [ -f "$SCRIPT" ]; then
  PERM=$(stat -c '%U %a' "$SCRIPT")
  [ "$PERM" = "root 700" ] && ok "$SCRIPT exists (owner root, mode 700)" || bad "$SCRIPT has owner/mode '$PERM', expected 'root 700'"
  bash -n "$SCRIPT" 2>/dev/null && ok "script syntax is valid" || bad "script has a syntax error"
else
  bad "$SCRIPT does not exist"
fi

# 4. backups
NEWEST=$(ls -1t "$DIR"/*.tar.gz 2>/dev/null | head -n 1)
if [ -n "$NEWEST" ]; then
  COUNT=$(ls -1 "$DIR"/*.tar.gz | wc -l)
  AGE=$(( ($(date +%s) - $(stat -c %Y "$NEWEST")) / 86400 ))
  SIZE=$(du -h "$NEWEST" | cut -f1)
  MSG="newest backup: $NEWEST ($SIZE, $AGE days old, $COUNT kept)"
  if [ ! -s "$NEWEST" ]; then bad "newest backup is empty: $NEWEST"
  elif [ "$AGE" -gt 8 ]; then bad "$MSG - older than a week"
  else ok "$MSG"; fi
else
  warn "no backups in $DIR yet"
fi

# 5. last cron run (only cron runs write to the log)
if [ -f "$LOG" ]; then
  LAST=$(grep '^=== ' "$LOG" | tail -n 1)
  case "$LAST" in
    *done*) ok "last cron run finished: $LAST" ;;
    *)      bad "last cron run did not finish (last step: $LAST) - see $LOG" ;;
  esac
else
  warn "$LOG does not exist yet (the job hasn't run from cron)"
fi

[ "$FAIL" -eq 0 ] && echo "  => all checks passed" || echo "  => some checks FAILED"
exit "$FAIL"
EOF

ansible "${1:-servers}" -b -m shell -a "$CHECKS" -e @backup_config.yml
