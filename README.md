<p align="center">
  <a href="https://youtu.be/dqKj2zKW1Ys">
    <img src="https://img.youtube.com/vi/dqKj2zKW1Ys/maxresdefault.jpg" width="600" alt="Watch the video">
  </a>
  <br>
  <em> [ ▸ ] Watch it on YouTube</em>
</p>


> [!WARNING]
> **Installed or last updated HomelabHero before July 18, 2026? Re-run the installer once.**
>
> A newer version of npm began blocking package install scripts, which broke the native modules HomelabHero depends on (`better-sqlite3`, `node-pty`, `bcrypt`). On affected boxes, Claude Code installed but would not start, or the web UI and terminal failed to load. 
> ```bash
> apt update && apt install -y curl && \
> curl -fsSL https://raw.githubusercontent.com/serversathome/homelabhero/main/install.sh | bash
> ```
>
> This is a reinstall, not a reconfigure. It is safe and idempotent: your users, credentials, and registered servers are preserved, and your `hh list` stays exactly as-is. Nothing gets wiped.
>
> At **Step 10 (adding servers)**, skip it. Your servers are already registered and skipping breaks nothing. Same for the Claude sign-in step if you are already signed in.


# HomelabHero

Turn a fresh LXC into an AI homelab command center. One command installs Claude
Code plus the claudecodeui web front end, preloaded with context and
troubleshooting skills, and wires up a credential broker so Claude can operate
your TrueNAS, Proxmox, and Linux machines over SSH without ever seeing a single
credential.

- A control-plane LXC that reaches everything else. It runs the UI and the agent;
  the workloads stay on your real machines.
- Claude connects only through `hh run <alias> "<command>"`. Same command for
  TrueNAS, Proxmox, and any Linux host, all reached as a normal shell over SSH.
- Credentials never touch the LLM, and cannot: they live in a vault the agent
  user has no permission to read.

## Install

On a fresh Ubuntu 26.04 LXC, one command. (Ubuntu/Debian only - it uses `apt`,
`systemd` and `visudo`.)

    apt update && apt install -y curl && \
      curl -fsSL https://raw.githubusercontent.com/serversathome/homelabhero/main/install.sh | bash

Answer the prompts. It installs everything, signs Claude in once, finds and adds
your servers, and prints a browser link on **port 3001** when it finishes.

Full walkthrough, updating, and how to add machines afterwards:
**[docs/install.md](docs/install.md)**.

## What it can do

    hh list                      registered hosts (no secrets)
    hh run <alias> "<command>"   run a command on a host via the broker
    hh overview                  read-only vitals sweep across every host
    hh inventory                 what is RUNNING everywhere (VMs, LXCs, containers, apps)
    hh scan [cidr]               discover live hosts on the network
    hh doctor                    check the whole setup is healthy

and four networking integrations, each reached over its own API rather than a
shell:

| | what it reads | can it change anything? |
|---|---|---|
| [UniFi](docs/integrations/unifi.md) | WAN and internet health, APs, switches, clients, VLANs | **no** - the broker cannot issue anything but a GET |
| [Firewalla](docs/integrations/firewalla.md) | devices, alarms, flows, bandwidth, rules | **no** - same |
| [NetBird](docs/integrations/netbird.md) | mesh peers, groups, policies, routes, BYOP services | yes, with an Admin token |
| [Cloudflare](docs/integrations/cloudflare.md) | DNS, tunnels and their ingress, Access apps | yes, with an Edit token |

Every subcommand and every per-integration op: **[docs/commands.md](docs/commands.md)**.

## Why the credentials are safe

Claude runs as `hhagent`, which cannot read anything the vault user owns. To
reach a machine it runs `hh run`, which invokes a broker through a single narrow
sudoers rule. The broker looks the host up, reads the key from the vault, opens
the connection, and hands back only the output. Even a fully hijacked agent
cannot exfiltrate a credential, because the OS will not let it read the vault.

The two integrations that CAN change something are fenced separately: no generic
write path, only named operations, and anything destructive refuses to run
without `--force`.

The whole model, including what is *not* protected:
**[docs/security.md](docs/security.md)**.

## Documentation

| | |
|---|---|
| [Installing and adding machines](docs/install.md) | first install, discovery, registering hosts |
| [Command reference](docs/commands.md) | every `hh` subcommand |
| [The security model](docs/security.md) | credential isolation, what the agent knows, how strongly each integration is fenced |
| [Updating and health](docs/updating.md) | `hh update`, the weekly job, `hh doctor` |
| [Layout, platforms, persistence](docs/layout.md) | where things live, per-platform notes, what to back up |
| [Integrations](docs/README.md) | [UniFi](docs/integrations/unifi.md) · [Firewalla](docs/integrations/firewalla.md) · [NetBird](docs/integrations/netbird.md) · [Cloudflare](docs/integrations/cloudflare.md) |
| [CHANGELOG](CHANGELOG.md) | what changed, per release |
| [SECURITY](SECURITY.md) | reporting a vulnerability |
