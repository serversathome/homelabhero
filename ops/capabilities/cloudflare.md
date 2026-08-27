# Cloudflare - capability catalog

For a Cloudflare account registered with a scoped custom API token. Everything
runs through `hh cloudflare <op> [alias]`, or `hh cf` for short.

## The model - what these objects are

Read this before acting on anything below. The three layers here are
independent, and most wrong answers come from treating them as one thing.

- **Zone** - a domain Cloudflare is authoritative for. DNS records live in it.
  `@` or the bare zone name means the apex.
- **DNS record** - a name pointing somewhere. Two modes, and the difference
  matters more than anything else on this page:
  - **proxied** (orange cloud) - traffic goes through Cloudflare, and the origin
    address is NOT visible in public DNS.
  - **dns-only** (grey cloud) - the record answers with the origin address
    itself, publishing it to anyone who looks.

  `TTL 1` is Cloudflare's "auto", and TTL only has meaning for a dns-only
  record; a proxied one is answered by Cloudflare's own edge.

- **Tunnel** - an OUTBOUND connection from `cloudflared` on a host to
  Cloudflare's edge. Nothing listens on your router; there is no port forward to
  open or close. A tunnel being `healthy` means connectors are attached to the
  edge - it says nothing about whether the service behind them is alive.
- **Ingress rule** - inside a tunnel, a hostname -> local service mapping. The
  list is ORDERED and must end in a catch-all.
- **Publishing a hostname is TWO independent things**: an ingress rule on the
  tunnel, AND a DNS CNAME pointing the hostname at
  `<tunnel-id>.cfargotunnel.com`. Either without the other looks like a fault
  and is not:
  - rule but no CNAME -> the name does not resolve anywhere
  - CNAME but no rule -> the name resolves, and the tunnel returns the
    catch-all's error
- **Access application** - an identity layer sitting in front of a hostname,
  independent of how that hostname is served. A tunnel can serve a hostname with
  or without Access on it, and Access can protect something not tunnelled at
  all. "Behind a tunnel" and "behind Access" are different claims.

Two consequences worth stating outright: `tunnel-unroute` stops serving a
hostname but leaves its DNS record behind, which then starts returning errors
until removed too; and turning a proxied record dns-only exposes the origin
address permanently to anyone who was watching, which no later change undoes.

## Read and write, and which you have

Write capabilities are available only when the alias was registered with a token
carrying **Edit** permissions. With a **Read** token every read below still
works and every write refuses immediately, before making a request. `hh list`
says which, in the ACCESS column.

The fencing around the writes is the same as NetBird's: named ops only, no
generic write path, and `--force` on anything destructive.

**One thing that is specific to Cloudflare.** Elsewhere in HomelabHero "it can
only GET" is the whole safety argument, because a GET only reads. That is not
true here: a few endpoints return credentials rather than describe them, above
all the tunnel token. The read escape hatch refuses those paths. If a tunnel
token is genuinely needed, it comes from the dashboard or from `cloudflared
tunnel token <name>` on a trusted host - never through an agent session.

## Overall state

- One-screen picture: `hh cloudflare summary`
- Token validity and capability: `hh cloudflare ping`
- Which account this alias resolves to, and how: `hh cloudflare account`
- Raw account list: `hh cloudflare info`

`summary` names any tunnel that is not healthy, and any zone that is not active.

## DNS

- Zones this token can see: `hh cloudflare zones`
- Records in a zone: `hh cloudflare records <zone> [name-substring]`

A bare label is expanded against the zone: `home` in `example.com` means
`home.example.com`. `@` means the zone apex.

## Tunnels

- All tunnels with status and connection counts: `hh cloudflare tunnels`
- One tunnel, connectors and ingress table: `hh cloudflare tunnel-show <tunnel>`

A **locally managed** tunnel keeps its ingress in the cloudflared config file on
its host rather than at Cloudflare. `tunnel-show` says so, and the file is what
to read: `hh run <host> "cat /etc/cloudflared/config.yml"`.

## Zero Trust

- Access applications: `hh cloudflare access-apps`

## Anything else

- Any GET under `/client/v4/`, minus the credential-returning paths:
  `hh cloudflare get /client/v4/... [name=value ...]`
- `{account}` is expanded in the path.

## Writes - confirm before running

- Create or update a record: `hh cloudflare dns-set <zone> <type> <name>
  <content> [ttl|auto] [on|off]` - **--force** if it repoints a record currently
  aimed at this machine
- Proxy on or off: `hh cloudflare dns-proxy <zone> <name> on|off` - **--force**
  to turn OFF, which exposes the origin address in public DNS
- Delete a record: `hh cloudflare dns-delete <zone> <name> [type]` **--force**
- Publish a hostname through a tunnel: `hh cloudflare tunnel-route <tunnel>
  <hostname> <service>` - the service is a cloudflared URL such as
  `http://192.168.1.50:8096` or `tcp://10.0.0.5:22`
- Stop serving a hostname: `hh cloudflare tunnel-unroute <tunnel> <hostname>`
  **--force**
- Purge a zone's cache: `hh cloudflare purge <zone>`
- Sign everyone out of an Access app: `hh cloudflare access-revoke <app>`
  **--force**

**Publishing takes two steps.** `tunnel-route` adds the ingress rule; the
hostname still needs a CNAME to `<tunnel-id>.cfargotunnel.com` before it
resolves. The command prints the exact `dns-set` to follow it with. A service is
not published until both are done.

**DNS is cached.** A change does not reach everyone at once, and a wrong one
outlives the moment it was made.

## Not available here

Creating or deleting tunnels and zones, editing Access policies, WAF and page
rules, Workers. Those are dashboard work. HomelabHero can say exactly what to
change and read back the result afterwards.
