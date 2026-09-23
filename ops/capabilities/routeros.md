# MikroTik RouterOS - capability catalog

For a MikroTik switch or router registered as platform `routeros` and reached
via `hh run <alias> "..."`. RouterOS takes SSH but is NOT a POSIX shell: no
`echo`, `grep`, pipes, `sudo` or `&&`. Use its own CLI - paths start with `/`,
commands are separated with `;`, and `:put` prints. Read side first; writes need
confirmation.

## Before you change anything

A switch like this often carries storage traffic and cluster heartbeat for every
hypervisor, and sometimes the path this box uses to reach it. A wrong VLAN or
bridge change can cut off the hosts AND your way back in, which is the same
reason UniFi and Firewalla are read-only here. Nothing in the broker fences
RouterOS writes: `hh run` is the "fenced only by convention" tier, so the
"(confirm)" marks below are instructions to you, not enforcement.

- Say exactly what you are about to run and what it could disconnect.
- Prefer changes on ports that do not carry this box's own traffic, and check
  that with the FDB (`/interface bridge host print`) first.
- Changes apply the moment they run. RouterOS safe-mode (Ctrl-X) only works in
  an interactive session, so it does NOT protect `hh run`. For anything risky,
  give the user the commands to run themselves from WinBox or a terminal with
  safe-mode on.
- `hh doctor` shows the login's `/user` group. A `read` group means the device
  refuses writes, whatever you run.

## Identity, health and resources

- Name / version / board: `/system identity print`, `/system resource print`,
  `/system routerboard print`
- CPU, memory, free flash, uptime: `/system resource print`
- Per-core load: `/system resource cpu print`
- Temperature, fans, PSU (model dependent, may be empty): `/system health print`
- Clock: `/system clock print`
- Packages and update channel: `/system package print`,
  `/system package update print`

## Interfaces and links

- All interfaces with running/disabled flags: `/interface print`
- Only enabled ports with no link: `/interface print where !running and !disabled`
- Ethernet settings (speed, auto-negotiation, MTU, L2 MTU): `/interface ethernet print detail`
- Negotiated rate, and SFP/QSFP optics and DOM (temperature, TX/RX power):
  `/interface ethernet monitor <port> once`
- Traffic and error counters: `/interface print stats`,
  `/interface ethernet print stats`
- Enable/disable a port (confirm): `/interface ethernet enable <port>`,
  `/interface ethernet disable <port>`
- Comment a port (confirm, harmless): `/interface ethernet set <port> comment="..."`

## Bridge, VLANs and the MAC table

- Bridges and whether VLAN filtering is on: `/interface bridge print detail`
- Port membership, pvid, frame types: `/interface bridge port print detail`
- VLAN table (tagged/untagged per VLAN): `/interface bridge vlan print`
- FDB, i.e. which MAC is on which port: `/interface bridge host print`
- VLAN interfaces (routed/L3): `/interface vlan print`
- Change membership, pvid or frame types (confirm - can cut hosts off):
  `/interface bridge port set ...`, `/interface bridge vlan set ...`
- Turning VLAN filtering on or off (confirm - high risk): `/interface bridge set <bridge> vlan-filtering=...`

## IP, routing and services

- Addresses and routes: `/ip address print`, `/ip route print`
- ARP / neighbours: `/ip arp print`, `/ip neighbor print`
- DNS: `/ip dns print`
- Enabled management services and their ports: `/ip service print`
- SNMP: `/snmp print`, `/snmp community print`
- Firewall (if routing): `/ip firewall filter print`, `/ip firewall nat print`

## Users and access

- Users and their groups: `/user print`
- Groups and what they allow: `/user group print`
- SSH keys per user: `/user ssh-keys print`
- Active sessions: `/user active print`

Authorizing HomelabHero's key: RouterOS keeps keys per user, so `ssh-copy-id`
does not work. Upload the public key to the device (WinBox/WebFig Files, or
scp), then `/user ssh-keys import public-key-file=<file> user=<user>`.

## Logs and diagnostics

- Recent log: `/log print`, or filter `/log print where topics~"interface"`
- Ping / traceroute from the switch: `/ping <ip> count=3`, `/tool traceroute <ip>`
- Configuration as a script (read-only, useful for review): `/export terse`
  (`/export` hides secrets by default; do not add `show-sensitive`)

## Destructive - never without an explicit, specific request

- `/system reboot`, `/system shutdown`
- `/system reset-configuration`
- `/system package downgrade`, firmware upgrades
- Removing bridges, bridge ports or VLAN entries in bulk

## What RouterOS cannot tell you

The switch knows links, MACs and VLANs. It does not know which host or service a
MAC belongs to (match it against `hh inventory` and the hosts' `ip -br link`),
whether storage paths are healthy end to end (check multipath and NVMe/TCP on
the hosts), or anything about the NetBird mesh or Cloudflare. A port can be up
at full rate here and the traffic over it still be broken higher up.
