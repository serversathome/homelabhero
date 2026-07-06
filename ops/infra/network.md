# Network

The fabric that ties the homelab together. When something is broadly
unreachable, this is usually the real layer even when it looks like an app
problem.

## Topology

- Gateway / router: UniFi Cloud Gateway Ultra (UCG-Ultra). Routing, DNS,
  firewall, VLANs.
- Core switch: Netgear XS708E, 10GbE. TrueNAS and the Proxmox nodes hang off
  this for storage-speed links.
- Overlay: NetBird mesh VPN. This is how the command center reaches every
  managed host. Direct, encrypted peer connections, no port forwarding.
- Ingress: Cloudflare Tunnels for anything published to the outside.

## Fill me in

- LAN subnet(s) / VLANs: `<...>`
- Internal DNS resolver and domain: `<...>`
- NetBird network CIDR: `<...>`
- Which services sit behind Cloudflare Tunnels: `<...>`

## Reachability checks

    ping -c3 <host-mesh-ip>
    hh run <alias> "echo ok"                    # mesh + SSH in one shot
    hh run <alias> "ip -br addr && ip -br link" # interfaces up, addresses assigned
    nc -vz <host> <port>                     # is a specific port open

## DNS

    dig <name> @<internal-resolver>
    hh run <alias> "resolvectl status | head -30"
    # Split-horizon surprises live here. If a name resolves from the gateway but
    # not from a host, suspect per-VLAN DNS or a stale record.

## NetBird mesh

    netbird status                           # on this box: peer list, connection state
    hh run <alias> "netbird status"             # same, from the far end
    # If a host is unreachable by mesh IP but pingable on LAN, the mesh peer is
    # down, not the host.

## Cloudflare Tunnels

    hh run <tunnel-host> "cloudflared tunnel list"
    hh run <tunnel-host> "systemctl status cloudflared"
    hh run <tunnel-host> "journalctl -u cloudflared -n 80 --no-pager"

## Known gotchas

- `<record recurring issues here, e.g. a VLAN that loses DNS after a gateway
  update, a 10GbE link that renegotiates to 1G, a NetBird peer that needs a
  restart after the host reboots>`
