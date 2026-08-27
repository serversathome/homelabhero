---
name: network-diag
description: >
  Diagnose homelab connectivity, DNS, mesh, and ingress issues. Use this
  whenever the user reports that hosts or services are unreachable, DNS is not
  resolving, the NetBird mesh is flaky, a Cloudflare Tunnel is down, the
  UCG-Ultra gateway or Netgear 10GbE switch is involved, a link dropped or
  renegotiated speed, or a service works locally but not remotely. Trigger this
  early in any "everything is down" situation, since broad outages are usually a
  network or DNS layer wearing an application costume.
---

# Network diagnostics

Read `infra/network.md` for topology, subnets, DNS, and mesh CIDR first.

## Ask the gateway first, if it is registered

When a UniFi console is registered (`hh list` shows platform `unifi`), start
there. One command rules the whole fabric in or out before probing host by host:

    hh unifi summary                 # WAN, internet, LAN, WiFi, devices, clients
    hh unifi devices                 # anything not ONLINE explains a lot at once

An offline switch or access point accounts for every host behind it, so finding
one here saves troubleshooting those hosts individually. The unifi-ops skill
covers the rest, including clients and VLANs.

This is read-only: it diagnoses the fabric, it does not reconfigure it. UniFi
changes are made by hand in the UniFi app.

## Then ask the mesh and the edge, if they are registered

The overlay and the ingress each have their own control plane, and each answers
when the host in question does not. Check them before shelling anywhere:

    hh netbird summary               # is the peer even connected? (netbird-ops)
    hh cloudflare summary            # is the tunnel up? (cloudflare-ops)

This is the order that saves the most time: fabric, then overlay, then edge,
then the host. Three of those four answer while the host is unreachable, so
working inward means you usually know WHERE the break is before you try to log
in to anything.

What none of them can see, and this skill can: DNS resolution inside a host,
the host's own interfaces and routes, and whether the service itself is alive.
A NetBird peer can be `connected` and a Cloudflare tunnel `healthy` while the
app behind them returns 502 all day.

## Localize: is it reachability, name resolution, or the service

    ping -c2 <host-ip>                 # L3 reachability by IP
    nc -vz <host> <port>               # is the service port open
    dig <name> @<internal-resolver>    # does the name resolve, to what

Three quick outcomes:

- IP pings, name fails -> DNS problem (go to DNS section)
- Neither pings -> host or path down (mesh, switch, gateway)
- Both fine, port closed -> the service, not the network (hand back to the app)

## NetBird mesh

Ask the control plane first - it answers when the peer does not:

    hh netbird summary                 # offline peers, agent version drift
    hh netbird peers                   # last seen, per peer
    hh netbird peer <name>             # one peer in full

Then the peer's own opinion, which is a good second source and a poor first one:

    netbird status                     # local peers and connection state
    hh run <alias> "netbird status"       # from the far side, if reachable another way

If a host is reachable on its LAN IP but not its mesh IP, the mesh peer is down.
Restart NetBird on that host; peers commonly need a nudge after the host reboots.

## DNS

    resolvectl status | head -30
    dig <name> @<internal-resolver>
    dig <name> @1.1.1.1                # compare internal vs external answer

Split-horizon mismatches (internal name resolving differently per VLAN, or a
stale record after a gateway change) show up as "works from here, not from
there". Compare answers from two vantage points.

## Ingress

There may be TWO ways in, and checking only one is the most common way to
conclude wrongly that a service is not published:

- a **Cloudflare Tunnel**, and
- a **NetBird BYOP reverse proxy**, if the account runs one.

Ask both before deciding:

    hh netbird services                # NetBird-published, and public vs mesh-only
    hh cloudflare tunnels              # Cloudflare-published

A NetBird service marked **mesh-only** is reachable over the mesh and gated by
group membership - it has a domain and a certificate and is deliberately NOT on
the internet. That is a configuration, not a fault.

### Cloudflare Tunnels

Cloudflare's own view first, for the same reason:

    hh cloudflare tunnels              # status and live connection counts
    hh cloudflare tunnel-show <name>   # which hostname maps to which service
    hh cloudflare records <zone> <name>  # does the DNS record point at it

A hostname needs BOTH an ingress rule and a CNAME to
`<tunnel-id>.cfargotunnel.com`; one without the other is a common half-finished
state that looks like a tunnel fault and is not.

Then the daemon on the host:

    hh run <tunnel-host> "cloudflared tunnel list"
    hh run <tunnel-host> "systemctl status cloudflared"
    hh run <tunnel-host> "journalctl -u cloudflared -n 80 --no-pager"

## Physical layer (10GbE)

If storage throughput suddenly tanks, check for link renegotiation.

    hh run truenas "ethtool <iface> | grep -i speed"
    hh run truenas "ip -s link show <iface>"   # errors/drops climbing

The UCG-Ultra and the XS708E are managed from their own UIs; note findings here
and in `infra/network.md`, since they are not SSH targets.
