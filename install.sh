#!/usr/bin/env bash
#
# HomelabHero one-line installer.
#
#   apt update && apt install -y curl && \
#     curl -fsSL https://raw.githubusercontent.com/serversathome/homelabhero/main/install.sh | bash
#
# It clones the repo, then hands off to setup/main.sh (which reads any prompts
# from your terminal, so the curl | bash pipe stays interactive).
#
set -euo pipefail

HH_REPO="${HH_REPO:-https://github.com/serversathome/homelabhero.git}"
HH_BRANCH="${HH_BRANCH:-main}"
CLONE_DIR="${HH_DIR:-$HOME/.homelabhero}"

info() { printf '\033[1;36m[homelabhero]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[homelabhero] error:\033[0m %s\n' "$*" >&2; exit 1; }

# Works as root (typical on a fresh LXC) or as a sudo user.
if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; command -v sudo >/dev/null 2>&1 || die "Install sudo, or run as root."; fi

# git/curl are needed just to fetch the repo; install if missing.
if ! command -v git >/dev/null 2>&1; then
  info "Installing git..."
  $SUDO apt-get update -y && $SUDO apt-get install -y --no-install-recommends git ca-certificates
fi

if [ -d "$CLONE_DIR/.git" ]; then
  info "Updating existing checkout in $CLONE_DIR"
  git -C "$CLONE_DIR" fetch --depth 1 origin "$HH_BRANCH"
  git -C "$CLONE_DIR" reset --hard "origin/${HH_BRANCH}"
else
  info "Cloning $HH_REPO into $CLONE_DIR"
  git clone --depth 1 --branch "$HH_BRANCH" "$HH_REPO" "$CLONE_DIR"
fi

chmod +x "$CLONE_DIR/setup/main.sh" "$CLONE_DIR/bin/hh" "$CLONE_DIR/bin/hh-connect" 2>/dev/null || true

info "Starting setup..."
# Run setup with the terminal attached so its prompts work under curl | bash.
if [ -e /dev/tty ]; then
  exec bash "$CLONE_DIR/setup/main.sh" </dev/tty
else
  exec bash "$CLONE_DIR/setup/main.sh"
fi
