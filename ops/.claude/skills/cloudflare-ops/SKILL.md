---
name: cloudflare-ops
description: >
  Read and manage Cloudflare: DNS records for your domains, Cloudflare Tunnels
  and their ingress rules, connector health, and Zero Trust Access applications.
  Use this whenever the user asks about a domain or DNS record, whether a
  service is reachable from outside, a tunnel being up or down, cloudflared,
  publishing a service to the internet, an Access application or who can sign
  in to one, or asks to add, repoint or remove a DNS record or a tunnel route.
  This integration CAN change DNS and tunnels when registered with an Edit
  token; destructive operations refuse to run without --force.
---

# Cloudflare (DNS, Tunnels, Access)

Cloudflare is the front door: the DNS for your domains, and the tunnels that
publish homelab services without opening a port. Everything goes through:

    hh cloudflare <op> [alias] [args]

`hh cf` also works. The alias can be omitted when only one account is
registered. `hh list` shows it with platform `cloudflare` and an ACCESS column
saying whether its token is read-only or READ/WRITE.

## Why this exists, and when it is the right tool

`hh run <host> "cloudflared tunnel list"` asks the daemon what it thinks. That
tells you nothing when the host is down - which is exactly when someone reports
that the service is unreachable from outside. `hh cloudflare tunnels` asks
Cloudflare's edge, which knows whether it still has connections, and answers
either way.

## Know the model before you change anything

`capabilities/cloudflare.md` opens with what these objects are and how they
relate. The three that get conflated:

**A tunnel, a DNS record, and an Access application are independent.** A
hostname is published only when BOTH an ingress rule and a CNAME to
`<tunnel-id>.cfargotunnel.com` exist; either alone looks like a fault and is
not. Access sits in front of a hostname regardless of how it is served, so
"behind a tunnel" and "behind Access" are different claims - do not report one
as the other.

And the one that cannot be undone: turning a proxied record dns-only publishes
the origin address to anyone watching. Making it proxied again does not unsee
it.

## Start here

    hh cloudflare summary       # tunnels total/healthy, any that are down,
                                # zones and any not active
    hh cloudflare tunnels       # per-tunnel status, connection count, edge
                                # colos, cloudflared version

A tunnel that is not `healthy` is the most common single cause of "it works at
home but not from outside", so `summary` names those rather than counting them.

## Reading further

    hh cloudflare account                      # which account this alias means
    hh cloudflare zones                        # domains this token can see
    hh cloudflare records <zone> [substring]   # DNS records
    hh cloudflare tunnel-show <tunnel>         # connectors AND the ingress
                                               # table: which hostname maps to
                                               # which local service
    hh cloudflare access-apps                  # Zero Trust Access applications
    hh cloudflare get /client/v4/...           # anything else, read-only

`tunnel-show` is usually the op you want when tracing "why does this hostname
not reach my service": it shows the hostname -> service mapping as Cloudflare
holds it.

A **locally managed** tunnel keeps its ingress in the cloudflared config file on
the host instead of at Cloudflare. `tunnel-show` says so when that is the case,
and the file is what to read:

    hh run <host> "cat /etc/cloudflared/config.yml"

## If an account-scoped op says it cannot find an account

`tunnels`, `tunnel-show` and `access-apps` are account-scoped and need to know
which account to address. Cloudflare's `GET /accounts` only lists accounts when
the token carries **Account Settings: Read**, and without it the endpoint
answers with an empty list rather than an error - which reads like "you have no
accounts" and is never true of a working token.

HomelabHero works around it by reading the account off one of the zones, so a
token with Zone: Read resolves fine either way. `hh cloudflare account` says
which account it settled on and where it came from - run that first when an
account-scoped op misbehaves.

If it genuinely cannot resolve one (a tunnel-only token that can see no zones),
the fix is either adding Account Settings: Read to the token, or writing
`ACCOUNT=<id>` into the alias's registry entry. The error says both. Zone-scoped
ops (`zones`, `records`) never need it.

## Changing things

These exist only when the alias was registered with an Edit token. With a Read
token they refuse immediately and explain why, without making a request.

    hh cloudflare dns-set <zone> <type> <name> <content> [ttl] <on|off>
    hh cloudflare dns-proxy <zone> <name> on|off
    hh cloudflare dns-delete <zone> <name> [type]
    hh cloudflare tunnel-route <tunnel> <hostname> <service>
    hh cloudflare tunnel-unroute <tunnel> <hostname>
    hh cloudflare purge <zone>
    hh cloudflare access-revoke <app>

`dns-set` creates the record if it is absent and updates it if it is present, so
it is the one op for "point this name at that". A bare label is expanded against
the zone: `home` in zone `example.com` means `home.example.com`.

**Proxying is required for A, AAAA and CNAME**, not defaulted, and the op
refuses without it. Both settings are ordinary and the right one depends on the
record:

- a CNAME to `<tunnel-id>.cfargotunnel.com` **must** be `on` - a tunnel hostname
  does not work unproxied;
- a record pointing at a reverse proxy the user runs themselves (nginx proxy
  manager, Caddy, Traefik) is usually `off`, so their proxy terminates the
  connection rather than Cloudflare.

Do not guess on the user's behalf. If the target is a `cfargotunnel.com` name
it is `on`; otherwise ask what the record is for rather than assuming.

### The rules for writing

**Anything destructive refuses without `--force`, and that refusal is the
confirmation step.** It prints exactly what would change. Show the user what it
said, in your own words, and let them decide before re-running with `--force`.

That applies to: `dns-delete`, `tunnel-unroute`, `access-revoke`, `dns-proxy
off` (which publishes the origin address in public DNS), and to any `dns-set`
that would repoint a record currently aimed at this machine.

**Remember DNS is cached.** A change does not take effect everywhere at once,
and a wrong one outlives the moment it was made. Say so when it matters.

**Publishing a service takes two steps, not one.** `tunnel-route` adds the
ingress rule; the hostname still needs a CNAME to `<tunnel-id>.cfargotunnel.com`
before anything resolves. The command prints the exact `dns-set` to follow it
with. Do not report a service as published after only the first step.

**There is no generic write op**, and the read escape hatch refuses the handful
of endpoints that return credentials rather than describe them - the tunnel
token above all. If someone needs that token, it comes from the Cloudflare
dashboard or from `cloudflared tunnel token` on a host they trust, never through
an agent session.

## What Cloudflare can and cannot see

It knows the edge: DNS as the world resolves it, whether a tunnel has live
connections, what Access is protecting. It does NOT know whether the service
behind the tunnel is healthy - a tunnel can be perfectly healthy and the app
behind it returning 502 all day.

Pair with `netbird-ops` for the overlay, `network-diag` for DNS resolution and
the hosts themselves, and `docker-stack-ops` for the service behind the tunnel.

**Cloudflare may not be the only way in.** If the account also runs NetBird BYOP
(its own reverse proxy), some services are published through that instead. A
service missing from `tunnel-show` is not necessarily unpublished - check
`hh netbird services` before saying so.

Useful order when something is unreachable from outside:

1. `hh cloudflare summary` - is the tunnel even up?
2. `hh cloudflare tunnel-show <tunnel>` - is the hostname routed, and to where?
3. `hh cloudflare records <zone> <name>` - does the DNS record exist and point
   at the tunnel?
4. Then the service itself on the host, via `docker-stack-ops`.

## Recording what you learn

Which services sit behind which tunnel, and which hostnames they answer on,
belong in `infra/network.md`. That file already has a place for it.
