#!/usr/bin/env bash
# =============================================================================
# install_apps.sh
# =============================================================================
# Description:
#   Installs a curated set of Homebrew formulae and casks on macOS.
#   Skips any package that is already installed rather than erroring out.
#   Requires Homebrew to already be installed. Run brew_update.sh first
#   if you haven't set up Homebrew yet.
#
# Usage:
#   chmod +x install_apps.sh
#   ./install_apps.sh [--verbose]
#
# Options:
#   --verbose   Enable verbose/debug output (set -x)
#
# Exit Codes:
#   0  All packages installed (or already present)
#   1  Non-macOS system detected
#   2  Homebrew not found
# =============================================================================

set -euo pipefail

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ─── Parse arguments ──────────────────────────────────────────────────────────
VERBOSE=false
for arg in "$@"; do
  case "$arg" in
    --verbose) VERBOSE=true ;;
    *)
      echo -e "${RED}Unknown option: $arg${RESET}"
      echo "Usage: $0 [--verbose]"
      exit 1
      ;;
  esac
done

$VERBOSE && set -x

# ─── Helpers ──────────────────────────────────────────────────────────────────

print_header() {
  echo ""
  echo -e "${CYAN}${BOLD}══════════════════════════════════════════${RESET}"
  echo -e "${CYAN}${BOLD}  $1${RESET}"
  echo -e "${CYAN}${BOLD}══════════════════════════════════════════${RESET}"
}

print_success() { echo -e "${GREEN}✔ $1${RESET}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${RESET}"; }
print_info()    { echo -e "  → $1"; }
print_skip()    { echo -e "${YELLOW}  ↷ Skipping $1 (already installed)${RESET}"; }

die() {
  echo -e "${RED}✖ ERROR: $1${RESET}" >&2
  exit "${2:-1}"
}

# ─── Install a Homebrew formula (CLI tool / library) ──────────────────────────
# Usage: install_formula <name>
install_formula() {
  local name="$1"
  if brew list --formula | grep -q "^${name}$"; then
    print_skip "$name"
  else
    print_info "Installing formula: $name"
    brew install "$name"
    print_success "$name installed."
  fi
}

# ─── Install a Homebrew cask (GUI application) ────────────────────────────────
# Usage: install_cask <name>
install_cask() {
  local name="$1"
  if brew list --cask | grep -q "^${name}$"; then
    print_skip "$name"
  else
    print_info "Installing cask: $name"
    brew install --cask "$name"
    print_success "$name installed."
  fi
}

# =============================================================================
# PACKAGE LISTS
# Edit these arrays to add or remove packages.
# =============================================================================

# Homebrew formulae — command-line tools and libraries
# python@3.13 pulls the latest stable Python 3 release via Homebrew
FORMULAE=(
  python@3.13       # Latest stable Python 3
  claude-code       # Anthropic Claude CLI coding agent
  tigervnc          # TigerVNC remote desktop viewer/server
)

# Homebrew casks — macOS GUI applications
CASKS=(
  antigravity       # Google Antigravity — agent-first AI IDE powered by Gemini 3
  vscodium          # VS Code without Microsoft telemetry
  claude            # Anthropic Claude desktop app
  motion            # Motion task/project manager
  comet             # Comet review and collaboration tool
  balenaetcher      # Flash OS images to SD cards / USB drives
  docker-desktop    # Docker container platform
  protonvpn         # ProtonVPN client
  lm-studio         # Run local LLMs via LM Studio
  google-drive      # Google Drive for Desktop
  proton-mail       # Proton Mail and Proton Calendar desktop client
  tailscale         # Tailscale VPN mesh networking
)

# =============================================================================

# ─── Platform check ───────────────────────────────────────────────────────────

print_header "System Check"

[[ "$(uname)" == "Darwin" ]] || die "This script is intended for macOS only." 1

print_success "Running on macOS $(sw_vers -productVersion)"

# ─── Homebrew check ───────────────────────────────────────────────────────────

print_header "Homebrew Check"

if ! command -v brew &>/dev/null; then
  die "Homebrew is not installed or not on PATH. Run brew_update.sh first to install it." 2
fi

print_success "Homebrew found: $(brew --version | head -1)"

# Update Homebrew before installing so we get current formula info
print_info "Updating Homebrew before installing..."
brew update
print_success "Homebrew updated."

# ─── Install formulae ─────────────────────────────────────────────────────────

print_header "Installing Formulae (${#FORMULAE[@]} packages)"

for formula in "${FORMULAE[@]}"; do
  install_formula "$formula"
done

# ─── Install casks ────────────────────────────────────────────────────────────

print_header "Installing Casks (${#CASKS[@]} applications)"

for cask in "${CASKS[@]}"; do
  install_cask "$cask"
done

# ─── Python post-install note ─────────────────────────────────────────────────

print_header "Python Setup Note"

PYTHON_BIN="$(brew --prefix python@3.13)/bin/python3"

if [[ -x "$PYTHON_BIN" ]]; then
  PY_VERSION="$("$PYTHON_BIN" --version)"
  print_success "$PY_VERSION installed at $PYTHON_BIN"
fi

print_info "Homebrew intentionally does not symlink Python to /usr/local/bin"
print_info "to avoid conflicts with the macOS system Python."
print_info ""
print_info "To use this Python by default, add the following to your ~/.zprofile:"
print_info ""
echo -e "      ${BOLD}export PATH=\"\$(brew --prefix python@3.13)/bin:\$PATH\"${RESET}"
print_info ""
print_info "Or create an explicit alias in ~/.zshrc:"
echo -e "      ${BOLD}alias python3=\"\$(brew --prefix python@3.13)/bin/python3\"${RESET}"

# ─── Summary ──────────────────────────────────────────────────────────────────

print_header "Installation Complete"
print_success "All packages have been installed (or were already present)."
print_info "Run 'brew list' to see everything installed on your system."
echo ""
