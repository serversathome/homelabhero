# Firewalla - capability catalog

For a Firewalla (Gold, Gold SE, Gold Plus, Purple, Blue Plus, Purple SE)
registered with a Firewalla MSP personal access token. Everything runs through
`hh firewalla <op> [alias]`. `hh run` does NOT apply here: the Firewalla is
reached over the MSP API, not SSH.

## Where this reads from

Firewalla ships no supported local API on the box, so HomelabHero reads it
through Firewalla MSP - Firewalla's own management portal - at
`https://<yourname>.firewalla.net/v2/...`. That means:

- Reads go out to the internet and back. If the internet is down, this is one
  of the things that stops working, which makes `hh firewalla` a poor first
  probe for "is my internet down" and a good one for everything else.

## One alias means one box

An MSP token is scoped to an ACCOUNT, not to a box, so the API will happily
answer for every Firewalla the account can see. A registered alias means one
box, so it is pinned to one at registration (`GID=` in the registry entry) and
every per-box op filters on it. On an account with one box that pin is resolved
silently and nothing about this is visible.

Three ops are account-wide on purpose, and say so:

- `boxes` - every box the token can see, which is how you find the others. The
  last column marks the one this alias reads.
- `ping` - a connectivity check, which must stay answerable before a pin exists.
- `stats` - every supported type ranks boxes or regions against each other, so
  there would be nothing to rank within one box.

If an alias is somehow NOT pinned and the account has more than one box, the
per-box ops refuse rather than guess. That refusal is the correct answer, not a
fault to work around: a plausible-looking table from the wrong site is worse
than no table. Register each box as its own alias (`hh add-firewalla`, once per
box, same token), and use `hh firewalla <op> <alias>` to say which you mean.

Trends are the exception to all of this: see below.

## Read-only, with no exceptions - and it matters more here

Every capability below reads. There is no write capability, not because none
was documented but because none exists: the broker issues HTTP GET and has no
code path that can POST, PUT, PATCH, or DELETE.

UniFi has a second lock that Firewalla does not. A UniFi API key is minted
under a View Only admin, so the console refuses writes on its own. Firewalla
MSP has no read-only token scope: a personal access token carries the
permissions of the account that created it, and the same token that reads
devices could pause a rule or rename a device. The GET-only broker is therefore
the only thing making that token safe to hold, which is exactly why nothing
here should ever route around it - not `curl` against the API directly, not a
helper script, not "just this once".

So there is nothing to "confirm before running" in this catalog, and nothing
here can change the network. What there IS to do, when a change is needed, is
tell the user exactly what to change in the Firewalla app or in MSP, and then
verify the result by reading it back. See the firewalla-ops skill.

## Overall state

- One-screen picture: `hh firewalla summary`
- Every box the token can see, with model, mode, firmware, public IP, counts,
  and which one this alias reads: `hh firewalla boxes`
- Raw box JSON: `hh firewalla info`
- Reachability check: `hh firewalla ping`

## Devices

- Every known device with IP, MAC, state, network, group, totals:
  `hh firewalla devices` (offline first, which is what you usually came for)
- One device in full: `hh firewalla device <mac-or-name>` - the name match is a
  case-insensitive substring, so `device printer` works without the MAC.

What to look for: anything OFFLINE that should not be, and a device on a
network or group you did not expect. Firewalla counts a VPN client as a device
too, so an absent road-warrior peer shows up here.

## Alarms

- Active alarms, newest first: `hh firewalla alarms [n]` (default 20)

Alarms are Firewalla's core signal: new device joined, abnormal upload, large
bandwidth usage, security activity, port scan. An alarm is a statement about
something that already happened, so treat it as evidence to explain rather than
a fault to fix.

## Traffic

- Recent flows: `hh firewalla flows [n]` (default 20) - device, direction,
  destination, category, bytes. Blocked flows show as `BLOCKED`.
- Top talkers over the last 24 hours: `hh firewalla bandwidth [n]` (default 10)

`bandwidth` answers "what is eating the internet" in one call and is almost
always the right place to start on a slowness complaint.

## Rules and target lists

- All rules with action, status, target, and scope: `hh firewalla rules`
- Target lists (the IP/domain sets rules are built from): `hh firewalla lists`

Useful when a service cannot reach something: a block rule or a target list
entry explains it far more often than the service does.

## Trends and statistics

- Daily counts over time: `hh firewalla trends <flows|alarms|rules>`
- MSP-wide statistics: `hh firewalla stats <topBoxesByBlockedFlows |
  topBoxesBySecurityAlarms | topRegionsByBlockedFlows>`

`trends` cannot be narrowed by the box pin directly, because the endpoint filters
by MSP GROUP rather than by box. It resolves that itself: if the pinned box
belongs to a group, the group is passed automatically, which makes the numbers
per-box whenever that group holds only this box - the common arrangement.

Every run states what it actually covers, and that line is the thing to read
before quoting a number:

    Daily flows, covering box group Home Site, which holds only this box.
    Daily flows, covering box group Sites, which holds 3 boxes including this one.
    Daily flows, covering the whole MSP account - this box is in no MSP group.

A group holding several boxes is NOT this box, however convenient that would be
to report, so the count is named. If the box is in no group, the read is
account-wide and the output says to put it in a group of its own to get per-box
figures - after which this command picks the group up on its own, with no id to
pass by hand. Per-box numbers obtained this way sum back to the account-wide
total, so the two views stay consistent.

## Anything else (raw GET)

The named ops cover the common ground. For the rest, a read-only escape hatch
takes any path under `/v2/`, plus optional `name=value` query parameters which
are URL-encoded for you (the MSP API requires that):

    hh firewalla get '/v2/devices' 'box={gid}'
    hh firewalla get '/v2/alarms' 'query=box.id:{gid} type:8 status:active' 'limit=50'
    hh firewalla get '/v2/flows' 'query=box.id:{gid} device.name:*iphone* total:>50MB'
    hh firewalla get '/v2/rules' 'query=box.id:{gid} status:paused action:allow'
    hh firewalla get '/v2/target-lists' 'owner=global,firewalla,{gid}'

`{gid}` is substituted with the box this alias is pinned to, in the path and in
any query value. Use it: a raw query without it is account-wide, which is the
one thing the named ops exist to avoid.

Target lists are the exception to that pattern, because they have owners rather
than a box filter, and there are THREE owner categories: `global` (lists the MSP
account defines), `firewalla` (the curated lists Firewalla ships - OISD, DoH
Services, Tor Exit Nodes), and a box gid. Naming only two of them does not
narrow the result, it DROPS the third, so an account whose lists are all
built-ins comes back empty. Name all three.

The query syntax is Firewalla's own: `qualifier:value` terms separated by
spaces, `-` to exclude, `*` to wildcard, `>` `<` `>=` `<=` and `n-m` for
numbers, and `B/KB/MB/GB/TB` units. Qualifiers that work almost everywhere:
`ts`, `box.id`, `box.name`, `device.id`, `device.name`, `status`. Flows add
`direction`, `domain`, `category`, `region`, `sport`, `dport`, `download`,
`upload`, `total`; alarms add `type`; rules add `action`.

## What Firewalla cannot tell you

The MSP knows the boxes, the devices they see, the traffic through them, and
the rules applied to it. It does not know about the NetBird mesh (see
`netbird.md`), Cloudflare tunnels (see `cloudflare.md`), DNS resolution inside a
host, or anything happening inside a
machine. For those, use the network-diag skill and `hh run` against the hosts
themselves. A device can look perfectly healthy to Firewalla and still be
unreachable over the mesh.
