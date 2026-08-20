# Firewalla - capability catalog

For a Firewalla (Gold, Gold SE, Gold Plus, Purple, Blue Plus, Purple SE)
registered with a Firewalla MSP personal access token. Everything runs through
`hh firewalla <op> [alias]`. `hh run` does NOT apply here: the Firewalla is
reached over the MSP API, not SSH.

## Where this reads from

Firewalla ships no supported local API on the box, so HomelabHero reads it
through Firewalla MSP - Firewalla's own management portal - at
`https://<yourname>.firewalla.net/v2/...`. That means:

- The MSP account is the source of truth, and it sees every box in the account,
  not just one. `hh firewalla boxes` lists them.
- Reads go out to the internet and back. If the internet is down, this is one
  of the things that stops working, which makes `hh firewalla` a poor first
  probe for "is my internet down" and a good one for everything else.

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
- Every box in the MSP with model, mode, firmware, public IP, counts:
  `hh firewalla boxes`
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

## Anything else (raw GET)

The named ops cover the common ground. For the rest, a read-only escape hatch
takes any path under `/v2/`, plus optional `name=value` query parameters which
are URL-encoded for you (the MSP API requires that):

    hh firewalla get '/v2/devices' 'box=<gid>'
    hh firewalla get '/v2/alarms' 'query=type:8 status:active' 'limit=50'
    hh firewalla get '/v2/flows' 'query=device.name:*iphone* total:>50MB'
    hh firewalla get '/v2/rules' 'query=status:paused action:allow'
    hh firewalla get '/v2/target-lists' 'owner=global'

The query syntax is Firewalla's own: `qualifier:value` terms separated by
spaces, `-` to exclude, `*` to wildcard, `>` `<` `>=` `<=` and `n-m` for
numbers, and `B/KB/MB/GB/TB` units. Qualifiers that work almost everywhere:
`ts`, `box.id`, `box.name`, `device.id`, `device.name`, `status`. Flows add
`direction`, `domain`, `category`, `region`, `sport`, `dport`, `download`,
`upload`, `total`; alarms add `type`; rules add `action`.

## What Firewalla cannot tell you

The MSP knows the boxes, the devices they see, the traffic through them, and
the rules applied to it. It does not know about the NetBird mesh, DNS
resolution inside a host, Cloudflare tunnels, or anything happening inside a
machine. For those, use the network-diag skill and `hh run` against the hosts
themselves. A device can look perfectly healthy to Firewalla and still be
unreachable over the mesh.
