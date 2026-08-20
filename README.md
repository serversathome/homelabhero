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
a browser link.

When it finishes, open the web UI in your browser on **port 3001**:

    http://<your-lxc-ip>:3001

The installer prints that exact address with the IP filled in as its last line.
(3001 is the default; if you changed `PORT=` in `/etc/homelabhero/cloudcli.env`,
use that port instead.) On your first visit, create your web login, open the
`homelab-ops` project, and — if it asks — click the gear icon and turn tools on.

From that point on you live in the web UI and talk to Claude in plain language
("how is everything doing", "what's running", "restart jellyfin"). You do not
need to remember any commands.

The `hh` commands below still exist for power users and are available in the web
UI's built-in terminal, but the normal experience is the browser.

### Updating to the latest code

You do not have to do anything. Updates arrive on their own: the weekly job runs
`hh update`, and you can run it yourself any time to force the latest right now:

    hh update

That is the one command. It pulls the latest HomelabHero, re-runs the installer
non-interactively to refresh everything (CLI and broker, skills, `CLAUDE.md`,
capability docs, Node/npm at the latest LTS, the Claude Code + claudecodeui
packages, the service), then patches the OS and runs a health check. It is a
**reinstall, not a reconfigure** and fully idempotent: it keeps your users, your
credentials, your registered hosts (your `hh list` is left exactly as-is), and
your ops notes, and skips Claude sign-in if you are already signed in. See
[Staying up to date](#staying-up-to-date-with-homelabhero-itself) for exactly
what it does and does not touch.

If you are onboarding a box that predates self-update (no
`/etc/homelabhero/install.conf`), run the install one-liner once to enable it,
after which `hh update` maintains it:

    apt update && apt install -y curl && \
      curl -fsSL https://raw.githubusercontent.com/serversathome/homelabhero/main/install.sh | bash

To see which version you are on and what changed between releases:

    hh version

[CHANGELOG.md](CHANGELOG.md) explains every release: what was added, what
changed, and anything worth knowing before you update.


## Commands

    hh list                      registered hosts (no secrets)
    hh run <alias> "<command>"   run a command on a host via the broker
    hh test <alias>              connectivity check
    hh overview                  read-only vitals sweep across all hosts
    hh inventory [alias]         what is RUNNING (VMs, LXCs, containers, apps)
    hh diff [alias]              inventory drift vs the last saved snapshot
    hh scan [cidr]               discover live hosts (and your router) on the network
    hh unifi <op> [alias]        read your UniFi router: summary, health, devices,
                                 clients, networks (READ-ONLY, see below)
    hh firewalla <op> [alias]    read your Firewalla: summary, devices, alarms,
                                 flows, bandwidth, rules (READ-ONLY, see below)
    hh doctor                    check the whole setup is healthy
    hh provision <alias> <host> [port] [platform] [user]
                                 register a host with a generated key (UI-safe);
                                 connects as root by default (pass a user to override)

    hh add-host                  register a host (operator)
    hh add-unifi                 register your UniFi router with an API key (operator)
    hh add-firewalla             register your Firewalla with an MSP token (operator)
    hh repin <alias>             re-pin a UniFi console after its cert changed (operator)
    hh rm-host <alias>           remove a host and its credential
    hh update                    update everything now: HomelabHero + OS (operator)
    hh login                     log Claude Code in as the agent user
    hh audit [lines]             review the broker audit log (operator)
    hh version                   print the version and a link to the changelog

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
narrow sudoers rule (`hhagent` may run only that broker, its read-only router
siblings `hh-unifi` and `hh-firewalla`, and `hh-provision`, and only as
`hhvault`).
The broker looks the host up in the non-secret registry, reads the key or password
from the vault, and opens the connection. Claude gets the output, never the secret.
A router credential works the same way: `hh-unifi` and `hh-firewalla` read the
UniFi API key or the Firewalla MSP token from the vault and pass it to curl
through a config file on stdin, never on the command line, so it never appears
in `/proc` where the agent user could read it.
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
- Live inventory via `hh inventory`: Proxmox VMs and LXCs, TrueNAS VMs, LXCs,
  apps and pools, and Docker containers wherever they run. `hh inventory --save`
  snapshots into `ops/inventory/` so state changes show up in git over time.
- Environment-specific notes about your setup in `ops/infra/`.

## Discovery (point and click)

`hh scan` sweeps your subnet (auto-detected, or pass a CIDR) for live management
endpoints and guesses what each is (Proxmox on 8006, SSH on 22, and so on), marking
which are already registered. `hh scan --add` turns that into a picker: choose the
numbers you want and it walks you through registering each, pre-filling the address
and platform.

It also looks for your **router**. Anything sitting at your default gateway or at
the `.1` of the subnet (`192.168.1.1`, `10.99.0.1`, and so on) gets fingerprinted,
and a UniFi console is identified by name and version:

    #    IP               OPEN PORTS           GUESS            ROLE      REGISTERED?
    1    10.99.0.1        22,80,443            unifi            gateway   new
    2    10.99.0.20       22,443               truenas?/linux   -         registered

    Found your router: a UniFi OS console running Network 9.0.114 at 10.99.0.1

Pick it during install (step 10) or any time after, and it registers with an API
key instead of SSH. This is the router integration below.

## Your UniFi router (read-only, on purpose)

A UniFi console (UDM, UCG, Cloud Key Gen2+, UniFi OS Server, on Network 9.0 or
newer) can be registered alongside your servers. It shows up in `hh list` like
anything else, and `hh overview` and `hh inventory` include it:

    Console   10.99.0.1   Network 9.0.114
    WAN       ok      ip 203.0.113.7   gateway UCG-Ultra 4.2.14   isp Example ISP
    Internet  ok      latency 12 ms   down/up 940.5/88.2 Mbps   uptime 1209600s
    LAN       ok      41 clients, 2 switches, 3 adopted, 0 offline
    WiFi      ok      38 clients, 2 APs, 2 adopted, 0 offline
    Devices   5 adopted, 5 online
    Updates   firmware available for 1 device: Office AP
    Clients   43 connected

That means "the internet is down", "which access point is offline", "is that
machine actually on the network", and "what VLAN is it on" become questions
Claude can answer from the gateway itself, instead of inferring from the hosts.

**It can only read. It cannot change anything on your network.** That is enforced
in three independent places, not just asked for in a prompt:

1. The broker behind `hh unifi` issues HTTP `GET` and has no code path that can
   `POST`, `PUT`, `PATCH`, or `DELETE`. There is no restart, no reboot, no
   firewall, VLAN, SSID, or port-forward edit, because none of it is implemented.
2. You mint the API key under a **View Only** UniFi admin, so the console itself
   refuses writes from that key regardless of what asks.
3. The ops brain and the `unifi-ops` skill tell Claude the rule plainly, and tell
   it what to do instead: explain the change you should make in the UniFi app,
   then read the state back to confirm it worked.

The router is the one device whose failure takes away the access you would need
to fix it. A bad firewall rule or an ill-timed reboot can cut off every host, the
command center, and you, all at once. Reading it is enormously useful; letting an
agent write to it is not worth that.

Register it from an admin shell (an API key is a secret being typed, so it stays
out of the chat, exactly like password auth):

    hh add-unifi

It walks you through creating the key in the UniFi app, stores it in the vault
where the agent cannot read it, and pins the console's TLS public key on first
contact (trust on first use, like SSH). If you later replace the console's
certificate, `hh repin <alias>` accepts the new one; until you do, calls fail
closed rather than quietly trusting a new identity.

## Your Firewalla (read-only, on purpose)

A Firewalla (Gold, Gold SE, Gold Plus, Purple, Blue Plus) can be registered the
same way. It shows up in `hh list` like anything else, and `hh overview` and
`hh inventory` include it:

    MSP       yourname.firewalla.net
    Box       Home Firewalla (gold, router mode, v1.975)   online   public IP 203.0.113.7
    Counts    41 devices, 34 rules, 6 alarms
    Devices   41 known, 39 online
    Offline   2: Office Printer, Garage Camera
    Alarms    3 most recent active:
              08-19 21:04  Abnormal upload from Desktop-PC

So "is that machine actually on the network", "what is eating my internet", "why
can't this reach that", and "anything alarming overnight" become questions Claude
answers from the router itself.

One difference from UniFi worth knowing: Firewalla ships no supported local API,
so this reads Firewalla MSP - Firewalla's own management portal - over the
internet, at `https://<yourname>.firewalla.net`. You need an MSP account, and
when your internet is down this is down with it, so it is a poor first probe for
"is the internet up" and a good one for everything else.

**It can only read. It cannot change anything on your network.** Note that here
that rests on *one* lock rather than UniFi's two:

1. The broker behind `hh firewalla` issues HTTP `GET` and has no code path that
   can `POST`, `PUT`, `PATCH`, or `DELETE`. No pause, no unpause, no rule edit,
   no rename, no reboot, because none of it is implemented.
2. There is no second lock, and the setup says so out loud. Firewalla MSP has no
   read-only token: a personal access token carries the permissions of the
   account that made it. The GET-only broker is the only thing making that token
   safe to hold, which is why it is worth reading `bin/hh-firewalla` before you
   trust it, and why the token is stored where the agent cannot read it.
3. The ops brain and the `firewalla-ops` skill tell Claude the rule plainly, and
   tell it what to do instead: explain the change you should make in the
   Firewalla app or MSP, then read the state back to confirm it worked.

If you would rather not hold an MSP token at all, that is a legitimate choice.
Skip this and keep reading your Firewalla in its own app; everything else in
HomelabHero works without it.

Register it from an admin shell (a token is a secret being typed, so it stays out
of the chat, exactly like password auth):

    hh add-firewalla

It asks for your MSP domain - `yourname.firewalla.net`, not the box's LAN address
- and the token, which it stores in the vault where the agent cannot read it.
There is no TLS pin here, unlike UniFi: an MSP domain has a publicly trusted
certificate, so ordinary CA verification already applies and is the stronger
check.

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

One command does everything. A weekly cron job (`/etc/cron.d/homelabhero`, Sundays at
04:00) runs `hh update`, logging to `/var/log/homelabhero-update.log`. Edit that one
file to change the schedule, or delete it to turn auto-update off. Run it any time with
`hh update`.

`hh update` does three things in order:

1. **Update HomelabHero itself** (see below).
2. **Update the OS packages** (`apt`).
3. **Run a health check** (`hh doctor`).

### Staying up to date with HomelabHero itself

For step 1, `hh update` `git pull`s the branch you installed from (`main` unless you
changed it) and **re-runs the installer non-interactively** - so an update produces
exactly what a fresh install does:
the `hh` CLI and broker, the shipped skills / `CLAUDE.md` / capability docs, Node and
npm at the latest LTS, the Claude Code + claudecodeui packages (reinstalled with the
correct `--allow-scripts` set so their native modules always build), and the systemd
unit. Improvements and fixes pushed to the repo reach existing boxes on their own;
nobody has to re-run the installer by hand.

Because it re-runs the real installer, there is no "some changes only the installer can
apply" gap - `hh update` **is** the installer, plus the OS pass. Node tracks the latest
LTS automatically each week.

What it will and will not touch is deliberate:

- **Refreshed** (HomelabHero-owned): the CLI binaries, `.claude/skills/`,
  `.claude/settings.json`, `CLAUDE.md`, `capabilities/`, the logrotate/sudoers/service
  templates, and the Node/npm stack. An in-place edit to one of these *shipped* files
  will be overwritten - customize instead by adding your own skill, using
  `settings.local.json`, or filling in the notes below.
- **Never touched** (yours): your environment notes under `infra/`, `inventory/`,
  `runbooks/`, `hosts/`, your edited cron schedule, and `cloudcli.env`. Your own
  custom skills in `.claude/skills/` are preserved too. Ops-brain changes land in the
  working tree, so `git -C ~hhagent/homelab-ops diff` shows exactly what an update
  changed.

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
    │   ├── hh-connect             privileged SSH broker (runs as hhvault)
    │   ├── hh-unifi               read-only UniFi API broker (runs as hhvault)
    │   ├── hh-firewalla           read-only Firewalla MSP broker (runs as hhvault)
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
