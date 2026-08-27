# Layout, platforms and persistence

Where everything lives on disk, what differs per platform, and what to back up.

[← back to the README](../README.md)

## Layout


    homelabhero/
    ├── install.sh                 one-line entrypoint (clone + run setup)
    ├── setup/main.sh              full installer
    ├── bin/
    │   ├── hh                     control CLI (agent- and operator-facing)
    │   ├── hh-connect             privileged SSH broker (runs as hhvault)
    │   ├── hh-unifi               read-only UniFi API broker (runs as hhvault)
    │   ├── hh-firewalla           read-only Firewalla MSP broker (runs as hhvault)
    │   ├── hh-netbird             NetBird mesh broker, read+write (runs as hhvault)
    │   ├── hh-cloudflare          Cloudflare broker, read+write (runs as hhvault)
    │   ├── hh-provision           key-only host registration (UI-safe add)
    │   └── hh-update              the one update command: git pull + re-run
    │                              installer headless, then OS packages + doctor
    ├── templates/                 sudoers, systemd unit, cron job, cloudcli env,
    │                              logrotate rules, bash completion
    └── ops/                       becomes ~hhagent/homelab-ops (git-backed)
        ├── CLAUDE.md              always-loaded context + house rules
        ├── capabilities/          per-platform capability catalogs
        │                          (proxmox, truenas, linux, unifi, firewalla)
        ├── infra/                 environment-specific references
        ├── inventory/             saved inventory snapshots
        ├── runbooks/              resolved incidents accumulate here
        └── .claude/
            ├── settings.json      permission posture (forces the broker)
            └── skills/            triage, inventory, add-server, proxmox,
                                   truenas, truenas-middleware, docker,
                                   host (linux), network, unifi and firewalla
                                   (both read-only), backup-restore,
                                   security-audit, patch-management, deploy-app

## Platform notes


- TrueNAS, Proxmox, Linux: SSH key auth to the admin user. Keys are generated into
  the vault by `hh add-host`. Password auth is supported for stragglers but
  discouraged; a plaintext secret is only as isolated as the user boundary around
  it, which is exactly why the three-user split matters.
- Hosts are reached as root by default, so commands run directly with no sudo. On
  TrueNAS you can connect as `truenas_admin` instead (pass it to `hh provision`);
  `midclt` reaches the middleware and covers most TrueNAS work regardless.
- TrueNAS changed its VM engine twice (libvirt through 24.10, Incus on 25.04 and
  25.10, back to libvirt on 26), and the middleware method names moved with it.
  Inventory queries both namespaces, so VMs and LXCs are listed on any of them
  with nothing to configure. On 26, which is still beta, LXC containers may not
  be listed yet if they sit under a namespace neither of those covers.
- UniFi: API key, read-only, never SSH. A UniFi console is registered with
  `hh add-unifi` and reached with `hh unifi <op>`; `hh run` refuses it and says
  so. Needs UniFi OS (UDM, UCG, UDR, Cloud Key Gen2+, UniFi OS Server) on
  Network 9.0 or newer, since API keys do not exist on the old self-hosted
  Network application.
- Firewalla: MSP personal access token, read-only, never SSH. Registered with
  `hh add-firewalla` and reached with `hh firewalla <op>`; `hh run` refuses it and
  says so. Firewalla ships no supported local API, so this goes through Firewalla
  MSP over the internet and needs an MSP account - and it goes down when your
  internet does. Unlike UniFi there is no view-only token to mint, so the
  GET-only broker is the only thing keeping that token from being able to write.
- No MCP servers and no Grafana/Prometheus. The whole surface is SSH, two
  read-only router APIs, plus the capability catalogs, kept simple on purpose.

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
