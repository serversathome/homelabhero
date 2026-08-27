# Cloudflare - capability catalog

For a Cloudflare account registered with a scoped custom API token. Everything
runs through `hh cloudflare <op> [alias]`, or `hh cf` for short.

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
