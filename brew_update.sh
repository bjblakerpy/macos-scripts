#!/usr/bin/env bash
# =============================================================================
# brew_update.sh
# =============================================================================
# Description:
#   Verifies that Homebrew is installed on macOS, installs it if missing,
#   updates Homebrew itself, and then upgrades all installed packages
#   (formulae and casks). Optionally cleans up old versions afterward.
#
# Usage:
#   chmod +x brew_update.sh
#   ./brew_update.sh [--no-cleanup] [--verbose]
#
# Options:
#   --no-cleanup   Skip the `brew cleanup` step after upgrading
#   --verbose      Enable verbose output (set -x)
#
# Requirements:
#   - macOS
#   - Internet connection
#   - curl (pre-installed on all macOS systems)
#
# Exit Codes:
#   0  Success
#   1  Non-macOS system detected
#   2  Homebrew installation failed
#   3  Homebrew update failed
# =============================================================================

set -euo pipefail  # Exit on error, unset var, or pipe failure

# ─── Colors for output ───────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ─── Default option flags ─────────────────────────────────────────────────────
DO_CLEANUP=true
VERBOSE=false

# ─── Parse arguments ──────────────────────────────────────────────────────────
for arg in "$@"; do
  case "$arg" in
    --no-cleanup) DO_CLEANUP=false ;;
    --verbose)    VERBOSE=true ;;
    *)
      echo -e "${RED}Unknown option: $arg${RESET}"
      echo "Usage: $0 [--no-cleanup] [--verbose]"
      exit 1
      ;;
  esac
done

# Enable verbose/debug mode if requested
if $VERBOSE; then
  set -x
fi

# ─── Helper functions ─────────────────────────────────────────────────────────

# Print a section header
print_header() {
  echo ""
  echo -e "${CYAN}${BOLD}══════════════════════════════════════════${RESET}"
  echo -e "${CYAN}${BOLD}  $1${RESET}"
  echo -e "${CYAN}${BOLD}══════════════════════════════════════════${RESET}"
}

# Print a success message
print_success() {
  echo -e "${GREEN}✔ $1${RESET}"
}

# Print a warning message
print_warning() {
  echo -e "${YELLOW}⚠ $1${RESET}"
}

# Print an info message
print_info() {
  echo -e "  → $1"
}

# Print an error message and exit with the provided code
die() {
  local message="$1"
  local exit_code="${2:-1}"
  echo -e "${RED}✖ ERROR: $message${RESET}" >&2
  exit "$exit_code"
}

# ─── Platform check ───────────────────────────────────────────────────────────

print_header "System Check"

# Homebrew is macOS/Linux, but this script is tailored for macOS
if [[ "$(uname)" != "Darwin" ]]; then
  die "This script is intended for macOS only. Detected OS: $(uname)" 1
fi

print_success "Running on macOS $(sw_vers -productVersion)"

# ─── Homebrew detection ───────────────────────────────────────────────────────

print_header "Homebrew Detection"

# Check whether the `brew` command is available in the current shell.
# Homebrew installs to different paths depending on architecture:
#   Apple Silicon (ARM):  /opt/homebrew/bin/brew
#   Intel x86_64:         /usr/local/bin/brew
if command -v brew &>/dev/null; then
  BREW_PATH="$(command -v brew)"
  print_success "Homebrew found at: $BREW_PATH"
  print_info "Version: $(brew --version | head -1)"
else
  print_warning "Homebrew is not installed."

  # ─── Homebrew installation ──────────────────────────────────────────────────
  print_header "Installing Homebrew"
  print_info "Downloading and running the official Homebrew install script..."
  print_info "You may be prompted for your password (sudo) during installation."
  echo ""

  # The official install script from https://brew.sh
  # Using /bin/bash explicitly as required by the Homebrew installer
  if ! /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
    die "Homebrew installation failed. Check your internet connection and try again." 2
  fi

  # After installation, the brew binary may not be on PATH yet.
  # Add it based on detected architecture so subsequent commands work.
  if [[ "$(uname -m)" == "arm64" ]]; then
    # Apple Silicon path
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    # Intel path
    eval "$(/usr/local/bin/brew shellenv)"
  fi

  if ! command -v brew &>/dev/null; then
    die "Homebrew was installed but 'brew' is still not found in PATH. You may need to restart your shell." 2
  fi

  print_success "Homebrew installed successfully: $(brew --version | head -1)"
  echo ""
  print_info "To make 'brew' available in future shell sessions, add the following"
  print_info "to your ~/.zprofile (or ~/.bash_profile for bash):"
  if [[ "$(uname -m)" == "arm64" ]]; then
    print_info '  eval "$(/opt/homebrew/bin/brew shellenv)"'
  else
    print_info '  eval "$(/usr/local/bin/brew shellenv)"'
  fi
fi

# ─── Homebrew update ──────────────────────────────────────────────────────────

print_header "Updating Homebrew"
print_info "Fetching latest Homebrew formulae and cask definitions..."

if ! brew update; then
  die "Homebrew update failed. Check your internet connection and try again." 3
fi

print_success "Homebrew is up to date."

# ─── Upgrade installed packages ───────────────────────────────────────────────

print_header "Upgrading Installed Packages"

# Check how many packages are outdated before upgrading
OUTDATED_FORMULAE=$(brew outdated --formula --quiet | wc -l | tr -d ' ')
OUTDATED_CASKS=$(brew outdated --cask --quiet | wc -l | tr -d ' ')

print_info "Outdated formulae: $OUTDATED_FORMULAE"
print_info "Outdated casks:    $OUTDATED_CASKS"
echo ""

# Upgrade all outdated formulae (command-line tools and libraries)
if [[ "$OUTDATED_FORMULAE" -gt 0 ]]; then
  print_info "Upgrading formulae..."
  brew upgrade --formula
  print_success "All formulae upgraded."
else
  print_success "All formulae are already up to date."
fi

# Upgrade all outdated casks (GUI applications)
if [[ "$OUTDATED_CASKS" -gt 0 ]]; then
  print_info "Upgrading casks..."
  # --greedy also upgrades casks that don't have a version string (e.g., auto-updating apps)
  # Remove --greedy if you prefer to skip those
  brew upgrade --cask
  print_success "All casks upgraded."
else
  print_success "All casks are already up to date."
fi

# ─── Optional cleanup ─────────────────────────────────────────────────────────

if $DO_CLEANUP; then
  print_header "Cleaning Up"
  print_info "Removing outdated downloads and old versions to free disk space..."

  brew cleanup

  print_success "Cleanup complete."
else
  print_warning "Skipping cleanup (--no-cleanup was specified)."
  print_info "Run 'brew cleanup' manually to remove old versions and free disk space."
fi

# ─── Summary ─────────────────────────────────────────────────────────────────

print_header "Done"
print_success "Homebrew and all installed packages are up to date."
echo ""
