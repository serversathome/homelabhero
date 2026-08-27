---
name: netbird-ops
description: >
  Read and manage the NetBird mesh VPN: which peers exist and which are
  connected, when a peer was last seen, agent version drift, groups, access
  policies, network routers and routed resources, mesh DNS, setup keys, the
  audit log, and Bring Your Own Proxy (BYOP) - self-hosted reverse proxies, the
  services published through them, and their apex domains. Use this whenever the user asks about the mesh, the overlay, a
  NetBird peer, whether a host is "on the VPN", why a machine is reachable on
  the LAN but not by its mesh address, who can reach what, or asks to approve a
  peer, move one between groups, turn a policy on or off, or remove a peer.
  This integration CAN change the mesh when registered with an Admin token;
  destructive operations refuse to run without --force.
---

# NetBird mesh

NetBird is the overlay that lets the command center reach hosts wherever they
are. It is not a box on a subnet: it is registered as an account and an API, and
everything goes through one command:

    hh netbird <op> [alias] [args]

The alias can be omitted when only one mesh is registered, which is the normal
case. `hh list` shows it with platform `netbird`, and an ACCESS column saying
whether its token is read-only or READ/WRITE.

## Why this exists, and when it is the right tool

`hh run <alias> "netbird status"` asks ONE PEER what it thinks the mesh looks
like. That is a useful second opinion and a terrible first one, because the
moment it matters most - a host is unreachable - is the moment you cannot run
it. `hh netbird peers` asks the control plane, which still answers.

So: when someone reports a host is unreachable, come here BEFORE trying to shell
into it. The answer is often visible in one line of `hh netbird summary`.

## Know the model before you change anything

`capabilities/netbird.md` opens with what these objects are and how they relate.
The load-bearing one, because it is not how a firewall works:

**Policies name GROUPS, never individual peers.** Granting a host access means
putting it in a group a policy already names, not editing a rule to mention it.
`group-add` and `group-rm` are how access is given and taken away; reaching for
`policy-enable` or a policy edit when a group move is the answer is the most
common way to get this wrong.

Two more that read wrong if you assume otherwise: a peer being `connected` says
nothing about whether policy lets it reach anything, and revoking a setup key
does not remove the peers already enrolled with it.

## Start here

    hh netbird summary        # peers, connected, offline, waiting approval,
                              # agent version drift, routers, policies
    hh netbird peers          # the full table, offline sorted to the top

`summary` is deliberately opinionated: it names offline peers rather than
counting them, names peers stuck waiting for approval, and names peers running
an older agent than the rest of the fleet. Version drift is the single most
common cause of a mesh that works unevenly, so treat that line as a finding.

## Reading further

    hh netbird peer <name|ip>          # one peer in full
    hh netbird groups                  # groups and their membership counts
    hh netbird policies                # who may reach what, one row per rule
    hh netbird policy-show <name>      # one policy in full
    hh netbird networks                # networks (this replaced Routes)
    hh netbird routers                 # routing peers, across every network
    hh netbird resources <network>     # what a network exposes
    hh netbird dns                     # nameserver groups and DNS settings
    hh netbird keys                    # setup keys (values are masked)
    hh netbird posture                 # posture checks
    hh netbird events [n]              # audit log: who changed what
    hh netbird traffic [n]             # flow events (paid plans only)
    hh netbird get /api/...            # anything else, read-only

## BYOP: services published through your own reverse proxy

If the account uses **Bring Your Own Proxy**, NetBird is also an ingress path -
a service can be published under a domain you own, terminated by a reverse proxy
you run, and forwarded to a peer over WireGuard. That matters for triage: when
someone says a service is unreachable from outside, Cloudflare is no longer
necessarily the right place to look.

    hh netbird proxies                 # clusters, and how many proxies are live
    hh netbird services                # what is published, and how it is exposed
    hh netbird service <name>          # one service in full
    hh netbird domains                 # apex domains and validation state

Read the EXPOSURE column in `services` carefully, because it is the thing most
easily misread from the dashboard:

- **public** - reachable from the internet, gated by whatever is in AUTH
- **mesh-only** - reachable ONLY over the NetBird network, gated by group
  membership rather than a login page

A mesh-only service has a real domain and a real certificate and is still not
on the internet. Do not describe one as published externally.

A cluster listed with 0 connected proxies is registered but has nothing running.
That is a container problem on its host, not a NetBird problem:

    hh run <host> "docker ps | grep reverse-proxy"
    hh run <host> "curl -s http://localhost:8080/healthz"

**Proxy access tokens are out of reach**, deliberately. `hh netbird get` refuses
the `proxy-tokens` endpoints: NetBird shows a proxy token's plaintext once, and
anyone holding one can register a proxy against the account. Manage them in the
dashboard.

`hh netbird get` reaches any endpoint the API has - DNS zones, services, geo
locations, the instance endpoint - and can still only issue a GET.

## Changing the mesh

These exist only when the alias was registered with an Admin service-user token.
With a read-only (User role) token they refuse immediately and explain why,
without making a request.

    hh netbird approve <peer>                 # let a waiting peer join
    hh netbird rename <peer> <new-name>
    hh netbird group-add <peer> <group>       # grant reach, via policy
    hh netbird group-rm <peer> <group>        # revoke it
    hh netbird policy-enable <policy>
    hh netbird policy-disable <policy>
    hh netbird ssh <peer> on|off              # NetBird's own SSH server
    hh netbird expiration <peer> on|off
    hh netbird rm-peer <peer>
    hh netbird rm-policy <policy>
    hh netbird rm-group <group>
    hh netbird key-revoke <key>
    hh netbird key-create <name> ...          # terminal only, see below

### The rules for writing

**Anything destructive refuses without `--force`, and that refusal is the
confirmation step.** It prints exactly what the change would do. Do not simply
re-run it with `--force` on your own initiative. Show the user what it said, in
your own words, and let them decide. Then run it with `--force`.

That applies to: `rm-peer`, `rm-policy`, `rm-group`, `key-revoke`,
`group-rm`, `policy-disable`, and to `ssh <peer> on` and `policy-enable` on an
accept policy - the two that WIDEN access rather than narrowing it.

**Never remove the command center's own peer.** The broker recognises it and
says so, because doing it disconnects the box you are running on from the mesh
it uses to reach everything else, and nothing here can put it back.

**`key-create` will not run in an agent session.** NetBird returns the plaintext
setup key exactly once, so the broker refuses to print it anywhere it would land
in a transcript. Tell the user to run it themselves from an admin shell. Do not
try to work around this.

**There is no generic write op.** No `post`, no `put`, no `raw`. If the change
someone wants is not in the list above, say so and describe what to do in the
NetBird dashboard instead. Do not go looking for a way around it.

## What NetBird can and cannot see

It knows the overlay: peers, reachability policy, routed networks, mesh DNS,
and - where BYOP is in use - what it publishes and whether its proxies are
live. It does NOT know whether the service on a peer is healthy, whether the LAN
beneath it is fine, or what a Cloudflare Tunnel is doing. A peer can be
`connected`, and a proxy cluster online, and the app behind both still be down.

**Ingress may be either or both.** With BYOP in use, some services reach the
outside through a NetBird proxy and others through a Cloudflare Tunnel. Check
`hh netbird services` and `hh cloudflare tunnel-show` before concluding a
service is not published anywhere.

Pair with `network-diag` for the layers under and over it, `cloudflare-ops` for
ingress, and `unifi-ops` or `firewalla-ops` for the physical fabric.

Useful order when something is unreachable:

1. `hh netbird summary` - is its peer even connected?
2. `hh netbird peers` - when was it last seen, and is its agent behind?
3. If the peer is connected: `hh test <alias>`, then the host itself.
4. If the peer is offline but the host is up on the LAN: the NetBird agent
   needs a restart on that host, not the mesh.

## Recording what you learn

Durable facts belong in `infra/network.md`: the mesh CIDR, which groups exist
and what they mean, which peers are routers and for which subnets. Reading the
API is how you learn it; writing it down is how it stays learned.
