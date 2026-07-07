#!/usr/bin/env bash
#
# HomelabHero installer. Run on a fresh Ubuntu 26.04 LXC as root (the usual case
# on a new LXC) OR as a sudo-capable user. Creates the privilege-separated users,
# installs Node/Claude/claudecodeui,
# lays down the ops brain, wires the connection broker, and starts the service.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENT_USER="hhagent"
VAULT_USER="hhvault"
CFG_DIR="/etc/homelabhero"
VAULT_DIR="${CFG_DIR}/vault"
REG_DIR="${CFG_DIR}/hosts.d"
NODE_LTS_MIN=22

say()  { printf '\n\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

# Root (typical on a fresh LXC) or a sudo-capable user, both work.
if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
  # sudo is REQUIRED at runtime (the broker uses it), so ensure it exists.
  command -v sudo >/dev/null 2>&1 || { apt-get update -y; apt-get install -y sudo; }
else
  SUDO="sudo"
  command -v sudo >/dev/null 2>&1 || die "Install sudo, or run this as root."
  sudo -v || die "This installer needs sudo."
fi

# ---------------------------------------------------------------------------
say "1/10  OS prerequisites"
$SUDO apt-get update -y
$SUDO apt-get install -y --no-install-recommends \
  sudo git curl ca-certificates build-essential openssh-client sshpass \
  tmux jq ripgrep rsync unzip iputils-ping dnsutils netcat-openbsd nmap

# ---------------------------------------------------------------------------
say "2/10  Privilege-separated users"
if ! id "$VAULT_USER" >/dev/null 2>&1; then
  $SUDO useradd --system --create-home --home-dir "/home/${VAULT_USER}" \
    --shell /usr/sbin/nologin "$VAULT_USER"
fi
$SUDO install -d -o "$VAULT_USER" -g "$VAULT_USER" -m 700 "/home/${VAULT_USER}/.ssh"

if ! id "$AGENT_USER" >/dev/null 2>&1; then
  $SUDO useradd --create-home --shell /bin/bash "$AGENT_USER"
fi
AGENT_HOME="$(getent passwd "$AGENT_USER" | cut -d: -f6)"

# ---------------------------------------------------------------------------
say "3/10  Config, registry, and vault"
$SUDO install -d -o root -g root -m 755 "$CFG_DIR"
# The registry is non-secret metadata, but the provisioner (running as the vault
# user) needs to write entries here, so the vault user owns it. Still world-
# readable (conf files are 644) so the agent can `hh list`.
$SUDO install -d -o "$VAULT_USER" -g "$VAULT_USER" -m 755 "$REG_DIR"
$SUDO install -d -o "$VAULT_USER" -g "$VAULT_USER" -m 700 "$VAULT_DIR"
[ -f "${CFG_DIR}/cloudcli.env" ] || \
  $SUDO install -o root -g root -m 644 "${REPO_ROOT}/templates/cloudcli.env.example" "${CFG_DIR}/cloudcli.env"

# ---------------------------------------------------------------------------
say "4/10  Broker, CLI, updater, and weekly auto-update"
$SUDO install -o root -g root -m 755 "${REPO_ROOT}/bin/hh-connect" /usr/local/bin/hh-connect
$SUDO install -o root -g root -m 755 "${REPO_ROOT}/bin/hh"         /usr/local/bin/hh
$SUDO install -o root -g root -m 755 "${REPO_ROOT}/bin/hh-update"  /usr/local/bin/hh-update
$SUDO install -o root -g root -m 755 "${REPO_ROOT}/bin/hh-provision" /usr/local/bin/hh-provision
# Bash completion for the hh CLI (subcommands + host aliases).
$SUDO install -o root -g root -m 644 "${REPO_ROOT}/templates/hh.completion" /etc/bash_completion.d/hh
# Weekly OS + Claude auto-update (edit or delete /etc/cron.d/homelabhero to change)
$SUDO install -o root -g root -m 644 "${REPO_ROOT}/templates/cron.homelabhero" /etc/cron.d/homelabhero
# Keep the logs from growing without bound.
$SUDO install -o root -g root -m 644 "${REPO_ROOT}/templates/logrotate.homelabhero" /etc/logrotate.d/homelabhero
[ -f /var/log/homelabhero-update.log ] || $SUDO install -o root -g root -m 644 /dev/null /var/log/homelabhero-update.log
# Broker audit log: owned by the vault user, unreadable by the agent, so a
# hijacked agent can neither read past commands nor erase its own tracks.
[ -f /var/log/homelabhero-broker.log ] || $SUDO install -o "$VAULT_USER" -g "$VAULT_USER" -m 600 /dev/null /var/log/homelabhero-broker.log

# ---------------------------------------------------------------------------
say "5/10  Sudoers rule (agent may run ONLY the broker, ONLY as vault)"
TMP_SUDO="$(mktemp)"
cp "${REPO_ROOT}/templates/sudoers.homelabhero" "$TMP_SUDO"
if $SUDO visudo -cf "$TMP_SUDO" >/dev/null; then
  $SUDO install -o root -g root -m 0440 "$TMP_SUDO" /etc/sudoers.d/homelabhero
else
  rm -f "$TMP_SUDO"; die "sudoers template failed validation; aborting."
fi
rm -f "$TMP_SUDO"

# ---------------------------------------------------------------------------
say "6/10  Ops brain -> ${AGENT_HOME}/homelab-ops"
sudo -u "$AGENT_USER" mkdir -p "${AGENT_HOME}/homelab-ops"
$SUDO rsync -a --ignore-existing "${REPO_ROOT}/ops/" "${AGENT_HOME}/homelab-ops/"
$SUDO chown -R "$AGENT_USER:$AGENT_USER" "${AGENT_HOME}/homelab-ops"
sudo -u "$AGENT_USER" -H bash -lc "cd ~/homelab-ops && [ -d .git ] || (git init -q && git add -A && git -c user.name='HomelabHero' -c user.email='homelabhero@localhost' commit -q -m 'HomelabHero scaffold')" || true

# ---------------------------------------------------------------------------
say "7/10  Node (nvm) + Claude Code + claudecodeui, as ${AGENT_USER}"
sudo -u "$AGENT_USER" -i bash <<'AGENT'
set -e
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] || curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
. "$NVM_DIR/nvm.sh"
nvm install --lts
nvm alias default 'lts/*'
npm install -g @anthropic-ai/claude-code @cloudcli-ai/cloudcli
AGENT

# Resolve node/cloudcli in a shell that actually has nvm loaded. A login shell
# alone does NOT load nvm on Ubuntu (.bashrc returns early when non-interactive),
# so we source nvm explicitly. The || true lets the checks below report clearly.
nvm_run() { sudo -u "$AGENT_USER" -H bash -c "export NVM_DIR=\"${AGENT_HOME}/.nvm\"; [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\" >/dev/null 2>&1; $*"; }
NODE_BIN="$(nvm_run 'dirname "$(command -v node)"' 2>/dev/null)" || true
CLOUDCLI="$(nvm_run 'command -v cloudcli' 2>/dev/null)" || true
NODE_MAJOR="$(nvm_run 'node -p "process.versions.node.split(\".\")[0]"' 2>/dev/null)" || true
NODE_VER="$(nvm_run 'node -v' 2>/dev/null)" || true
[ -n "$NODE_BIN" ] || die "node not found after install (nvm did not load)."
[ -n "$CLOUDCLI" ] || die "cloudcli not found after install."
[ "${NODE_MAJOR:-0}" -ge "$NODE_LTS_MIN" ] || die "Node ${NODE_MAJOR:-?} < ${NODE_LTS_MIN}."
say "    node ${NODE_VER}  cloudcli ${CLOUDCLI}"

# ---------------------------------------------------------------------------
say "8/10  Service (homelab-cc)"
UNIT="$(mktemp)"
sed -e "s|__AGENT_HOME__|${AGENT_HOME}|g" \
    -e "s|__NODE_BIN__|${NODE_BIN}|g" \
    -e "s|__CLOUDCLI__|${CLOUDCLI}|g" \
    "${REPO_ROOT}/templates/homelab-cc.service.template" > "$UNIT"
$SUDO install -o root -g root -m 644 "$UNIT" /etc/systemd/system/homelab-cc.service
rm -f "$UNIT"
$SUDO systemctl daemon-reload
$SUDO systemctl enable --now homelab-cc.service

# ---------------------------------------------------------------------------
echo
say "Checking the service..."
sleep 2
$SUDO systemctl --no-pager --full status homelab-cc.service | head -n 8 || true

# ---------------------------------------------------------------------------
say "9/10  Sign Claude in (one time)"
if $SUDO test -f "${AGENT_HOME}/.claude/.credentials.json" 2>/dev/null; then
  echo "Already signed in. Skipping."
else
  cat <<'EOF'
Claude needs to sign in to your Claude account once. A sign-in screen will
appear next. Just follow it:

  1. Choose "Claude account with subscription".
  2. Open the link it shows in any browser and approve.
  3. If it shows a code, paste it back here and press Enter.
  4. When the Claude chat screen appears, type  /exit  and press Enter.

That is the only time you will type anything like this. After it, you live in
the web browser.
EOF
  printf '\nPress Enter to start sign-in (or type s + Enter to skip): ' >/dev/tty
  read -r ans </dev/tty || true
  if [ "${ans:-}" = "s" ]; then
    warn "Skipped. The web UI will ask you to sign in the first time you use it."
  else
    # Run the sign-in FROM the ops brain directory. Two reasons: Claude reads
    # project settings from the current directory's .claude/ (running elsewhere,
    # e.g. the installer's /root cwd, makes it try to read /root/.claude and fail
    # with EACCES as hhagent), and running a session here registers homelab-ops
    # under ~/.claude/projects/ so the web UI opens it preloaded with the skills.
    # HOME is set explicitly rather than trusting sudo -H.
    sudo -u "$AGENT_USER" -H bash -c "export HOME=\"${AGENT_HOME}\"; export NVM_DIR=\"\$HOME/.nvm\"; . \"\$NVM_DIR/nvm.sh\"; cd \"\$HOME/homelab-ops\"; exec claude" </dev/tty || true
  fi
fi

# ---------------------------------------------------------------------------
say "10/10  Add your servers"
echo "Looking for servers on your network you can add..."
hh scan --add </dev/tty || warn "network scan did not complete"
while [ "$(printf 'Add another server by hand? (y/N): ' >/dev/tty; read -r a </dev/tty || true; echo "${a:-N}")" = "y" ]; do
  hh add-host </dev/tty || warn "add-host did not complete"
done

# ---------------------------------------------------------------------------
# Hand off to the web UI. This is the last thing the user reads.
IP="$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')"
[ -n "$IP" ] || IP="<this-lxc-ip>"
PORT_VAL="$(grep -E '^PORT=' "${CFG_DIR}/cloudcli.env" | cut -d= -f2)"

cat <<EOF

==================================================================

   HomelabHero is ready. Everything from here happens in your browser.

        Open this:   http://${IP}:${PORT_VAL:-3001}

   First visit:
     - create your web login
     - open the "homelab-ops" project
     - if it asks, click the gear icon and turn tools on

   Then just talk to it: "how is everything doing", "what's running",
   "restart jellyfin". You should not need this terminal again.

   (It keeps itself updated weekly. To check its health later, the web
    terminal has:  hh doctor)

==================================================================
EOF
