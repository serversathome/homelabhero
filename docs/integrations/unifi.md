# UniFi

[← back to the README](../../README.md)

## Your UniFi router (read-only, on purpose)


A UniFi console (UDM, UCG, Cloud Key Gen2+, UniFi OS Server, on Network 9.0 or
newer) can be registered alongside your servers. It shows up in `hh list` like
anything else, and `hh overview` and `hh inventory` include it:

    Console   10.99.0.1   Network 9.0.114
    WAN       ok      ip 203.0.113.7   gateway UCG-Ultra 4.2.14   isp Example ISP
    Internet  ok      latency 12 ms   down/up 940.5/88.2 Mbps   uptime 1209600s
    LAN       ok      41 clients, 2 switches, 3 adopted, 0 offline
    WiFi      ok      38 clients, 2 APs, 2 adopted, 0 offline
    Devices   5 adopted, 5 online
    Updates   firmware available for 1 device: Office AP
    Clients   43 connected

That means "the internet is down", "which access point is offline", "is that
machine actually on the network", and "what VLAN is it on" become questions
Claude can answer from the gateway itself, instead of inferring from the hosts.

**It can only read. It cannot change anything on your network.** That is enforced
in three independent places, not just asked for in a prompt:

1. The broker behind `hh unifi` issues HTTP `GET` and has no code path that can
   `POST`, `PUT`, `PATCH`, or `DELETE`. There is no restart, no reboot, no
   firewall, VLAN, SSID, or port-forward edit, because none of it is implemented.
2. You mint the API key under a **View Only** UniFi admin, so the console itself
   refuses writes from that key regardless of what asks.
3. The ops brain and the `unifi-ops` skill tell Claude the rule plainly, and tell
   it what to do instead: explain the change you should make in the UniFi app,
   then read the state back to confirm it worked.

The router is the one device whose failure takes away the access you would need
to fix it. A bad firewall rule or an ill-timed reboot can cut off every host, the
command center, and you, all at once. Reading it is enormously useful; letting an
agent write to it is not worth that.

Register it from an admin shell (an API key is a secret being typed, so it stays
out of the chat, exactly like password auth):

    hh add-unifi

It walks you through creating the key in the UniFi app, stores it in the vault
where the agent cannot read it, and pins the console's TLS public key on first
contact (trust on first use, like SSH). If you later replace the console's
certificate, `hh repin <alias>` accepts the new one; until you do, calls fail
closed rather than quietly trusting a new identity.
