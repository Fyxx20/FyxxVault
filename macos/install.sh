#!/usr/bin/env bash
set -e

# ═══════════════════════════════════════════════════
#  FyxxVault Installer — Self-Hosted Edition
#  Beautiful animated installation experience
# ═══════════════════════════════════════════════════

# ── Colors ──
C='\033[0;36m'      # Cyan
V='\033[0;35m'      # Violet
G='\033[0;32m'      # Green
R='\033[0;31m'      # Red
Y='\033[1;33m'      # Yellow
W='\033[1;37m'      # White bold
D='\033[2m'         # Dim
B='\033[1m'         # Bold
NC='\033[0m'        # Reset
BG_C='\033[46m'     # Cyan bg
BG_V='\033[45m'     # Violet bg
BG_G='\033[42m'     # Green bg

# ── Config ──
FYXX_DIR="$HOME/.fyxxvault"
APP_DIR="$FYXX_DIR/app"
DATA_DIR="$FYXX_DIR/data"
LOG_DIR="$FYXX_DIR/logs"
BIN_DIR="$FYXX_DIR/bin"
REPO="https://github.com/Fyxx20/FyxxVault.git"
BRANCH="main"
PORT="${FYXXVAULT_PORT:-3000}"
TOTAL_STEPS=7
CURRENT_STEP=0

# ── Terminal Setup ──
COLS=$(tput cols 2>/dev/null || echo 60)
if [ "$COLS" -gt 70 ]; then COLS=70; fi

# ═══════════════════════════════════════════════════
#  UI Components
# ═══════════════════════════════════════════════════

clear_screen() {
  printf '\033[2J\033[H'
}

hide_cursor() {
  printf '\033[?25l'
  trap 'printf "\033[?25h"; exit' INT TERM EXIT
}

show_cursor() {
  printf '\033[?25h'
}

# Animated logo reveal
show_logo() {
  clear_screen
  echo ""
  echo ""

  # Line by line reveal with delay
  local lines=(
    "${C}    ╔═══════════════════════════════════════════════════╗${NC}"
    "${C}    ║${NC}                                                   ${C}║${NC}"
    "${C}    ║${NC}        ${B}${W}███████╗██╗   ██╗██╗  ██╗██╗  ██╗${NC}        ${C}║${NC}"
    "${C}    ║${NC}        ${B}${W}██╔════╝╚██╗ ██╔╝╚██╗██╔╝╚██╗██╔╝${NC}        ${C}║${NC}"
    "${C}    ║${NC}        ${B}${C}█████╗   ╚████╔╝  ╚███╔╝  ╚███╔╝${NC}         ${C}║${NC}"
    "${C}    ║${NC}        ${B}${V}██╔══╝    ╚██╔╝   ██╔██╗  ██╔██╗${NC}         ${C}║${NC}"
    "${C}    ║${NC}        ${B}${V}██║        ██║   ██╔╝ ██╗██╔╝ ██╗${NC}        ${C}║${NC}"
    "${C}    ║${NC}        ${D}╚═╝        ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝${NC}        ${C}║${NC}"
    "${C}    ║${NC}                                                   ${C}║${NC}"
    "${C}    ║${NC}          ${B}${C}V A U L T${NC}  ${D}— Self-Hosted Edition${NC}         ${C}║${NC}"
    "${C}    ║${NC}                                                   ${C}║${NC}"
    "${C}    ╚═══════════════════════════════════════════════════╝${NC}"
  )

  for line in "${lines[@]}"; do
    echo -e "$line"
    sleep 0.04
  done

  echo ""
  echo -e "    ${D}Your passwords. Your server. Your rules.${NC}"
  echo ""
  sleep 0.5
}

# Progress bar with percentage
progress_bar() {
  local percent=$1
  local label="$2"
  local bar_width=40
  local filled=$((percent * bar_width / 100))
  local empty=$((bar_width - filled))

  # Build bar
  local bar=""
  for ((i=0; i<filled; i++)); do bar+="█"; done
  for ((i=0; i<empty; i++)); do bar+="░"; done

  # Color gradient based on progress
  local color="$C"
  if [ "$percent" -gt 66 ]; then color="$G"
  elif [ "$percent" -gt 33 ]; then color="$V"; fi

  printf "\r    ${color}${bar}${NC}  ${B}${percent}%%${NC}  ${D}${label}${NC}  "
}

# Step progress (top bar)
show_step_progress() {
  local step_pct=$((CURRENT_STEP * 100 / TOTAL_STEPS))
  local dots=""
  for ((i=1; i<=TOTAL_STEPS; i++)); do
    if [ "$i" -le "$CURRENT_STEP" ]; then
      dots+="${G}●${NC} "
    elif [ "$i" -eq $((CURRENT_STEP + 1)) ]; then
      dots+="${C}◉${NC} "
    else
      dots+="${D}○${NC} "
    fi
  done
  echo -e "    ${dots}  ${D}${step_pct}%${NC}"
}

# Animated spinner for a task
run_with_spinner() {
  local msg="$1"
  shift
  local cmd="$@"

  local spin='⣾⣽⣻⢿⡿⣟⣯⣷'
  local i=0

  # Run command in background
  eval "$cmd" > /tmp/fyxx_install_out 2>&1 &
  local pid=$!

  while kill -0 "$pid" 2>/dev/null; do
    local char="${spin:i++%${#spin}:1}"
    printf "\r    ${C}${char}${NC}  ${msg}"
    sleep 0.08
  done

  wait "$pid"
  local exit_code=$?

  if [ $exit_code -eq 0 ]; then
    printf "\r    ${G}✓${NC}  ${msg}                              \n"
  else
    printf "\r    ${R}✗${NC}  ${msg}                              \n"
    echo ""
    echo -e "    ${R}Error details:${NC}"
    cat /tmp/fyxx_install_out | head -5 | sed 's/^/      /'
    echo ""
    show_cursor
    exit 1
  fi
}

# Section header
section() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  echo ""
  show_step_progress
  echo -e "    ${B}${W}$1${NC}"
  echo -e "    ${D}$(printf '%.0s─' $(seq 1 48))${NC}"
}

# ═══════════════════════════════════════════════════
#  Installation Steps
# ═══════════════════════════════════════════════════

check_requirements() {
  section "Checking requirements"

  # Node.js
  if command -v node &>/dev/null; then
    local nv=$(node -v | sed 's/v//')
    local major=$(echo "$nv" | cut -d. -f1)
    if [ "$major" -ge 18 ]; then
      echo -e "    ${G}✓${NC}  Node.js ${G}v${nv}${NC}"
    else
      echo -e "    ${R}✗${NC}  Node.js ${R}v${nv}${NC} ${D}(need 18+)${NC}"
      echo ""
      echo -e "    ${Y}Install Node.js 18+:${NC} https://nodejs.org"
      show_cursor; exit 1
    fi
  else
    echo -e "    ${R}✗${NC}  Node.js ${R}not found${NC}"
    echo ""
    echo -e "    ${Y}Install Node.js:${NC} https://nodejs.org"
    show_cursor; exit 1
  fi
  sleep 0.15

  # npm
  if command -v npm &>/dev/null; then
    echo -e "    ${G}✓${NC}  npm ${G}v$(npm -v 2>/dev/null)${NC}"
  else
    echo -e "    ${R}✗${NC}  npm ${R}not found${NC}"
    show_cursor; exit 1
  fi
  sleep 0.15

  # git
  if command -v git &>/dev/null; then
    echo -e "    ${G}✓${NC}  git ${G}v$(git --version | awk '{print $3}')${NC}"
  else
    echo -e "    ${R}✗${NC}  git ${R}not found${NC}"
    echo ""
    echo -e "    ${Y}Install git:${NC} https://git-scm.com"
    show_cursor; exit 1
  fi
  sleep 0.15

  # Disk space
  local free_mb=$(df -m "$HOME" | awk 'NR==2{print $4}')
  if [ "$free_mb" -gt 500 ]; then
    echo -e "    ${G}✓${NC}  Disk space ${G}${free_mb} MB free${NC}"
  else
    echo -e "    ${Y}!${NC}  Low disk space: ${Y}${free_mb} MB${NC}"
  fi
  sleep 0.15
}

create_directories() {
  section "Creating directory structure"

  local dirs=("$FYXX_DIR" "$APP_DIR" "$DATA_DIR" "$LOG_DIR" "$BIN_DIR")
  local names=("~/.fyxxvault/" "~/.fyxxvault/app/" "~/.fyxxvault/data/" "~/.fyxxvault/logs/" "~/.fyxxvault/bin/")

  for i in "${!dirs[@]}"; do
    mkdir -p "${dirs[$i]}"
    echo -e "    ${G}+${NC}  ${names[$i]}"
    sleep 0.08
  done

  chmod 700 "$DATA_DIR"
  echo -e "    ${G}✓${NC}  Permissions set ${D}(data: 0700)${NC}"
}

download_fyxxvault() {
  section "Downloading FyxxVault"

  if [ -d "$APP_DIR/.git" ]; then
    run_with_spinner "Updating to latest version..." "cd '$APP_DIR' && git fetch origin '$BRANCH' --quiet && git reset --hard 'origin/$BRANCH' --quiet && git clean -fd -e node_modules --quiet"
  else
    # Clean target if exists but no git
    if [ -d "$APP_DIR" ] && [ "$(ls -A $APP_DIR 2>/dev/null)" ]; then
      rm -rf "$APP_DIR"
      mkdir -p "$APP_DIR"
    fi
    run_with_spinner "Cloning repository (branch: ${BRANCH})..." "git clone --branch '$BRANCH' --depth 1 --quiet '$REPO' '$APP_DIR'"
  fi

  # Show downloaded structure
  echo -e "    ${D}├── web/           Application${NC}"
  echo -e "    ${D}└── self-hosted/   CLI & scripts${NC}"
}

install_dependencies() {
  section "Installing dependencies"

  # Count packages for display
  run_with_spinner "Installing npm packages..." "cd '$APP_DIR/web' && npm install --silent --no-fund --no-audit 2>&1"

  local pkg_count=$(ls "$APP_DIR/web/node_modules" 2>/dev/null | wc -l | tr -d ' ')
  echo -e "    ${D}${pkg_count} packages installed${NC}"
}

build_application() {
  section "Building application"

  echo -e "    ${D}Compiling SvelteKit with adapter-node...${NC}"
  run_with_spinner "TypeScript compilation..." "cd '$APP_DIR/web' && npm run build 2>&1"

  # Show build stats
  if [ -d "$APP_DIR/web/build" ]; then
    local build_size=$(du -sh "$APP_DIR/web/build" 2>/dev/null | awk '{print $1}')
    echo -e "    ${D}Build output: ${build_size}${NC}"
  fi
}

initialize_database() {
  section "Initializing database"

  run_with_spinner "Creating SQLite database (WAL mode)..." "cd '$APP_DIR' && node self-hosted/scripts/init-db.js 2>&1"

  # Show DB info
  if [ -f "$DATA_DIR/fyxxvault.db" ]; then
    local db_size=$(du -sh "$DATA_DIR/fyxxvault.db" 2>/dev/null | awk '{print $1}')
    local perms=$(stat -f "%Lp" "$DATA_DIR/fyxxvault.db" 2>/dev/null || stat -c "%a" "$DATA_DIR/fyxxvault.db" 2>/dev/null)
    echo -e "    ${D}├── Database: ${db_size}${NC}"
    echo -e "    ${D}├── Location: ~/.fyxxvault/data/fyxxvault.db${NC}"
    echo -e "    ${D}├── Mode: WAL (Write-Ahead Logging)${NC}"
    echo -e "    ${D}└── Permissions: ${perms}${NC}"
  fi
}

setup_cli_and_panel() {
  section "Setting up CLI & Panel"

  # Create fyxxvault CLI wrapper
  cat > "$BIN_DIR/fyxxvault" << 'CLIFILE'
#!/usr/bin/env bash
FYXX_DIR="$HOME/.fyxxvault"
export FYXXVAULT_DATA_DIR="$FYXX_DIR/data"
node "$FYXX_DIR/app/self-hosted/bin/fyxxvault.js" "$@"
CLIFILE
  chmod +x "$BIN_DIR/fyxxvault"
  echo -e "    ${G}✓${NC}  CLI tool installed"

  # Create panel launcher
  cat > "$BIN_DIR/fyxxvault-panel" << 'PANELFILE'
#!/usr/bin/env bash
FYXX_DIR="$HOME/.fyxxvault"
export FYXXVAULT_DATA_DIR="$FYXX_DIR/data"
bash "$FYXX_DIR/app/panel.sh"
PANELFILE
  chmod +x "$BIN_DIR/fyxxvault-panel"
  echo -e "    ${G}✓${NC}  Panel launcher installed"

  # Add to PATH
  local SHELL_RC=""
  if [ -f "$HOME/.zshrc" ]; then
    SHELL_RC="$HOME/.zshrc"
  elif [ -f "$HOME/.bashrc" ]; then
    SHELL_RC="$HOME/.bashrc"
  elif [ -f "$HOME/.bash_profile" ]; then
    SHELL_RC="$HOME/.bash_profile"
  fi

  if [ -n "$SHELL_RC" ]; then
    if ! grep -q "fyxxvault/bin" "$SHELL_RC" 2>/dev/null; then
      echo "" >> "$SHELL_RC"
      echo "# FyxxVault" >> "$SHELL_RC"
      echo 'export PATH="$HOME/.fyxxvault/bin:$PATH"' >> "$SHELL_RC"
      echo -e "    ${G}✓${NC}  Added to PATH ${D}($SHELL_RC)${NC}"
    else
      echo -e "    ${G}✓${NC}  Already in PATH"
    fi
  fi

  # Export for current session
  export PATH="$BIN_DIR:$PATH"
  echo -e "    ${G}✓${NC}  CLI ready for current session"
}

# ═══════════════════════════════════════════════════
#  Success Screen
# ═══════════════════════════════════════════════════

show_success() {
  echo ""
  echo ""
  echo -e "    ${G}╔═══════════════════════════════════════════════════╗${NC}"
  echo -e "    ${G}║${NC}                                                   ${G}║${NC}"
  echo -e "    ${G}║${NC}     ${B}${G}✓  Installation complete!${NC}                      ${G}║${NC}"
  echo -e "    ${G}║${NC}                                                   ${G}║${NC}"
  echo -e "    ${G}╚═══════════════════════════════════════════════════╝${NC}"
  echo ""
  echo ""
  echo -e "    ${B}${W}Copiez-collez cette commande pour lancer :${NC}"
  echo ""
  echo -e "    ${C}~/.fyxxvault/bin/fyxxvault start${NC}"
  echo ""
  echo -e "    ${D}Puis ouvrez :${NC} ${C}http://localhost:${PORT}${NC}"
  echo ""
  echo ""
  echo -e "    ${D}Apres avoir redemarre votre terminal, vous pourrez${NC}"
  echo -e "    ${D}utiliser directement :${NC} ${C}fyxxvault start${NC}"
  echo ""
  echo -e "    ${V}Your passwords. Your server. Your rules.${NC}"
  echo ""
}

# ═══════════════════════════════════════════════════
#  Main
# ═══════════════════════════════════════════════════

main() {
  hide_cursor
  show_logo
  sleep 0.3

  check_requirements
  create_directories
  download_fyxxvault
  install_dependencies
  build_application
  initialize_database
  setup_cli_and_panel

  show_cursor
  show_success
}

main
