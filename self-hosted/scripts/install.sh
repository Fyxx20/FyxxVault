#!/usr/bin/env bash
set -e

# ─────────────────────────────────────────────
#  FyxxVault — Self-Hosted Installer
#  One command. Full control.
# ─────────────────────────────────────────────

CYAN='\033[0;36m'
VIOLET='\033[0;35m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

FYXX_DIR="$HOME/.fyxxvault"
APP_DIR="$FYXX_DIR/app"
DATA_DIR="$FYXX_DIR/data"
LOG_DIR="$FYXX_DIR/logs"
BIN_DIR="$FYXX_DIR/bin"
REPO="https://github.com/Fyxx20/FyxxVault.git"
BRANCH="self-hosted"
PORT="${PORT:-3000}"

# ─────────────────────────────────────────────
#  ASCII Art Header
# ─────────────────────────────────────────────
header() {
  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║${NC}                                              ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}   ${BOLD}${VIOLET}⬡${NC}  ${BOLD}FyxxVault${NC} — Self-Hosted Edition          ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}   ${DIM}Your passwords. Your server. Your rules.${NC}  ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}                                              ${CYAN}║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
  echo ""
}

# ─────────────────────────────────────────────
#  Helpers
# ─────────────────────────────────────────────
step() {
  echo -e "  ${CYAN}▸${NC} $1"
}

success() {
  echo -e "  ${GREEN}✓${NC} $1"
}

warn() {
  echo -e "  ${YELLOW}!${NC} $1"
}

fail() {
  echo -e "  ${RED}✗${NC} $1"
  exit 1
}

spinner() {
  local pid=$1
  local msg=$2
  local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  ${CYAN}${spin:i++%${#spin}:1}${NC} %s" "$msg"
    sleep 0.1
  done
  printf "\r"
}

# ─────────────────────────────────────────────
#  Checks
# ─────────────────────────────────────────────
check_requirements() {
  step "Checking requirements..."
  echo ""

  # Node.js
  if command -v node &>/dev/null; then
    NODE_VERSION=$(node -v | sed 's/v//')
    NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d. -f1)
    if [ "$NODE_MAJOR" -ge 18 ]; then
      success "Node.js v$NODE_VERSION"
    else
      fail "Node.js 18+ required (found v$NODE_VERSION). Install: https://nodejs.org"
    fi
  else
    fail "Node.js not found. Install: https://nodejs.org"
  fi

  # npm
  if command -v npm &>/dev/null; then
    success "npm $(npm -v)"
  else
    fail "npm not found"
  fi

  # git
  if command -v git &>/dev/null; then
    success "git $(git --version | awk '{print $3}')"
  else
    fail "git not found. Install: https://git-scm.com"
  fi

  echo ""
}

# ─────────────────────────────────────────────
#  Install
# ─────────────────────────────────────────────
create_dirs() {
  step "Creating directories..."
  mkdir -p "$APP_DIR" "$DATA_DIR" "$LOG_DIR" "$BIN_DIR"
  chmod 700 "$DATA_DIR"
  success "~/.fyxxvault/ created"
}

clone_repo() {
  if [ -d "$APP_DIR/.git" ]; then
    step "Updating existing installation..."
    cd "$APP_DIR"
    git fetch origin "$BRANCH" --quiet
    git reset --hard "origin/$BRANCH" --quiet
    success "Updated to latest version"
  else
    step "Downloading FyxxVault..."
    git clone --branch "$BRANCH" --depth 1 --quiet "$REPO" "$APP_DIR"
    success "Downloaded"
  fi
}

install_deps() {
  step "Installing dependencies..."
  cd "$APP_DIR/web"
  npm install --silent --no-fund --no-audit 2>&1 | tail -1
  success "Dependencies installed"
}

build_app() {
  step "Building application..."
  cd "$APP_DIR/web"
  npm run build --silent 2>&1
  success "Build complete"
}

init_database() {
  step "Initializing database..."
  cd "$APP_DIR"
  node self-hosted/scripts/init-db.js
}

setup_cli() {
  step "Setting up CLI..."

  # Create wrapper script
  cat > "$BIN_DIR/fyxxvault" << 'WRAPPER'
#!/usr/bin/env bash
FYXX_DIR="$HOME/.fyxxvault"
export FYXXVAULT_DATA_DIR="$FYXX_DIR/data"
node "$FYXX_DIR/app/self-hosted/bin/fyxxvault.js" "$@"
WRAPPER

  chmod +x "$BIN_DIR/fyxxvault"

  # Add to PATH if needed
  SHELL_RC=""
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
      echo "# FyxxVault CLI" >> "$SHELL_RC"
      echo 'export PATH="$HOME/.fyxxvault/bin:$PATH"' >> "$SHELL_RC"
      success "CLI added to PATH (restart terminal or run: source $SHELL_RC)"
    else
      success "CLI already in PATH"
    fi
  else
    warn "Add this to your shell profile: export PATH=\"\$HOME/.fyxxvault/bin:\$PATH\""
  fi
}

# ─────────────────────────────────────────────
#  Finish
# ─────────────────────────────────────────────
print_success() {
  echo ""
  echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║${NC}                                              ${GREEN}║${NC}"
  echo -e "${GREEN}║${NC}   ${BOLD}${GREEN}✓${NC}  ${BOLD}FyxxVault installed successfully!${NC}        ${GREEN}║${NC}"
  echo -e "${GREEN}║${NC}                                              ${GREEN}║${NC}"
  echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  ${BOLD}Start the server:${NC}"
  echo -e "  ${DIM}\$${NC} ${CYAN}fyxxvault start${NC}"
  echo ""
  echo -e "  ${BOLD}Or run directly:${NC}"
  echo -e "  ${DIM}\$${NC} ${CYAN}cd ~/.fyxxvault/app/web && PORT=$PORT node build/index.js${NC}"
  echo ""
  echo -e "  ${BOLD}Then open:${NC}"
  echo -e "  ${DIM}➜${NC} ${CYAN}http://localhost:$PORT${NC}"
  echo ""
  echo -e "  ${BOLD}CLI commands:${NC}"
  echo -e "  ${DIM}\$${NC} fyxxvault start       ${DIM}# Start server${NC}"
  echo -e "  ${DIM}\$${NC} fyxxvault stop        ${DIM}# Stop server${NC}"
  echo -e "  ${DIM}\$${NC} fyxxvault status      ${DIM}# Check status${NC}"
  echo -e "  ${DIM}\$${NC} fyxxvault backup      ${DIM}# Backup database${NC}"
  echo -e "  ${DIM}\$${NC} fyxxvault check       ${DIM}# Integrity check${NC}"
  echo ""
  echo -e "  ${DIM}Data: ~/.fyxxvault/data/fyxxvault.db${NC}"
  echo -e "  ${DIM}Logs: ~/.fyxxvault/logs/fyxxvault.log${NC}"
  echo ""
  echo -e "  ${VIOLET}Your passwords. Your server. Your rules.${NC}"
  echo ""
}

# ─────────────────────────────────────────────
#  Main
# ─────────────────────────────────────────────
main() {
  header
  check_requirements
  create_dirs
  clone_repo
  install_deps
  build_app
  init_database
  setup_cli
  print_success
}

main
