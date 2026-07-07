# HomelabHero

Turn a fresh LXC into an AI homelab command center. One command installs Claude
Code plus the claudecodeui web front end, preloaded with context and
troubleshooting skills, and wires up a credential broker so Claude can operate
your TrueNAS, Proxmox, and Linux machines over SSH without ever seeing a single
credential.

## Install (one time)

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
    hh update                    update the OS + Claude now (operator)
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

A weekly cron job (`/etc/cron.d/homelabhero`, Sundays at 04:00) updates the OS
packages and Claude, restarts the command center, and runs a health check, logging
everything to `/var/log/homelabhero-update.log`. Edit that one file to change the
schedule, or delete it to turn auto-update off. Run it on demand with `hh update`.

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
    │   └── hh-update              OS + Claude updater (run by cron / hh update)
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
