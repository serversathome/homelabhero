# UniFi console - capability catalog

For a UniFi router/gateway (UCG, UDM, UDR, Cloud Key Gen2+, UniFi OS Server)
registered with an API key. Everything runs through `hh unifi <op> [alias]`.
`hh run` does NOT apply here: the console is reached over its local HTTPS API,
not SSH.

## Read-only, with no exceptions

Every capability below reads. There is no write capability, not because none
was documented but because none exists: the broker issues HTTP GET and has no
code path that can POST, PUT, PATCH, or DELETE. The API key is additionally
minted under a View Only UniFi admin, so the console refuses writes on its own.

So there is nothing to "confirm before running" in this catalog, and nothing
here can break the network. What there IS to do, when a change is needed, is
tell the user exactly what to change in the UniFi app and then verify the
result by reading it back. See the unifi-ops skill.

## Overall state

- One-screen picture: `hh unifi summary`
- Subsystem health (WAN, internet, LAN, WiFi): `hh unifi health`
- Console and Network application version: `hh unifi info`
- Sites on the console (usually one): `hh unifi sites`
- Reachability check: `hh unifi ping`

## Devices (gateway, switches, access points)

- All adopted gear with state, IP, firmware: `hh unifi devices`
- One device in full: `hh unifi device <deviceId>`
- Latest statistics for a device: `hh unifi stats <deviceId>`
- Device IDs come from `hh unifi devices`; pass the `id` field, not the name.

What to look for: any device not `ONLINE`, and anything flagged
`update available`. An offline switch or access point explains every host
behind it, so check this before troubleshooting those hosts.

## Clients

- Connected clients with IP, MAC, and type: `hh unifi clients`
- Answers "is that machine actually on the network", "what address did it get",
  "is it wired or wireless".

## Networks and VLANs

- Configured networks with VLAN IDs and subnets: `hh unifi networks`
- Useful when a host cannot reach another host: confirm they are on the
  networks you think they are.

## Anything else (raw GET)

The named ops cover the common ground. For the rest, a read-only escape hatch
takes any path under `/proxy/network/`, with `{site}` (the integration API's
site UUID) and `{siteName}` (the legacy API's short name) substituted for you:

- Firewall policies: `hh unifi get '/proxy/network/integration/v1/sites/{site}/firewall/policies'`
- Event log: `hh unifi get '/proxy/network/api/s/{siteName}/stat/event?_limit=20'`
- Port forwarding: `hh unifi get '/proxy/network/api/s/{siteName}/rest/portforward'`
- WiFi networks (SSIDs): `hh unifi get '/proxy/network/api/s/{siteName}/rest/wlanconf'`
- Per-client detail: `hh unifi get '/proxy/network/integration/v1/sites/{site}/clients/<id>'`

Two APIs live under `/proxy/network/`:

- `/proxy/network/integration/v1/...` is the documented integration API. It is
  stable and paginated (`offset`, `limit`, `count`, `totalCount`, `data`), and
  addresses a site by UUID. Prefer it.
- `/proxy/network/api/s/{siteName}/...` is the older private API. It returns
  `{meta: {...}, data: [...]}` and addresses a site by short name (normally
  `default`). Use it for what the integration API does not cover yet, above all
  site health.

Both accept the same API key. The integration API needs Network 9.0 or newer.

## What UniFi cannot tell you

The console knows the fabric and the gear on it. It does not know about the
NetBird mesh (see `netbird.md`), Cloudflare tunnels (see `cloudflare.md`), DNS
resolution, or anything happening inside
a host. For those, use the network-diag skill and `hh run` against the hosts
themselves. A service can be perfectly healthy in UniFi's view and still be
unreachable over the mesh.
