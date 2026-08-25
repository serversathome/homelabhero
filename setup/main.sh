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
# Pristine copy of the ops files HomelabHero owns, as last shipped. It is what
# makes an update able to tell "the user edited this" from "this is simply old".
SHIPPED_DIR="${CFG_DIR}/shipped"
NODE_LTS_MIN=22
# Non-interactive mode. `hh update` re-runs this installer headless (weekly via
# cron and on demand) with HH_NONINTERACTIVE=1, which skips only the two
# interactive steps - Claude sign-in (9) and adding servers (10). Everything else
# is idempotent, so an update produces exactly what a fresh install does.
HH_NONINTERACTIVE="${HH_NONINTERACTIVE:-0}"

say()  { printf '\n\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Preflight. HomelabHero needs a real Linux instance (LXC or VM) with working
# systemd and working sudo privilege escalation. Both TrueNAS and Proxmox LXCs
# qualify once configured correctly; a bare Docker "app" or a locked-down Incus
# container does not. Fail fast here with an actionable message instead of
# breaking cryptically halfway through (or, worse, only later at runtime).
preflight() {
  # no_new_privs stops sudo from gaining root, and the broker runs through sudo.
  # The flag lives in two different places with two completely different fixes,
  # so read them separately and only complain when the combination really breaks:
  #   * set on PID 1 -> the whole container is constrained, including the
  #     command center service, which PID 1 forks. That is the TrueNAS/Incus
  #     "no new privileges" install failure, and it is a container-level fix.
  #   * set only on this shell -> the container is fine; the attaching shell
  #     (TrueNAS web shell, lxc-attach) set it for this session alone. The
  #     service is unaffected. Recreating the container does NOT fix it.
  # The flag is one-way - a process can set it but can never clear it - so a
  # shell that has it must be replaced, not repaired. If /proc/1/status cannot
  # be read we cannot tell the two apart, so say nothing rather than guess.
  if [ -r /proc/1/status ]; then
    if grep -qs '^NoNewPrivs:[[:space:]]*1' /proc/1/status; then
      cat >&2 <<'EOF'

[error] This container has the "no new privileges" (no_new_privs) flag set on
        PID 1, so everything inside it - including the command center service -
        inherits the flag. It stops sudo from gaining root, and HomelabHero's
        connection broker runs through sudo, so nothing works until it is
        cleared.

        Unprivileged container managers set this flag. To fix it:

          - Proxmox LXC works as-is (the flag is not set there by default).

          - On TrueNAS, recreate the instance as "privileged". TrueNAS switched
            its container backend from Incus (25.x) to libvirt (26), so the exact
            toggle moved between versions and some builds keep the flag on even
            when privileged. If it still fails after that, run HomelabHero in a
            VM instead: a VM has its own kernel and none of these restrictions.

        Then re-run this installer inside the instance.
EOF
      die "no_new_privs is set on PID 1; sudo cannot escalate to root (see above)."
    elif grep -qs '^NoNewPrivs:[[:space:]]*1' /proc/self/status; then
      cat >&2 <<'EOF'

        This shell has the "no new privileges" (no_new_privs) flag set, but PID 1
        does not - so the container itself is fine and only this session is
        affected. The TrueNAS web shell and lxc-attach set the flag per session.
        sudo refuses to escalate under it, and the flag cannot be cleared once
        set, so this shell cannot be repaired - use a different one:

          systemd-run --pty --quiet /bin/bash    (a shell spawned by PID 1)

        or SSH into the container instead of attaching from the host UI. Then
        re-run this installer there.

        Do NOT recreate the container as privileged: this is not a container
        setting, and on TrueNAS 26 the ID Map Type is fixed at creation, so that
        costs a full rebuild and does not fix this.
EOF
      if [ "$(id -u)" -eq 0 ]; then
        warn "no_new_privs is set on this shell only; continuing, since this shell is already root and nothing here has to escalate."
      else
        die "no_new_privs is set on this shell; sudo cannot escalate to root (see above)."
      fi
    fi
  fi

  # The command center is installed and run as a systemd service.
  if [ ! -d /run/systemd/system ]; then
    cat >&2 <<'EOF'

[error] systemd is not the init system here. HomelabHero runs its command center
        as a systemd service, so it needs a systemd-based instance: a normal
        Ubuntu/Debian LXC (TrueNAS Instances or Proxmox) or a VM. A bare Docker
        container is not enough.
EOF
    die "systemd not detected (no /run/systemd/system)."
  fi
}
preflight

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
# openssl is what pins a UniFi console's TLS key at registration (see hh-unifi).
$SUDO apt-get install -y --no-install-recommends \
  sudo git curl ca-certificates build-essential openssh-client sshpass \
  tmux jq ripgrep rsync unzip iputils-ping dnsutils netcat-openbsd nmap acl openssl

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
$SUDO install -o root -g root -m 755 "${REPO_ROOT}/bin/hh-unifi"   /usr/local/bin/hh-unifi
$SUDO install -o root -g root -m 755 "${REPO_ROOT}/bin/hh-firewalla" /usr/local/bin/hh-firewalla
$SUDO install -o root -g root -m 755 "${REPO_ROOT}/bin/hh"         /usr/local/bin/hh
$SUDO install -o root -g root -m 755 "${REPO_ROOT}/bin/hh-update"  /usr/local/bin/hh-update
$SUDO install -o root -g root -m 755 "${REPO_ROOT}/bin/hh-provision" /usr/local/bin/hh-provision
# hh-upgrade was merged into hh-update (one `hh update` command does everything);
# remove the retired binary from boxes that had it.
$SUDO rm -f /usr/local/bin/hh-upgrade
# Record where this git checkout lives (non-secret) so hh-update can pull future
# releases and re-run this installer, weekly. Branch and remote come from the
# checkout itself so custom forks/branches keep working.
HH_BRANCH_NOW="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"
[ "$HH_BRANCH_NOW" = "HEAD" ] && HH_BRANCH_NOW="main"
HH_REPO_NOW="$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null || echo https://github.com/serversathome/homelabhero.git)"
printf 'CHECKOUT=%s\nBRANCH=%s\nREPO=%s\n' "$REPO_ROOT" "$HH_BRANCH_NOW" "$HH_REPO_NOW" \
  | $SUDO tee "${CFG_DIR}/install.conf" >/dev/null
$SUDO chown root:root "${CFG_DIR}/install.conf"; $SUDO chmod 644 "${CFG_DIR}/install.conf"
# Bash completion for the hh CLI (subcommands + host aliases).
$SUDO install -o root -g root -m 644 "${REPO_ROOT}/templates/hh.completion" /etc/bash_completion.d/hh
# Weekly auto-update (edit or delete /etc/cron.d/homelabhero to change). Install
# only if absent: since `hh update` re-runs this installer, overwriting here every
# week would silently revert a user's edited schedule.
[ -f /etc/cron.d/homelabhero ] || \
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
OPS_DST="${AGENT_HOME}/homelab-ops"
sudo -u "$AGENT_USER" mkdir -p "$OPS_DST"

# Seed the baseline for a box that has never had one.
#
# Without a baseline the sync below cannot tell "the user edited this" from
# "this is simply the old version", so it falls back to overwrite-with-.bak:
# lossless, but it flattens every local edit once and leaves a backup beside
# every file that changed, edited or not.
#
# This has to live HERE, in the installer, and that is the whole point. During
# the update that first introduces the baseline, the hh-update running on the
# box is still the OLD one, from before any of this code existed - hh-update
# pulls and then runs the installer, and the installer is what replaces
# hh-update. So the new hh-update only exists after the run that needed it.
# Anything written there for this transition can never fire for it. That is not
# hypothetical: 1.3.2 put the seeding in hh-update and it never ran once.
#
# The installer, by contrast, IS already the new version at this point. And it
# can recover what it needs: `git reset --hard` in hh-update sets ORIG_HEAD to
# the revision the box was running before the pull, which is exactly the tree
# that produced the live ops brain.
if [ ! -d "$SHIPPED_DIR" ] && [ -d "${REPO_ROOT}/.git" ]; then
  PREV_REV="$(git -C "$REPO_ROOT" rev-parse --verify --quiet ORIG_HEAD || true)"
  if [ -n "${PREV_REV:-}" ]; then
    $SUDO install -d -o root -g root -m 755 "$SHIPPED_DIR"
    if git -C "$REPO_ROOT" archive "$PREV_REV" ops 2>/dev/null \
         | $SUDO tar -x --strip-components=1 -C "$SHIPPED_DIR" 2>/dev/null; then
      say "    baseline seeded from ${PREV_REV:0:7}; local edits will be preserved, not backed up"
    else
      # Not fatal - the sync just falls back to backing up whatever it replaces.
      [ -n "$SHIPPED_DIR" ] && $SUDO rm -rf -- "$SHIPPED_DIR"
      warn "could not seed the shipped-file baseline; files this update replaces will be backed up instead"
    fi
  fi
fi
$SUDO install -d -o root -g root -m 755 "$SHIPPED_DIR"

# Two halves to the ops tree, and `hh update` re-runs this installer weekly, so
# what happens here to an edited file happens every week.
#
#   * User-owned, add-only: infra/, inventory/, runbooks/, hosts/. New stubs are
#     added, existing notes are never touched. Unchanged.
#   * HomelabHero-owned: the skills, settings.json, capability docs, CLAUDE.md.
#     These have to keep receiving updates - that is how a skill improves - but
#     they are also the files the docs invite you to make your own.
#
# That second half used to be restored from the shipped copy unconditionally, so
# a renamed operator in a skill description, an environment note added to a
# capability doc, or a paragraph appended to CLAUDE.md was thrown away on the
# next cron run. Silently: no output, no backup, nothing to recover from.
#
# So keep a pristine copy of what was last shipped and compare three ways, the
# way dpkg handles a conffile. See sync_shipped below.
STAMP="$(date +%Y%m%d-%H%M%S)"
SYNC_UPDATED=(); SYNC_KEPT=(); SYNC_BACKED=()

# Deliver one shipped file, without ever destroying a local edit:
#
#   live missing        -> install it (fresh install, or a newly shipped file)
#   live == new         -> already current, nothing to do
#   live == pristine    -> the user never touched it; deliver the update
#   new  == pristine    -> the user edited it and upstream did NOT change;
#                          leave it alone and say nothing (this is the steady
#                          state for a personalised file, and it must be quiet)
#   all three differ    -> the user edited it AND upstream changed. KEEP the
#                          user's file, drop the new one beside it as
#                          <file>.upstream, and report it. Never merge blind.
#
# With no pristine copy yet - the first run after this change lands - an edit is
# indistinguishable from an old version, so the update still goes in, but the
# previous file is backed up to <file>.bak-<stamp> first. That way even the
# one-time bootstrap run loses nothing, and every run after it preserves in
# place instead of backing up.
sync_shipped() {
  # Declared separately on purpose: `local a=$1 b=${a}` expands every word
  # BEFORE the builtin assigns any of them, so a later one cannot reference an
  # earlier one - under `set -u` that is an unbound-variable abort, not a subtle
  # bug, and it takes the whole install with it.
  local src="$1" rel="$2"
  local live="${OPS_DST}/${rel}"
  local old="${SHIPPED_DIR}/${rel}"
  $SUDO install -d -m 755 "$(dirname "$live")"
  if ! $SUDO test -e "$live"; then
    $SUDO install -m 644 "$src" "$live"
  elif $SUDO cmp -s "$src" "$live"; then
    :
  elif $SUDO test -e "$old" && $SUDO cmp -s "$old" "$live"; then
    $SUDO install -m 644 "$src" "$live"; SYNC_UPDATED+=("$rel")
  elif $SUDO test -e "$old" && $SUDO cmp -s "$old" "$src"; then
    :
  elif $SUDO test -e "$old"; then
    $SUDO install -m 644 "$src" "${live}.upstream"; SYNC_KEPT+=("$rel")
  else
    $SUDO cp -p "$live" "${live}.bak-${STAMP}"
    $SUDO install -m 644 "$src" "$live"; SYNC_BACKED+=("$rel")
  fi
  # The pristine copy always tracks what was SHIPPED, whatever happened to the
  # live file. Getting this wrong (only recording it when the file was written)
  # would compare next week's edit against an ancient version and report a
  # conflict for a change the user already resolved.
  $SUDO install -D -m 644 "$src" "$old"
}

while IFS= read -r f; do
  sync_shipped "$f" "${f#"${REPO_ROOT}/ops/"}"
done < <(find "${REPO_ROOT}/ops/.claude" "${REPO_ROOT}/ops/capabilities" -type f | sort)
sync_shipped "${REPO_ROOT}/ops/CLAUDE.md" "CLAUDE.md"

# Everything else: add-only, exactly as before.
$SUDO rsync -a --ignore-existing "${REPO_ROOT}/ops/" "${OPS_DST}/"
# The supported place for local additions to the ops brain. CLAUDE.md imports it
# and this installer never overwrites it, so anything here survives every update
# by construction rather than by luck.
if ! $SUDO test -e "${OPS_DST}/CLAUDE.local.md"; then
  $SUDO tee "${OPS_DST}/CLAUDE.local.md" >/dev/null <<'LOCALMD'
# Local notes

Yours. HomelabHero never overwrites this file, and `CLAUDE.md` imports it, so
anything here is loaded on every session and survives every update.

Good things to put here:

- Who you are, if you want Claude to use your name: "The operator is <name>."
- House rules that differ from the shipped ones.
- Pointers to your own docs, dashboards, or runbooks.
- Anything you would otherwise be tempted to edit into CLAUDE.md itself.
LOCALMD
fi
$SUDO chown -R "$AGENT_USER:$AGENT_USER" "$OPS_DST"

# Say what happened. An update that quietly declines to update something is only
# better than one that quietly overwrites it if the user is told.
if [ "${#SYNC_BACKED[@]}" -gt 0 ]; then
  warn "First run under the new update rules. These files differed from the shipped"
  warn "version, so they were updated and the previous copy kept as .bak-${STAMP}:"
  for f in "${SYNC_BACKED[@]}"; do printf '         %s\n' "$f"; done
  warn "From now on local edits are preserved in place instead."
fi
if [ "${#SYNC_KEPT[@]}" -gt 0 ]; then
  warn "You have edited these files, and a newer version shipped. YOUR copy was kept."
  warn "The new version is beside it as <file>.upstream - merge what you want:"
  for f in "${SYNC_KEPT[@]}"; do printf '         %s\n' "$f"; done
fi
sudo -u "$AGENT_USER" -H bash -lc "cd ~/homelab-ops && [ -d .git ] || (git init -q && git add -A && git -c user.name='HomelabHero' -c user.email='homelabhero@localhost' commit -q -m 'HomelabHero scaffold')" || true

# The low-privilege agent user must be able to READ its ops brain. On TrueNAS/ZFS
# an inherited NFSv4 ACL can deny this even when the mode bits look right (644),
# which otherwise surfaces later as "cannot read CLAUDE.md". Catch it now and
# print the exact fix rather than leaving a broken command center.
if ! sudo -u "$AGENT_USER" test -r "${AGENT_HOME}/homelab-ops/CLAUDE.md"; then
  warn "Agent user '${AGENT_USER}' cannot read ${AGENT_HOME}/homelab-ops/CLAUDE.md."
  warn "This is usually a ZFS/NFSv4 ACL overriding the file mode (common on TrueNAS)."
  warn "Fix it, then re-run 'hh doctor':"
  warn "    sudo setfacl -R -m u:${AGENT_USER}:rX '${AGENT_HOME}/homelab-ops'"
fi

# ---------------------------------------------------------------------------
say "7/10  Node (nvm) + Claude Code + claudecodeui, as ${AGENT_USER}"
sudo -u "$AGENT_USER" -i bash <<'AGENT'
set -e
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] || curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
. "$NVM_DIR/nvm.sh"
nvm install --lts
nvm alias default 'lts/*'
# Anthropic's native installer puts a self-contained, self-updating claude in
# ~/.local/bin, which a non-login shell does NOT have on PATH. Add it here so
# the checks below can see one; the generated systemd unit does the same for
# the service.
export PATH="$HOME/.local/bin:$PATH"

# Is a NATIVE claude already installed and working? Two decisions hang on this:
# whether to install the npm package at all, and whether a broken npm package is
# fatal or merely something to route around.
native_claude() { [ -x "$HOME/.local/bin/claude" ] && "$HOME/.local/bin/claude" --version >/dev/null 2>&1; }

# A native install WINS, and keeps winning. `hh update` re-runs this installer
# every week, so anything unconditional here is re-applied every week: leaving
# the npm package in the list would recreate its bin link and clobber a working
# native claude on every cron run - the same weekly-clobber dynamic the
# --allow-scripts fix had to solve one layer up. A native claude also updates
# itself, so npm has no reason to touch it at all.
pkgs="@cloudcli-ai/cloudcli"
if native_claude; then
  echo "[info] native claude present at $HOME/.local/bin/claude ($("$HOME/.local/bin/claude" --version 2>/dev/null | head -1)); leaving it alone and skipping the npm claude-code package."
else
  pkgs="@anthropic-ai/claude-code ${pkgs}"
fi

# npm v12 BLOCKS dependency install scripts by default (v11 only warns). Those
# scripts build native modules, so they must be explicitly allowed or the package
# lands on disk broken. Allow the two first-party packages AND cloudcli's native
# deps - better-sqlite3 (its DB), node-pty (the web terminal), bcrypt (auth) -
# which are NOT covered transitively by allowing the top-level package. Older npm
# ignores the flag and runs scripts anyway, so this is safe everywhere.
allow="@anthropic-ai/claude-code,@cloudcli-ai/cloudcli,better-sqlite3,node-pty,bcrypt"
# shellcheck disable=SC2086  # $pkgs is a deliberate list of package arguments.
if ! out="$(npm install -g --allow-scripts="$allow" $pkgs 2>&1)"; then
  printf '%s\n' "$out"; echo "[error] npm global install failed"; exit 1
fi
printf '%s\n' "$out"
# Drift guard: if npm still flags ANY package as having uncovered install scripts,
# a newer cloudcli pulled in a native dep we do not list. Surface the names loudly
# so it is fixed before an npm-v12 box silently breaks, rather than letting a
# hardcoded list quietly rot.
missed="$(printf '%s\n' "$out" | sed -n 's/^npm warn allow-scripts[[:space:]]\{1,\}\([^ ]\{1,\}\)@.*/\1/p' | sort -u | paste -sd, -)"
if [ -n "$missed" ]; then
  echo "[warn] npm reports install scripts NOT in the allowlist: ${missed}"
  echo "[warn] harmless on npm 11 (scripts still run) but they are BLOCKED on npm 12."
  echo "[warn] add them to the allow-scripts list in setup/main.sh and re-run."
fi

# Do not trust "npm said ok". The npm package ships the actual binary as a
# PLATFORM-SPECIFIC OPTIONAL dependency (@anthropic-ai/claude-code-linux-x64),
# and on some machines npm never resolves it: the install reports success,
# installs one package instead of two, and leaves behind a claude that cannot
# start. The only way to know is to run it.
#
# When it does not run, install Anthropic's native build instead. It is
# self-contained, has no optional platform dependency to miss, and lands in
# ~/.local/bin - which is first on the service's PATH and is what the branch at
# the top of this block will find (and preserve) on every future update.
if ! native_claude; then
  hash -r 2>/dev/null || true
  if ! claude --version >/dev/null 2>&1; then
    echo "[warn] the npm-installed claude does not run - npm could not resolve its platform package."
    echo "[warn] falling back to Anthropic's native installer -> $HOME/.local/bin/claude"
    curl -fsSL https://claude.ai/install.sh | bash || { echo "[error] the native claude installer failed"; exit 1; }
    hash -r 2>/dev/null || true
    native_claude || { echo "[error] claude still does not run after the native install"; exit 1; }
    # Retire the broken npm copy. The native one already wins on PATH, but two
    # claudes on one box is one more than anybody should have to reason about.
    npm uninstall -g @anthropic-ai/claude-code >/dev/null 2>&1 || true
    echo "[info] native claude installed: $("$HOME/.local/bin/claude" --version 2>/dev/null | head -1)"
  fi
fi
AGENT

# Resolve node/cloudcli/claude in a shell that actually has nvm loaded. A login
# shell alone does NOT load nvm on Ubuntu (.bashrc returns early when
# non-interactive), so we source nvm explicitly, and prepend ~/.local/bin so a
# natively installed claude resolves here exactly as it does in the service.
# The || true lets the checks below report clearly.
nvm_run() { sudo -u "$AGENT_USER" -H bash -c "export NVM_DIR=\"${AGENT_HOME}/.nvm\"; [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\" >/dev/null 2>&1; export PATH=\"${AGENT_HOME}/.local/bin:\$PATH\"; $*"; }
NODE_BIN="$(nvm_run 'dirname "$(command -v node)"' 2>/dev/null)" || true
CLOUDCLI="$(nvm_run 'command -v cloudcli' 2>/dev/null)" || true
CLAUDE_BIN="$(nvm_run 'command -v claude' 2>/dev/null)" || true
NODE_MAJOR="$(nvm_run 'node -p "process.versions.node.split(\".\")[0]"' 2>/dev/null)" || true
NODE_VER="$(nvm_run 'node -v' 2>/dev/null)" || true
[ -n "$NODE_BIN" ] || die "node not found after install (nvm did not load)."
[ -n "$CLOUDCLI" ] || die "cloudcli not found after install."
# claude comes from one of two places by now: the npm package's postinstall, or
# Anthropic's native installer (the fallback above). Missing here means both
# failed, so point at the native installer, which is the one that does not depend
# on npm resolving an optional platform package.
[ -n "$CLAUDE_BIN" ] || die "claude not found after install. Install it by hand as ${AGENT_USER}, then re-run this installer (it will keep that install):
    sudo -u ${AGENT_USER} -i bash -c 'curl -fsSL https://claude.ai/install.sh | bash'"
[ "${NODE_MAJOR:-0}" -ge "$NODE_LTS_MIN" ] || die "Node ${NODE_MAJOR:-?} < ${NODE_LTS_MIN}."
say "    node ${NODE_VER}  cloudcli ${CLOUDCLI}  claude ${CLAUDE_BIN}"

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
$SUDO systemctl enable homelab-cc.service >/dev/null 2>&1 || true
# restart (not just enable --now): on an upgrade the service is already running, and
# it must pick up the new unit, Node, and cloudcli/claude. On a fresh install this
# simply starts it. This is why hh-update no longer restarts separately.
$SUDO systemctl restart homelab-cc.service

# ---------------------------------------------------------------------------
echo
say "Checking the service..."
sleep 2
$SUDO systemctl --no-pager --full status homelab-cc.service | head -n 8 || true

# ---------------------------------------------------------------------------
say "9/10  Sign Claude in (one time)"
if $SUDO test -f "${AGENT_HOME}/.claude/.credentials.json" 2>/dev/null; then
  echo "Already signed in. Skipping."
elif [ "$HH_NONINTERACTIVE" = 1 ]; then
  warn "Not signed in, running non-interactively; skipping. Sign in from the web UI, or run 'hh login'."
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
say "10/10  Add your servers (and your router)"
if [ "$HH_NONINTERACTIVE" = 1 ]; then
  echo "Non-interactive; skipping server discovery. Add hosts anytime with 'hh add-host' or by asking Claude in the UI."
else
  echo "Looking for servers on your network you can add..."
  echo "This also looks for your router. If it is a UniFi console, you can add it"
  echo "with a UniFi API key; HomelabHero only ever reads from it, never writes."
  echo "Have a Firewalla instead? It is added separately, after this, with"
  echo "'hh add-firewalla' and a Firewalla MSP token. Also read-only."
  hh scan --add </dev/tty || warn "network scan did not complete"
  while [ "$(printf 'Add another server by hand? (y/N): ' >/dev/tty; read -r a </dev/tty || true; echo "${a:-N}")" = "y" ]; do
    hh add-host </dev/tty || warn "add-host did not complete"
  done
fi

# ---------------------------------------------------------------------------
# On an upgrade (non-interactive) there is no user watching; a short line is
# enough. The full browser hand-off banner is for a fresh, interactive install.
if [ "$HH_NONINTERACTIVE" = 1 ]; then
  say "HomelabHero is up to date."
  exit 0
fi

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
