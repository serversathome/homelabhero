# HomelabHero documentation

[← back to the README](../README.md)

| | |
|---|---|
| [Installing and adding machines](install.md) | first install, discovery, registering hosts |
| [Command reference](commands.md) | every `hh` subcommand |
| [The security model](security.md) | credential isolation, what the agent knows, how strongly each integration is fenced |
| [Updating and health](updating.md) | `hh update`, the weekly job, `hh doctor` |
| [Layout, platforms, persistence](layout.md) | where things live, per-platform notes, what to back up |

## Integrations

Each is reached over its own API rather than a shell, so `hh run` does not apply
to any of them.

| | |
|---|---|
| [UniFi](integrations/unifi.md) | WAN and internet health, APs, switches, clients, VLANs. Read-only by construction. |
| [Firewalla](integrations/firewalla.md) | devices, alarms, flows, bandwidth, rules. Read-only by construction. |
| [NetBird](integrations/netbird.md) | mesh peers, groups, policies, routes, BYOP services. Can write with an Admin token. |
| [Cloudflare](integrations/cloudflare.md) | DNS, tunnels and their ingress, Access apps. Can write with an Edit token. |

Elsewhere in the repository: [CHANGELOG](../CHANGELOG.md) for what changed per
release, and [SECURITY](../SECURITY.md) for reporting a vulnerability.
