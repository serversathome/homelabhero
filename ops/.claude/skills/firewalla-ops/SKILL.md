---
name: firewalla-ops
description: >
  Read and analyze the Firewalla router through the MSP API: box and firmware
  state, devices on the network and which are offline, active alarms, traffic
  flows and top bandwidth consumers, rules and target lists. Use this whenever
  the user asks about the Firewalla, the router, the gateway, what is connected to
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

**One alias means one box.** An MSP token sees the whole account, so each alias
is pinned to a single Firewalla at registration and every read is filtered to it.
If the user has boxes at two sites, they are two aliases, and you must name which
one you mean: `hh firewalla devices cabin`. `hh firewalla boxes` lists every box
the token can see and marks the one an alias reads. Three ops are account-wide
on purpose - `boxes`, `ping`, and `stats` - and `trends` is account-wide for a
different reason (see below).

If a per-box op refuses because an alias is not pinned, that refusal is correct
and is not something to work around with the raw `get` escape hatch. Answering
from the wrong site looks exactly like answering from the right one. Tell the user
to re-register the alias (`hh rm-host <alias> && hh add-firewalla`, which asks
which box) rather than reaching around it.

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
  planning any of that, stop. The answer is to tell the user what to change, not to
  change it.
- If the user asks you to change a Firewalla setting, do not refuse flatly and do
  not quietly do nothing. Say that HomelabHero's Firewalla access is read-only
  on purpose, then give him the exact steps to do it himself in the Firewalla
  app or in MSP: which screen, which setting, which value, and what he should
  expect to see afterwards. Offer to read the state back once he has done it
  and confirm it took effect. That is the whole workflow, and it is a good one.

Why it is built this way: the router is the one device whose failure takes away
the access you would need to fix it. A bad rule, a paused allow, or an
ill-timed reboot can cut off every host, the command center, and the user's own way
in, all at once, with no way back except physically standing in front of the
hardware. Nothing an agent could usefully automate here is worth that risk.

## What you can read

    hh firewalla summary        the one-screen picture: box, firmware, public IP,
                                device counts, who is offline, recent alarms
    hh firewalla boxes          every Firewalla the token can see, marking which
                                one this alias reads
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

    hh firewalla get '/v2/alarms' 'query=box.id:{gid} type:8 status:active' 'limit=50'
    hh firewalla get '/v2/flows' 'query=box.id:{gid} device.name:*iphone* total:>50MB'
    hh firewalla get '/v2/rules' 'query=box.id:{gid} status:paused action:allow'

`{gid}` expands to the box this alias is pinned to. Always include it. A raw
query without it reads the whole MSP account, which on a multi-box account
quietly mixes in another site - the named ops all scope themselves, and an
ad-hoc query has to do the same.

The query syntax and the full qualifier list are in
`capabilities/firewalla.md`.

## Trends: read the scope line before quoting a number

`hh firewalla trends` filters by MSP group rather than by box, and resolves the
pinned box's group automatically, so it is usually already per-box. It prints
what it covers on the first line, every time:

    Daily flows, covering box group Home Site, which holds only this box.
    Daily flows, covering box group Sites, which holds 3 boxes including this one.
    Daily flows, covering the whole MSP account - this box is in no MSP group.

Read that line and repeat its scope when you report the numbers. A group with
three boxes in it is not "your Firewalla", and an account-wide total is not
either. If the box is in no group, the numbers are account-wide and the fix is
the user's: put the box in an MSP group of its own, after which this command
finds the group on its own.

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
  alarming the user.
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

Pair it with `netbird-ops` for the mesh, `cloudflare-ops` for ingress, and
`network-diag` for DNS resolution inside a host and per-host interfaces.
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
