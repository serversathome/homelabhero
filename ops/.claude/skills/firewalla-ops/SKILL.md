---
name: firewalla-ops
description: >
  Read and analyze the Firewalla router through the MSP API: box and firmware
  state, devices on the network and which are offline, active alarms, traffic
  flows and top bandwidth consumers, rules and target lists. Use this whenever
  Evan asks about the Firewalla, the router, the gateway, what is connected to
  the network, who is using bandwidth, whether a device is online, a security
  alarm, a block rule, or whether something is being blocked, and whenever a
  problem might be upstream of a host rather than on it ("is my printer on the
  network", "what is eating my internet", "why can't this reach that",
  "anything alarming overnight"). This is READ-ONLY: it can report and explain
  and recommend, but it cannot change any Firewalla setting, and it must never
  claim otherwise.
---

# Firewalla router (read-only)

The Firewalla is registered like any other host, but it is reached over
Firewalla's MSP API instead of SSH, so `hh run` does not apply to it.
Everything goes through one command:

    hh firewalla <op> [alias] [args]

The alias can be omitted when only one Firewalla is registered, which is the
normal case. `hh list` shows it with platform `firewalla` and auth `token`.

## THIS IS READ-ONLY. DO NOT TRY TO CHANGE THE NETWORK.

Say it plainly to yourself before every Firewalla task: **you can look, you
cannot touch.** This is not a preference or a default that a good enough reason
can override. It is the point of the integration.

- There is **no** command here that changes anything. No pause, no unpause, no
  block, no unblock, no rule edit, no device rename, no reboot, no config write
  of any kind. The broker behind `hh firewalla` issues HTTP GET and physically
  cannot issue anything else.
- **Firewalla has no second lock, so this one carries all the weight.** On
  UniFi the API key is minted under a View Only admin, so the console refuses
  writes even if something got past the broker. Firewalla MSP has no read-only
  token: the token in the vault carries the account's full permissions. The
  GET-only broker is the only thing standing between that token and a network
  change. Treat it accordingly.
- Do not try to route around it. Do not look for another path to the router:
  not SSH to the box, not the Firewalla app, not `curl` against the MSP API
  yourself, not a script that "just" pauses one rule. If you catch yourself
  planning any of that, stop. The answer is to tell Evan what to change, not to
  change it.
- If Evan asks you to change a Firewalla setting, do not refuse flatly and do
  not quietly do nothing. Say that HomelabHero's Firewalla access is read-only
  on purpose, then give him the exact steps to do it himself in the Firewalla
  app or in MSP: which screen, which setting, which value, and what he should
  expect to see afterwards. Offer to read the state back once he has done it
  and confirm it took effect. That is the whole workflow, and it is a good one.

Why it is built this way: the router is the one device whose failure takes away
the access you would need to fix it. A bad rule, a paused allow, or an
ill-timed reboot can cut off every host, the command center, and Evan's own way
in, all at once, with no way back except physically standing in front of the
hardware. Nothing an agent could usefully automate here is worth that risk.

## What you can read

    hh firewalla summary        the one-screen picture: box, firmware, public IP,
                                device counts, who is offline, recent alarms
    hh firewalla boxes          every Firewalla in the MSP account
    hh firewalla devices        every known device: IP, MAC, state, network, group
    hh firewalla device <q>     one device in full, by MAC or by name substring
    hh firewalla alarms [n]     active alarms, newest first (default 20)
    hh firewalla flows [n]      recent traffic, blocked flows marked BLOCKED
    hh firewalla bandwidth [n]  top talkers over the last 24 hours
    hh firewalla rules          every rule: action, status, target, scope
    hh firewalla lists          target lists (the IP/domain sets rules use)
    hh firewalla trends <what>  daily counts of flows, alarms, or rules
    hh firewalla stats <type>   MSP-wide statistics
    hh firewalla info           raw box JSON
    hh firewalla ping           connectivity check

Start with `summary`. It answers most questions on its own, and it tells you
whether to go deeper into devices, alarms, or traffic.

For anything the named ops do not cover, there is a raw GET escape hatch. It is
still read-only, and query parameters are URL-encoded for you:

    hh firewalla get '/v2/alarms' 'query=type:8 status:active' 'limit=50'
    hh firewalla get '/v2/flows' 'query=device.name:*iphone* total:>50MB'
    hh firewalla get '/v2/rules' 'query=status:paused action:allow'

The query syntax and the full qualifier list are in
`capabilities/firewalla.md`.

## One thing to know before you use this in an outage

This reads Firewalla's cloud (MSP), not the box on the LAN. If the internet is
down, `hh firewalla` is down with it. So a failure here is NOT evidence that
the router is broken - it is just as likely to be the WAN, which is the thing
you were probably trying to diagnose. Say which of the two you have actually
established, and never report the router as down on the strength of a broker
timeout alone.

## Reading the output

- **Offline devices** in `summary` and `devices` are the single most useful
  signal. If a host is unreachable and Firewalla also lists it offline, the
  problem is at or below the network layer and there is no point troubleshooting
  the service on it.
- **Alarms** describe something that already happened. "Abnormal upload" or
  "large bandwidth usage" on a known device is usually a backup or a sync, not
  an intrusion; check `bandwidth` and the device's normal behaviour before
  alarming Evan.
- **Blocked flows** in `flows` explain a surprising number of "app cannot reach
  X" reports. Cross-check with `rules` and `lists`: a target list entry or a
  category block is a far more common cause than the app being broken.
- **Bandwidth** is the answer to "the internet is slow" nine times out of ten.
  Get the top talkers first, before probing any host.

## How this fits the rest of the ladder

The escalation ladder in `CLAUDE.md` ends at the network layer, and this is the
top of it. When several unrelated things are broken at once, check here early:
one offline switch port or one over-broad block rule explains a lot of symptoms,
and it takes one command to rule in or out.

Pair it with `network-diag` for the parts Firewalla cannot see: the NetBird
mesh, DNS resolution inside a host, Cloudflare tunnels, and per-host interfaces.
Firewalla tells you about the devices and the traffic; `network-diag` tells you
about the overlay and the hosts on it.

Useful pairing in practice:

1. `hh firewalla summary` to see whether the network looks healthy at all.
2. `hh firewalla devices` to find anything offline.
3. `hh firewalla bandwidth` if the complaint is about speed.
4. `hh firewalla flows` and `hh firewalla rules` if something specific cannot
   reach something else.
5. Then `hh test <alias>` and the `network-diag` skill for the hosts themselves.

## Recording what you learn

The topology notes in `infra/network.md` are the place for anything durable you
discover here: subnets and networks, which devices are expected to be offline,
the normal device count, what the traffic profile usually looks like, which
rules exist and why. Reading the live MSP is how you learn it; writing it down
is how it stays learned. When an incident is resolved, the runbook entry belongs
in `runbooks/` as usual.
