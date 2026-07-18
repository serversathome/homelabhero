<p align="center">
  <a href="https://youtu.be/dqKj2zKW1Ys">
    <img src="https://img.youtube.com/vi/dqKj2zKW1Ys/maxresdefault.jpg" width="600" alt="Watch the video">
  </a>
  <br>
  <em> [ ▸ ] Watch it on YouTube</em>
</p>

# HomelabHero

Turn a fresh LXC into an AI homelab command center. One command installs Claude
Code plus the claudecodeui web front end, preloaded with context and
troubleshooting skills, and wires up a credential broker so Claude can operate
your TrueNAS, Proxmox, and Linux machines over SSH without ever seeing a single
credential.

## Install and update

On a fresh Ubuntu 26.04 LXC, run one command. (The installer is Ubuntu/Debian
only: it uses `apt`, `systemd`, and `visudo`. It has not been tested on other
distros.) A new LXC usually has only a root user and no curl, so this installs
curl first (drop the `apt` part if you already have curl; add `sudo` in front of
`apt` if you run as a non-root user):

    apt update && apt install -y curl && \
      curl -fsSL https://raw.githubusercontent.com/serversathome/homelabhero/main/install.sh | bash

Then just answer the prompts. The script installs everything, walks you through
signing Claude in once, finds and adds your servers, and finishes by handing you
a browser link. From that point on you live in the web UI and talk to Claude in
plain language ("how is everything doing", "what's running", "restart jellyfin").
You do not need to remember any commands.

The `hh` commands below still exist for power users and are available in the web
UI's built-in terminal, but the normal experience is the browser.

### Updating to the latest code

Re-run the exact same command to update an existing box to the latest HomelabHero:

    apt update && apt install -y curl && \
      curl -fsSL https://raw.githubusercontent.com/serversathome/homelabhero/main/install.sh | bash

This is a **reinstall, not a reconfigure.** It is idempotent: it pulls the latest
code and refreshes the installed pieces, but it keeps your users, your
credentials, your registered hosts (your `hh list` is left exactly as-is), and
your ops notes. It skips Claude sign-in if you are already signed in. Safe to run
any time, and it is the way to force the very latest immediately.

You rarely need to do this by hand, though: `hh upgrade` runs this exact installer
for you (non-interactively), and the weekly job runs it automatically (see
[Staying up to date](#staying-up-to-date-with-homelabhero-itself)). Re-running the
one-liner is just the manual equivalent - handy to force the very latest right now,
or to onboard a box that predates self-update.

## Commands

    hh list                      registered hosts (no secrets)
    hh run <alias> "<command>"   run a command on a host via the broker
    hh test <alias>              connectivity check
    hh overview                  read-only vitals sweep across all hosts
    hh inventory [alias]         what is RUNNING (VMs, LXCs, containers, apps)
    hh diff [alias]              inventory drift vs the last saved snapshot
    hh scan [cidr]               discover live hosts on the network
    hh doctor                    check the whole setup is healthy
    hh provision <alias> <host> [port] [platform] [user]
                                 register a host with a generated key (UI-safe);
                                 connects as root by default (pass a user to override)

    hh add-host                  register a host (operator)
    hh rm-host <alias>           remove a host and its credential
    hh update                    update the OS packages now (operator)
    hh upgrade                   update HomelabHero: code, skills, Node (operator)
    hh login                     log Claude Code in as the agent user
    hh audit [lines]             review the broker audit log (operator)
    hh version                   print the HomelabHero version

## The idea

- A control-plane LXC that reaches everything else. It runs the UI and the agent;
  the workloads stay on your real machines.
- Claude connects only through `hh run <alias> "<command>"`. Same command for
  TrueNAS, Proxmox, and any Linux host, all reached as a normal shell over SSH.
- Credentials never touch the LLM (see below).

## Credential isolation (the important part)

HomelabHero uses privilege separation with a connection broker. Three users:

- your operator account (installs, registers hosts)
- `hhagent` (runs Claude and the web UI, deliberately low-privilege)
- `hhvault` (owns every credential, mode 700)

Claude runs as `hhagent`, which cannot read anything `hhvault` owns. To reach a
host, Claude runs `hh run`, which invokes the broker `hh-connect` through a single
narrow sudoers rule (`hhagent` may run only that one program, only as `hhvault`).
The broker looks the host up in the non-secret registry, reads the key or password
from the vault, and opens the connection. Claude gets the output, never the secret.
Even a fully hijacked agent cannot exfiltrate a credential, because the OS will not
let it read the vault and will not let it run anything but the broker as `hhvault`.
The broker also refuses loopback targets and unregistered aliases.

Every brokered command and host registration is recorded to
`/var/log/homelabhero-broker.log`, owned by `hhvault` and unreadable by the agent,
so a hijacked agent can neither read past activity nor erase its own tracks. The
log rotates weekly (`/etc/logrotate.d/homelabhero`). Review it as an operator with
`hh audit [lines]` (needs sudo; the agent cannot read it, by design).

What this protects: credential material never enters Claude's context and cannot be
exfiltrated. What it does not do: restrict what Claude may run on a host it is
already allowed to reach. That is handled by the approval prompts and confirm-first
rule in the ops brain. Two layers, both kept.

Register hosts from a real admin shell (not the Claude web terminal) so the secrets
you type never pass through an LLM-driven session.

## What Claude knows

- Full platform capability catalogs (`ops/capabilities/`) for Proxmox, TrueNAS, and
  Linux, so Claude uses the whole toolset of each system, not just the basics.
- Live inventory via `hh inventory`: Proxmox VMs and LXCs, TrueNAS apps and pools,
  and Docker containers wherever they run. `hh inventory --save` snapshots into
  `ops/inventory/` so state changes show up in git over time.
- Environment-specific notes about your setup in `ops/infra/`.

## Discovery (point and click)

`hh scan` sweeps your subnet (auto-detected, or pass a CIDR) for live management
endpoints and guesses what each is (Proxmox on 8006, SSH on 22, and so on), marking
which are already registered. `hh scan --add` turns that into a picker: choose the
numbers you want and it walks you through registering each, pre-filling the address
and platform.

## Adding servers from the UI

You do not have to shell in to add machines. Just ask Claude in the browser, e.g.
"add my TrueNAS at 10.0.0.20". Claude runs `hh provision`, which registers the
host and generates a keypair in the vault, then hands you the public key to paste
into the target's admin UI (TrueNAS user SSH keys, Proxmox authorized_keys, or a
Linux authorized_keys). No password ever passes through the chat, and the agent
never sees the private key. `hh test <alias>` confirms it once the key is
installed. Password-based onboarding stays in the shell-only `hh add-host` for an
admin, since a password can't be handled safely in an LLM session.

## Auto-updates and health

A weekly cron job (`/etc/cron.d/homelabhero`, Sundays at 04:00) runs two jobs in
order, logging everything to `/var/log/homelabhero-update.log`:

1. **`hh-upgrade`** - update HomelabHero itself (see below).
2. **`hh-update`** - update the OS packages (`apt`) and run a health check.

Edit that one file to change the schedule, or delete it to turn auto-update off. The
two are separate on purpose: `hh update` is a quick, low-risk OS patch that never
touches Node or restarts the stack, while `hh upgrade` handles the application side.

### Staying up to date with HomelabHero itself

`hh-upgrade` is the single upgrade path. It `git pull`s the release you installed from
and **re-runs the installer non-interactively** - so an upgrade produces exactly what a
fresh install does: the `hh` CLI and broker, the shipped skills / `CLAUDE.md` /
capability docs, Node and npm at the latest LTS, the Claude Code + claudecodeui packages
(reinstalled with the correct `--allow-scripts` set so their native modules always
build), and the systemd unit. Improvements and fixes pushed to the repo reach existing
boxes on their own; nobody has to re-run the installer by hand. Run it on demand with
`hh upgrade`.

Because it re-runs the real installer, there is no "some changes only the installer can
apply" gap anymore - `hh upgrade` **is** the installer. Node tracks the latest LTS
automatically each week.

What it will and will not touch is deliberate:

- **Refreshed** (HomelabHero-owned): the CLI binaries, `.claude/skills/`,
  `.claude/settings.json`, `CLAUDE.md`, `capabilities/`, the logrotate/sudoers/service
  templates, and the Node/npm stack. An in-place edit to one of these *shipped* files
  will be overwritten - customize instead by adding your own skill, using
  `settings.local.json`, or filling in the notes below.
- **Never touched** (yours): your environment notes under `infra/`, `inventory/`,
  `runbooks/`, `hosts/`, your edited cron schedule, and `cloudcli.env`. Your own
  custom skills in `.claude/skills/` are preserved too. Ops-brain changes land in the
  working tree, so `git -C ~hhagent/homelab-ops diff` shows exactly what an upgrade
  changed.

The installer also always reasserts the `claude` binary with the postinstall allowed,
so the "installed but cannot start" failure (issue #11, a newer npm blocking install
scripts) self-heals on every upgrade. One bootstrapping limit remains: self-update only
reaches boxes that installed successfully and can run the weekly job, and a box that
predates self-update needs **one** manual re-run of the one-liner to enable it (that
writes `/etc/homelabhero/install.conf`, after which it maintains itself).

Because an update can occasionally break something, `hh doctor` checks the whole
chain in one pass: the users, the broker, vault permissions, the service, Claude's
version, every host's reachability, and the last update result. Run it any time; the
auto-update runs it for you after each update.

## Layout

    homelabhero/
    ├── install.sh                 one-line entrypoint (clone + run setup)
    ├── setup/main.sh              full installer
    ├── bin/
    │   ├── hh                     control CLI (agent- and operator-facing)
    │   ├── hh-connect             privileged broker (runs as hhvault)
    │   ├── hh-provision           key-only host registration (UI-safe add)
    │   ├── hh-update              OS package updater + health check (hh update)
    │   └── hh-upgrade             self-updater: git pull + re-run installer headless
    ├── templates/                 sudoers, systemd unit, cron job, cloudcli env,
    │                              logrotate rules, bash completion
    └── ops/                       becomes ~hhagent/homelab-ops (git-backed)
        ├── CLAUDE.md              always-loaded context + house rules
        ├── capabilities/          per-platform capability catalogs
        ├── infra/                 environment-specific references
        ├── inventory/             saved inventory snapshots
        ├── runbooks/              resolved incidents accumulate here
        └── .claude/
            ├── settings.json      permission posture (forces the broker)
            └── skills/            triage, inventory, add-server, proxmox,
                                   truenas, truenas-middleware, docker,
                                   host (linux), network, backup-restore,
                                   security-audit, patch-management, deploy-app

## Platform notes

- TrueNAS, Proxmox, Linux: SSH key auth to the admin user. Keys are generated into
  the vault by `hh add-host`. Password auth is supported for stragglers but
  discouraged; a plaintext secret is only as isolated as the user boundary around
  it, which is exactly why the three-user split matters.
- Hosts are reached as root by default, so commands run directly with no sudo. On
  TrueNAS you can connect as `truenas_admin` instead (pass it to `hh provision`);
  `midclt` reaches the middleware and covers most TrueNAS work regardless.
- No MCP servers and no Grafana/Prometheus. The whole surface is SSH plus the
  capability catalogs, kept simple on purpose.

## Persistence and backup

Everything lives on the LXC rootfs, which persists across reboots. Put the LXC on a
snapshotted dataset and add it to your Proxmox backup schedule. The ops brain is a
git repo; push it to your own GitHub for a second copy. The vault is intentionally
excluded from anything git-tracked.

Note that snapshots and backups of the LXC *do* contain the vault, and the vault
keys are stored unencrypted (they have to be, for non-interactive automation).
Their safety rests on the `hhvault` user boundary, which a raw filesystem copy
bypasses, so treat those backups as secret material: keep them somewhere only you
can reach, exactly as you would the private keys themselves.
