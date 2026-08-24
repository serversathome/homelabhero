---
name: unifi-ops
description: >
  Read and analyze the UniFi router/console: WAN and internet health, adopted
  access points and switches, connected clients, VLANs and networks, firmware
  status. Use this whenever the user asks about the router, the gateway, the
  internet connection, WiFi, an access point, a UniFi switch, what is connected
  to the network, who is using bandwidth, a VLAN, or the ISP, and whenever a
  problem might be upstream of a host rather than on it ("the internet is
  down", "wifi is slow", "is my WAN up", "did the router reboot"). This is
  READ-ONLY: it can report and explain and recommend, but it cannot change any
  UniFi setting, and it must never claim otherwise.
---

# UniFi router (read-only)

The UniFi console is registered like any other host, but it is reached over its
local API instead of SSH, so `hh run` does not apply to it. Everything goes
through one command:

    hh unifi <op> [alias] [args]

The alias can be omitted when only one console is registered, which is the
normal case. `hh list` shows it with platform `unifi` and auth `apikey`.

## THIS IS READ-ONLY. DO NOT TRY TO CHANGE THE NETWORK.

Say it plainly to yourself before every UniFi task: **you can look, you cannot
touch.** This is not a preference or a default that a good enough reason can
override. It is the point of the integration.

- There is **no** command here that changes anything. No restart, no reboot, no
  adopt, no firmware upgrade, no port or VLAN or SSID or firewall edit, no
  client block, no config write of any kind. The broker behind `hh unifi`
  issues HTTP GET and physically cannot issue anything else.
- The API key is minted under a **View Only** UniFi admin, so the console
  refuses writes even if something got past the broker.
- Do not try to route around this. Do not look for another path to the router:
  not SSH to the gateway, not the UniFi mobile app, not `curl` against the API
  yourself, not a script that "just" restarts one access point. If you catch
  yourself planning any of that, stop. The answer is to tell the user what to
  change, not to change it.
- If the user asks you to change a UniFi setting, do not refuse flatly and do not
  quietly do nothing. Say that HomelabHero's UniFi access is read-only on
  purpose, then give him the exact steps to do it himself in the UniFi app:
  which screen, which setting, which value, and what he should expect to see
  afterwards. Offer to re-read the state once he has done it and confirm it
  took effect. That is the whole workflow, and it is a good one.

Why it is built this way: the router is the one device whose failure takes away
the access you would need to fix it. A bad firewall rule, a mistaken VLAN
change, or an ill-timed reboot can cut off every host, the command center, and
your own way in, all at once, with no way back except physically standing in
front of the hardware. Nothing an agent could usefully automate here is worth
that risk. So the router is treated as a source of truth to read and reason
about, and changes stay with the person.

## What you can read

    hh unifi summary          the one-screen picture: WAN, internet, LAN, WiFi,
                              device counts, pending firmware, client count
    hh unifi health           WAN / internet / LAN / WiFi subsystem status
    hh unifi devices          adopted gear: name, model, state, IP, firmware
    hh unifi clients          connected clients: name, IP, MAC, type
    hh unifi networks         configured networks and VLANs
    hh unifi info             console and Network application version
    hh unifi sites            sites on the console (usually just one)
    hh unifi device <id>      full JSON for one device
    hh unifi stats <id>       latest statistics for one device
    hh unifi ping             connectivity check

Start with `summary`. It answers most questions on its own, and it tells you
whether to go deeper into devices, clients, or health.

For anything the named ops do not cover, there is a raw GET escape hatch. It is
still read-only, and `{site}` / `{siteName}` are substituted for you:

    hh unifi get '/proxy/network/integration/v1/sites/{site}/firewall/policies'
    hh unifi get '/proxy/network/api/s/{siteName}/stat/event?_limit=20'
    hh unifi get '/proxy/network/api/s/{siteName}/rest/portforward'
    hh unifi get '/proxy/network/api/s/{siteName}/rest/wlanconf'

Two APIs sit under `/proxy/network/`: the documented integration API at
`/integration/v1/...`, and the older private API at `/api/s/{siteName}/...`
which still holds things the new one has no equivalent for. Prefer the former;
reach for the latter when it is the only source.

## Reading the output

`summary` and `health` report four subsystems. What each one failing means:

- **WAN** not ok: the internet link itself. Check `wan_ip` is present and
  plausible. No IP means the connection to the ISP is down, which is upstream
  of everything and not something in the homelab to fix.
- **Internet (www)** not ok: the link is up but quality is poor. Latency and
  throughput numbers are in the same line; compare them against what the user pays
  for before calling it a fault.
- **LAN** not ok: usually a switch offline or a port down. Cross-check with
  `hh unifi devices` for anything not `ONLINE`.
- **WiFi (wlan)** not ok: an access point is offline or disconnected. Again,
  `devices` names which one.

An `OFFLINE` device in `devices` is the single most useful signal here. If a
host is unreachable and the access point or switch it hangs off is offline, the
network is the cause and there is no point troubleshooting the host.

## How this fits the rest of the ladder

The escalation ladder in `CLAUDE.md` ends at the network layer, and this is the
top of it. When several unrelated things are broken at once, check here early:
one offline switch explains a dozen unreachable services, and it takes one
command to rule in or out.

Pair it with `network-diag` for the parts UniFi cannot see: the NetBird mesh,
DNS resolution, Cloudflare tunnels, and per-host interfaces. UniFi tells you
about the fabric and the gear; `network-diag` tells you about the overlay and
the hosts on it.

Useful pairing in practice:

1. `hh unifi summary` to see whether the fabric is healthy at all.
2. `hh unifi devices` to find anything offline.
3. `hh unifi clients` to confirm a specific machine is actually on the network,
   and on which network or VLAN.
4. Then `hh test <alias>` and the `network-diag` skill for the hosts
   themselves.

## Recording what you learn

The topology notes in `infra/network.md` are the place for anything durable you
discover here: subnets and VLANs, which access point covers which area, the
normal client count, what the internet numbers usually look like. Reading the
live console is how you learn it; writing it down is how it stays learned. When
an incident is resolved, the runbook entry belongs in `runbooks/` as usual.
