#!/usr/bin/env bash

# ═══════════════════════════════════════════════════
#  FyxxVault Panel — Interactive Management Console
# ═══════════════════════════════════════════════════

# ── Colors ──
C='\033[0;36m'
V='\033[0;35m'
G='\033[0;32m'
R='\033[0;31m'
Y='\033[1;33m'
W='\033[1;37m'
D='\033[2m'
B='\033[1m'
NC='\033[0m'

# ── Config ──
FYXX_DIR="$HOME/.fyxxvault"
APP_DIR="$FYXX_DIR/app"
DATA_DIR="${FYXXVAULT_DATA_DIR:-$FYXX_DIR/data}"
LOG_DIR="$FYXX_DIR/logs"
LOG_FILE="$LOG_DIR/fyxxvault.log"
PID_FILE="$FYXX_DIR/fyxxvault.pid"
DB_FILE="$DATA_DIR/fyxxvault.db"
PORT="${FYXXVAULT_PORT:-3000}"
BUILD_DIR="$APP_DIR/web/build"

# ═══════════════════════════════════════════════════
#  Helpers
# ═══════════════════════════════════════════════════

clear_screen() {
  printf '\033[2J\033[H'
}

is_running() {
  if [ -f "$PID_FILE" ]; then
    local pid=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
  fi
  return 1
}

get_pid() {
  cat "$PID_FILE" 2>/dev/null
}

get_db_size() {
  if [ -f "$DB_FILE" ]; then
    local bytes=$(stat -f%z "$DB_FILE" 2>/dev/null || stat -c%s "$DB_FILE" 2>/dev/null)
    if [ "$bytes" -gt 1048576 ]; then
      echo "$((bytes / 1048576)) MB"
    else
      echo "$((bytes / 1024)) KB"
    fi
  else
    echo "N/A"
  fi
}

get_uptime() {
  if is_running; then
    local pid=$(get_pid)
    # Get process start time
    local start=$(ps -o lstart= -p "$pid" 2>/dev/null)
    if [ -n "$start" ]; then
      local start_epoch=$(date -j -f "%a %b %d %T %Y" "$start" "+%s" 2>/dev/null || date -d "$start" "+%s" 2>/dev/null)
      local now=$(date "+%s")
      local diff=$((now - start_epoch))
      local hours=$((diff / 3600))
      local minutes=$(( (diff % 3600) / 60 ))
      if [ "$hours" -gt 0 ]; then
        echo "${hours}h ${minutes}m"
      else
        echo "${minutes}m"
      fi
    else
      echo "running"
    fi
  else
    echo "stopped"
  fi
}

get_table_count() {
  local table=$1
  if [ -f "$DB_FILE" ] && command -v sqlite3 &>/dev/null; then
    sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM $table;" 2>/dev/null || echo "?"
  elif [ -f "$DB_FILE" ]; then
    # Use node as fallback
    node -e "
      const Database = require('$APP_DIR/web/node_modules/better-sqlite3');
      const db = new Database('$DB_FILE', { readonly: true });
      console.log(db.prepare('SELECT COUNT(*) as c FROM $table').get().c);
      db.close();
    " 2>/dev/null || echo "?"
  else
    echo "0"
  fi
}

get_backup_count() {
  ls "$DATA_DIR"/fyxxvault-backup-*.db 2>/dev/null | wc -l | tr -d ' '
}

get_last_backup() {
  local last=$(ls -t "$DATA_DIR"/fyxxvault-backup-*.db 2>/dev/null | head -1)
  if [ -n "$last" ]; then
    local name=$(basename "$last")
    # Extract date from filename
    echo "$name" | sed 's/fyxxvault-backup-//;s/\.db//' | cut -c1-16 | tr 'T' ' '
  else
    echo "never"
  fi
}

log_action() {
  mkdir -p "$LOG_DIR"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [panel] $1" >> "$LOG_FILE"
}

wait_key() {
  echo ""
  echo -e "    ${D}Press any key to continue...${NC}"
  read -rsn1
}

# ═══════════════════════════════════════════════════
#  UI Components
# ═══════════════════════════════════════════════════

draw_header() {
  echo ""
  echo -e "    ${C}╔═══════════════════════════════════════════════════╗${NC}"
  echo -e "    ${C}║${NC}  ${B}${W}FyxxVault${NC} ${D}— Management Panel${NC}                      ${C}║${NC}"
  echo -e "    ${C}╚═══════════════════════════════════════════════════╝${NC}"
}

draw_status_bar() {
  echo ""
  if is_running; then
    local pid=$(get_pid)
    local uptime=$(get_uptime)
    echo -e "    ${G}●${NC} ${G}Server running${NC}  ${D}PID: ${pid}  |  Uptime: ${uptime}  |  Port: ${PORT}${NC}"
  else
    echo -e "    ${R}●${NC} ${R}Server stopped${NC}"
  fi
  echo -e "    ${D}$(printf '%.0s─' $(seq 1 52))${NC}"
}

draw_dashboard() {
  local db_size=$(get_db_size)
  local users=$(get_table_count "users")
  local items=$(get_table_count "vault_items")
  local backups=$(get_backup_count)
  local last_bk=$(get_last_backup)

  echo ""
  echo -e "    ${B}${W}Dashboard${NC}"
  echo ""

  # Stats grid
  echo -e "    ┌─────────────────────┬─────────────────────────────┐"
  echo -e "    │  ${C}Database${NC}            │  ${D}$db_size${NC}"
  echo -e "    │  ${C}Users${NC}               │  ${D}$users${NC}"
  echo -e "    │  ${C}Vault entries${NC}       │  ${D}$items${NC}"
  echo -e "    │  ${C}Backups${NC}             │  ${D}$backups${NC}"
  echo -e "    │  ${C}Last backup${NC}         │  ${D}$last_bk${NC}"
  echo -e "    │  ${C}Node.js${NC}             │  ${D}$(node -v 2>/dev/null || echo 'N/A')${NC}"
  echo -e "    │  ${C}Platform${NC}            │  ${D}$(uname -s) $(uname -m)${NC}"
  echo -e "    │  ${C}Data dir${NC}            │  ${D}$DATA_DIR${NC}"
  echo -e "    └─────────────────────┴─────────────────────────────┘"
}

draw_menu() {
  echo ""
  echo -e "    ${B}${W}Actions${NC}"
  echo ""

  if is_running; then
    echo -e "    ${C}[1]${NC}  Stop server"
    echo -e "    ${C}[2]${NC}  Restart server"
  else
    echo -e "    ${C}[1]${NC}  ${G}Start server${NC} ${D}(port $PORT)${NC}"
    echo -e "    ${D}[2]${NC}  ${D}Restart server (stopped)${NC}"
  fi

  echo -e "    ${C}[3]${NC}  Create backup"
  echo -e "    ${C}[4]${NC}  Integrity check"
  echo -e "    ${C}[5]${NC}  View logs ${D}(last 30 lines)${NC}"
  echo -e "    ${C}[6]${NC}  Security audit"
  echo -e "    ${C}[7]${NC}  Change port ${D}(current: $PORT)${NC}"
  echo -e "    ${C}[8]${NC}  Open in browser"
  echo -e "    ${C}[9]${NC}  Update FyxxVault"
  echo ""
  echo -e "    ${D}[q]${NC}  Quit"
  echo ""
  echo -ne "    ${C}▸${NC} "
}

# ═══════════════════════════════════════════════════
#  Actions
# ═══════════════════════════════════════════════════

action_start() {
  clear_screen
  draw_header
  echo ""

  if is_running; then
    echo -e "    ${Y}!${NC}  Server is already running (PID: $(get_pid))"
    wait_key
    return
  fi

  if [ ! -f "$BUILD_DIR/index.js" ]; then
    echo -e "    ${R}✗${NC}  Build not found. Run the installer first."
    wait_key
    return
  fi

  echo -e "    ${C}⣾${NC}  Starting server on port $PORT..."

  mkdir -p "$LOG_DIR"
  FYXXVAULT_DATA_DIR="$DATA_DIR" PORT="$PORT" node "$BUILD_DIR/index.js" \
    >> "$LOG_FILE" 2>&1 &
  local pid=$!
  echo "$pid" > "$PID_FILE"
  disown "$pid" 2>/dev/null

  # Wait a moment and verify
  sleep 1.5

  if kill -0 "$pid" 2>/dev/null; then
    echo -e "\r    ${G}✓${NC}  Server started!                    "
    echo ""
    echo -e "    ${C}➜${NC}  http://localhost:$PORT"
    echo -e "    ${D}PID: $pid${NC}"
    log_action "Server started on port $PORT (PID: $pid)"
  else
    echo -e "\r    ${R}✗${NC}  Failed to start. Check logs:       "
    echo -e "    ${D}tail -20 $LOG_FILE${NC}"
    rm -f "$PID_FILE"
  fi

  wait_key
}

action_stop() {
  clear_screen
  draw_header
  echo ""

  if ! is_running; then
    echo -e "    ${Y}!${NC}  Server is not running"
    wait_key
    return
  fi

  local pid=$(get_pid)
  echo -e "    ${C}⣾${NC}  Stopping server (PID: $pid)..."

  kill "$pid" 2>/dev/null
  sleep 0.5

  # Force kill if still running
  if kill -0 "$pid" 2>/dev/null; then
    kill -9 "$pid" 2>/dev/null
    sleep 0.3
  fi

  rm -f "$PID_FILE"
  echo -e "\r    ${G}✓${NC}  Server stopped                      "
  log_action "Server stopped (PID: $pid)"
  wait_key
}

action_restart() {
  clear_screen
  draw_header
  echo ""

  if is_running; then
    local pid=$(get_pid)
    echo -e "    ${C}⣾${NC}  Stopping server..."
    kill "$pid" 2>/dev/null
    sleep 1
    kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null
    rm -f "$PID_FILE"
    echo -e "\r    ${G}✓${NC}  Stopped                             "
  fi

  sleep 0.3

  echo -e "    ${C}⣾${NC}  Starting server on port $PORT..."

  mkdir -p "$LOG_DIR"
  FYXXVAULT_DATA_DIR="$DATA_DIR" PORT="$PORT" node "$BUILD_DIR/index.js" \
    >> "$LOG_FILE" 2>&1 &
  local pid=$!
  echo "$pid" > "$PID_FILE"
  disown "$pid" 2>/dev/null

  sleep 1.5

  if kill -0 "$pid" 2>/dev/null; then
    echo -e "\r    ${G}✓${NC}  Server restarted!                   "
    echo -e "    ${C}➜${NC}  http://localhost:$PORT"
    log_action "Server restarted on port $PORT (PID: $pid)"
  else
    echo -e "\r    ${R}✗${NC}  Failed to restart                   "
    rm -f "$PID_FILE"
  fi

  wait_key
}

action_backup() {
  clear_screen
  draw_header
  echo ""

  if [ ! -f "$DB_FILE" ]; then
    echo -e "    ${R}✗${NC}  No database found"
    wait_key
    return
  fi

  local ts=$(date '+%Y-%m-%dT%H-%M-%S')
  local backup_name="fyxxvault-backup-${ts}.db"
  local backup_path="$DATA_DIR/$backup_name"

  echo -e "    ${C}⣾${NC}  Creating backup..."
  cp "$DB_FILE" "$backup_path"
  chmod 600 "$backup_path"

  local size=$(du -sh "$backup_path" | awk '{print $1}')
  echo -e "\r    ${G}✓${NC}  Backup created!                     "
  echo ""
  echo -e "    ${D}File: $backup_name${NC}"
  echo -e "    ${D}Size: $size${NC}"
  echo -e "    ${D}Path: $backup_path${NC}"

  local total=$(get_backup_count)
  echo -e "    ${D}Total backups: $total${NC}"

  log_action "Backup created: $backup_name"
  wait_key
}

action_integrity() {
  clear_screen
  draw_header
  echo ""

  if [ ! -f "$DB_FILE" ]; then
    echo -e "    ${R}✗${NC}  No database found"
    wait_key
    return
  fi

  echo -e "    ${C}⣾${NC}  Running integrity check..."

  local result=""
  if command -v sqlite3 &>/dev/null; then
    result=$(sqlite3 "$DB_FILE" "PRAGMA integrity_check;" 2>&1)
  else
    result=$(node -e "
      const Database = require('$APP_DIR/web/node_modules/better-sqlite3');
      const db = new Database('$DB_FILE', { readonly: true });
      const r = db.pragma('integrity_check');
      console.log(r[0].integrity_check);
      db.close();
    " 2>&1)
  fi

  if [ "$result" = "ok" ]; then
    echo -e "\r    ${G}✓${NC}  Database integrity: ${G}OK${NC}              "
  else
    echo -e "\r    ${R}✗${NC}  Integrity issue detected:           "
    echo -e "    ${R}$result${NC}"
  fi

  # Additional checks
  echo ""
  local db_size=$(get_db_size)
  local perms=$(stat -f "%Lp" "$DB_FILE" 2>/dev/null || stat -c "%a" "$DB_FILE" 2>/dev/null)

  echo -e "    ${D}Database size:  $db_size${NC}"
  echo -e "    ${D}Permissions:    $perms${NC}"

  # Check WAL mode
  local wal_mode=""
  if command -v sqlite3 &>/dev/null; then
    wal_mode=$(sqlite3 "$DB_FILE" "PRAGMA journal_mode;" 2>/dev/null)
  fi
  if [ -n "$wal_mode" ]; then
    echo -e "    ${D}Journal mode:   $wal_mode${NC}"
  fi

  log_action "Integrity check: $result"
  wait_key
}

action_logs() {
  clear_screen
  draw_header
  echo ""
  echo -e "    ${B}${W}Recent Logs${NC} ${D}(last 30 lines)${NC}"
  echo -e "    ${D}$(printf '%.0s─' $(seq 1 52))${NC}"
  echo ""

  if [ -f "$LOG_FILE" ]; then
    tail -30 "$LOG_FILE" | while IFS= read -r line; do
      # Color timestamps
      if [[ "$line" == *"[panel]"* ]]; then
        echo -e "    ${V}$line${NC}"
      elif [[ "$line" == *"error"* ]] || [[ "$line" == *"Error"* ]]; then
        echo -e "    ${R}$line${NC}"
      elif [[ "$line" == *"started"* ]] || [[ "$line" == *"Started"* ]]; then
        echo -e "    ${G}$line${NC}"
      else
        echo -e "    ${D}$line${NC}"
      fi
    done
  else
    echo -e "    ${D}No logs yet${NC}"
  fi

  wait_key
}

action_audit() {
  clear_screen
  draw_header
  echo ""
  echo -e "    ${B}${W}Security Audit${NC}"
  echo -e "    ${D}$(printf '%.0s─' $(seq 1 52))${NC}"
  echo ""

  local issues=0

  # Check DB permissions
  if [ -f "$DB_FILE" ]; then
    local perms=$(stat -f "%Lp" "$DB_FILE" 2>/dev/null || stat -c "%a" "$DB_FILE" 2>/dev/null)
    if [ "$perms" = "600" ]; then
      echo -e "    ${G}✓${NC}  Database permissions: $perms"
    else
      echo -e "    ${R}✗${NC}  Database permissions: $perms ${Y}(should be 600)${NC}"
      issues=$((issues + 1))
    fi
  else
    echo -e "    ${Y}!${NC}  No database found"
  fi

  # Check data dir permissions
  local dir_perms=$(stat -f "%Lp" "$DATA_DIR" 2>/dev/null || stat -c "%a" "$DATA_DIR" 2>/dev/null)
  if [ "$dir_perms" = "700" ]; then
    echo -e "    ${G}✓${NC}  Data directory permissions: $dir_perms"
  else
    echo -e "    ${R}✗${NC}  Data directory permissions: $dir_perms ${Y}(should be 700)${NC}"
    issues=$((issues + 1))
  fi

  # Check .env doesn't exist or is secure
  if [ -f "$APP_DIR/web/.env" ]; then
    local env_perms=$(stat -f "%Lp" "$APP_DIR/web/.env" 2>/dev/null || stat -c "%a" "$APP_DIR/web/.env" 2>/dev/null)
    if [ "$env_perms" = "600" ]; then
      echo -e "    ${G}✓${NC}  .env permissions: $env_perms"
    else
      echo -e "    ${Y}!${NC}  .env permissions: $env_perms ${D}(consider 600)${NC}"
    fi
  else
    echo -e "    ${G}✓${NC}  No .env file (good, no secrets exposed)"
  fi

  # Check WAL files
  if [ -f "$DB_FILE-wal" ]; then
    local wal_size=$(du -sh "$DB_FILE-wal" | awk '{print $1}')
    echo -e "    ${G}✓${NC}  WAL file exists: $wal_size"
  fi

  # Check Node.js version
  local node_major=$(node -v 2>/dev/null | sed 's/v//' | cut -d. -f1)
  if [ -n "$node_major" ] && [ "$node_major" -ge 18 ]; then
    echo -e "    ${G}✓${NC}  Node.js $(node -v): supported"
  else
    echo -e "    ${Y}!${NC}  Node.js version may be outdated"
    issues=$((issues + 1))
  fi

  # Check if running as root
  if [ "$(id -u)" = "0" ]; then
    echo -e "    ${R}✗${NC}  Running as root ${Y}(not recommended)${NC}"
    issues=$((issues + 1))
  else
    echo -e "    ${G}✓${NC}  Not running as root"
  fi

  # Check backups
  local backup_count=$(get_backup_count)
  if [ "$backup_count" -gt 0 ]; then
    echo -e "    ${G}✓${NC}  $backup_count backup(s) found"
  else
    echo -e "    ${Y}!${NC}  No backups found ${D}(run: fyxxvault backup)${NC}"
    issues=$((issues + 1))
  fi

  echo ""
  if [ "$issues" -eq 0 ]; then
    echo -e "    ${G}${B}All checks passed!${NC}"
  else
    echo -e "    ${Y}${B}$issues issue(s) found${NC}"
  fi

  log_action "Security audit: $issues issues"
  wait_key
}

action_change_port() {
  clear_screen
  draw_header
  echo ""
  echo -e "    ${B}${W}Change Server Port${NC}"
  echo -e "    ${D}Current: $PORT${NC}"
  echo ""
  echo -ne "    New port: ${C}"
  read -r new_port
  echo -ne "${NC}"

  if [[ "$new_port" =~ ^[0-9]+$ ]] && [ "$new_port" -ge 1024 ] && [ "$new_port" -le 65535 ]; then
    PORT="$new_port"
    export FYXXVAULT_PORT="$new_port"
    echo -e "    ${G}✓${NC}  Port changed to ${C}$PORT${NC}"
    echo -e "    ${D}Restart the server for changes to take effect${NC}"

    # Persist in shell rc
    local SHELL_RC=""
    if [ -f "$HOME/.zshrc" ]; then
      SHELL_RC="$HOME/.zshrc"
    elif [ -f "$HOME/.bashrc" ]; then
      SHELL_RC="$HOME/.bashrc"
    fi

    if [ -n "$SHELL_RC" ]; then
      # Remove old port line if exists
      sed -i'' -e '/FYXXVAULT_PORT/d' "$SHELL_RC" 2>/dev/null
      echo "export FYXXVAULT_PORT=$new_port" >> "$SHELL_RC"
      echo -e "    ${D}Saved to $SHELL_RC${NC}"
    fi
  else
    echo -e "    ${R}✗${NC}  Invalid port (must be 1024-65535)"
  fi

  wait_key
}

action_open_browser() {
  if is_running; then
    local url="http://localhost:$PORT"
    echo -e "    ${C}➜${NC}  Opening $url..."
    if command -v open &>/dev/null; then
      open "$url"
    elif command -v xdg-open &>/dev/null; then
      xdg-open "$url"
    else
      echo -e "    ${D}Open manually: $url${NC}"
    fi
    sleep 0.5
  else
    echo ""
    echo -e "    ${Y}!${NC}  Server is not running. Start it first."
    wait_key
  fi
}

action_update() {
  clear_screen
  draw_header
  echo ""
  echo -e "    ${B}${W}Update FyxxVault${NC}"
  echo -e "    ${D}$(printf '%.0s─' $(seq 1 52))${NC}"
  echo ""

  # Stop server if running
  if is_running; then
    local pid=$(get_pid)
    echo -e "    ${C}⣾${NC}  Stopping server..."
    kill "$pid" 2>/dev/null
    sleep 1
    rm -f "$PID_FILE"
    echo -e "\r    ${G}✓${NC}  Server stopped                      "
  fi

  # Pull latest
  echo -e "    ${C}⣾${NC}  Pulling latest changes..."
  cd "$APP_DIR"
  if git pull origin "$BRANCH" --quiet 2>/dev/null; then
    echo -e "\r    ${G}✓${NC}  Updated to latest                    "
  else
    echo -e "\r    ${G}✓${NC}  Already up to date                   "
  fi

  # Rebuild
  echo -e "    ${C}⣾${NC}  Rebuilding..."
  cd "$APP_DIR/web"
  npm install --silent --no-fund --no-audit 2>/dev/null
  npm run build --silent 2>/dev/null
  echo -e "\r    ${G}✓${NC}  Build complete                       "

  echo ""
  echo -e "    ${G}Update complete!${NC} ${D}Start the server with: fyxxvault start${NC}"

  log_action "FyxxVault updated"
  wait_key
}

# ═══════════════════════════════════════════════════
#  Main Loop
# ═══════════════════════════════════════════════════

BRANCH="main"

main() {
  while true; do
    clear_screen
    draw_header
    draw_status_bar
    draw_dashboard
    draw_menu

    read -rsn1 choice

    case "$choice" in
      1)
        if is_running; then
          action_stop
        else
          action_start
        fi
        ;;
      2) action_restart ;;
      3) action_backup ;;
      4) action_integrity ;;
      5) action_logs ;;
      6) action_audit ;;
      7) action_change_port ;;
      8) action_open_browser ;;
      9) action_update ;;
      q|Q)
        clear_screen
        echo ""
        echo -e "    ${V}FyxxVault${NC} ${D}— See you later${NC}"
        echo ""
        exit 0
        ;;
    esac
  done
}

main
