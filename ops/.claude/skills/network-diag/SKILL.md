---
name: network-diag
description: >
  Diagnose homelab connectivity, DNS, mesh, and ingress issues. Use this
  whenever Evan reports that hosts or services are unreachable, DNS is not
  resolving, the NetBird mesh is flaky, a Cloudflare Tunnel is down, the
  UCG-Ultra gateway or Netgear 10GbE switch is involved, a link dropped or
  renegotiated speed, or a service works locally but not remotely. Trigger this
  early in any "everything is down" situation, since broad outages are usually a
  network or DNS layer wearing an application costume.
---

# Network diagnostics

Read `infra/network.md` for topology, subnets, DNS, and mesh CIDR first.

## Localize: is it reachability, name resolution, or the service

    ping -c2 <host-ip>                 # L3 reachability by IP
    nc -vz <host> <port>               # is the service port open
    dig <name> @<internal-resolver>    # does the name resolve, to what

Three quick outcomes:

- IP pings, name fails -> DNS problem (go to DNS section)
- Neither pings -> host or path down (mesh, switch, gateway)
- Both fine, port closed -> the service, not the network (hand back to the app)

## NetBird mesh

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

## Ingress (Cloudflare Tunnels)

    hh run <tunnel-host> "cloudflared tunnel list"
    hh run <tunnel-host> "systemctl status cloudflared"
    hh run <tunnel-host> "journalctl -u cloudflared -n 80 --no-pager"

## Physical layer (10GbE)

If storage throughput suddenly tanks, check for link renegotiation.

    hh run truenas "sudo -n ethtool <iface> | grep -i speed"
    hh run truenas "sudo -n ip -s link show <iface>"   # errors/drops climbing

The UCG-Ultra and the XS708E are managed from their own UIs; note findings here
and in `infra/network.md`, since they are not SSH targets.
