# Command reference

Every `hh` subcommand. The per-integration ops have their own pages under
[integrations](integrations/) - this is the top level.

[← back to the README](../README.md)

## The commands


    hh list                      registered hosts (no secrets)
    hh run <alias> "<command>"   run a command on a host via the broker
    hh test <alias>              connectivity check
    hh overview                  read-only vitals sweep across all hosts
    hh inventory [alias]         what is RUNNING (VMs, LXCs, containers, apps)
    hh diff [alias]              inventory drift vs the last saved snapshot
    hh scan [cidr]               discover live hosts (and your router) on the network
    hh unifi <op> [alias]        read your UniFi router: summary, health, devices,
                                 clients, networks (READ-ONLY)
    hh firewalla <op> [alias]    read your Firewalla: summary, devices, alarms,
                                 flows, bandwidth, rules (READ-ONLY)
    hh netbird <op> [alias]      read and manage your NetBird mesh: peers, groups,
                                 policies, routers, DNS, keys
    hh cloudflare <op> [alias]   read and manage Cloudflare: DNS records, tunnels,
                                 Access apps
    hh doctor                    check the whole setup is healthy
    hh provision <alias> <host> [port] [platform] [user]
                                 register a host with a generated key (UI-safe);
                                 connects as root by default (pass a user to override)

    hh add-host                  register a host (operator)
    hh add-unifi                 register your UniFi router with an API key (operator)
    hh add-firewalla             register your Firewalla with an MSP token (operator)
    hh add-netbird               register your NetBird mesh with a service-user token (operator)
    hh add-cloudflare            register Cloudflare with a scoped API token (operator)
    hh repin <alias>             re-pin a UniFi console or self-hosted NetBird server
                                 after its cert changed (operator)
    hh rm-host <alias>           remove a host and its credential
    hh update                    update everything now: HomelabHero + OS (operator)
    hh login                     log Claude Code in as the agent user
    hh audit [lines]             review the broker audit log (operator)
    hh version                   print the version and a link to the changelog

## Per-integration operations

The four API integrations each have their own set of ops, and their own page:

- [UniFi](integrations/unifi.md) - read-only
- [Firewalla](integrations/firewalla.md) - read-only
- [NetBird](integrations/netbird.md) - reads, and writes with an Admin token
- [Cloudflare](integrations/cloudflare.md) - reads, and writes with an Edit token

`hh netbird` and `hh cloudflare` will list their own ops if you run them with no
arguments, and both refuse destructive operations without `--force`.
