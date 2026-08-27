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

## Asking the gateway directly

If the UniFi console is registered (check `hh list` for platform `unifi`), it
answers most network questions itself, faster and more completely than probing
from a host:

    hh unifi summary                 # WAN, internet, LAN, WiFi, devices, clients
    hh unifi devices                 # every AP and switch, with state and firmware
    hh unifi clients                 # who is actually connected, and how
    hh unifi networks                # configured networks and VLAN IDs

This is READ-ONLY. It reports on the gateway, switches, and access points; it
cannot change any of them. Configuration changes are made by hand in the UniFi
app. See the unifi-ops skill and `capabilities/unifi.md`.

Not registered yet? An admin adds it from a shell with `hh add-unifi`. It needs
a UniFi API key, minted under a View Only admin, which is why it cannot be done
from the chat.

If the router is a Firewalla instead (platform `firewalla` in `hh list`), the
same questions go to it through Firewalla MSP:

    hh firewalla summary             # box, firmware, public IP, devices, alarms
    hh firewalla devices             # every device, offline ones first
    hh firewalla bandwidth           # top talkers over the last 24 hours
    hh firewalla flows               # recent traffic, blocked flows marked
    hh firewalla rules               # what is blocked or allowed, and for whom

Also READ-ONLY, and for a sharper reason: an MSP token has no read-only scope,
so the GET-only broker is the only thing keeping it from being able to change
the network. Registration is `hh add-firewalla` from a shell, with an MSP
personal access token and your MSP domain (yourname.firewalla.net), not the
box's LAN address. Note that this reads Firewalla's cloud, so it goes down with
the internet - a timeout here is not proof the router is down. See the
firewalla-ops skill and `capabilities/firewalla.md`.

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

    hh netbird summary                       # control plane: peers, offline, drift
    hh netbird peers                         # last seen, agent version, groups
    netbird status                           # on this box: peer list, connection state
    hh run <alias> "netbird status"             # same, from the far end
    # If a host is unreachable by mesh IP but pingable on LAN, the mesh peer is
    # down, not the host. `hh netbird peers` says so without needing the host.

## Cloudflare Tunnels

    hh cloudflare summary                    # edge view: which tunnels are healthy
    hh cloudflare tunnel-show <name>         # hostname -> service ingress table
    hh run <tunnel-host> "cloudflared tunnel list"
    hh run <tunnel-host> "systemctl status cloudflared"
    hh run <tunnel-host> "journalctl -u cloudflared -n 80 --no-pager"

## Known gotchas

- `<record recurring issues here, e.g. a VLAN that loses DNS after a gateway
  update, a 10GbE link that renegotiates to 1G, a NetBird peer that needs a
  restart after the host reboots>`
