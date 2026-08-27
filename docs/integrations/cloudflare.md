# Cloudflare

[← back to the README](../../README.md)

## Cloudflare: DNS, Tunnels, and Access


Cloudflare is the front door. Same problem as the mesh, same fix: asking the
host running `cloudflared` tells you nothing when that host is down, and
Cloudflare's edge answers either way.

    hh cloudflare summary
    hh cloudflare tunnels
    hh cloudflare tunnel-show <name>     # which hostname maps to which service
    hh cloudflare records <zone>

Register it from an admin shell:

    hh add-cloudflare

It asks for a **custom API token** - never the Global API Key, which cannot be
scoped and would put full account control in the vault. It tells you exactly
which permissions to tick, and which to use if you want writes as well as
reads. Scope it to the specific zones your homelab uses while you are there: a
token scoped to one zone cannot touch another even if something ever reached it
outside this broker.

With an Edit token you also get `dns-set`, `dns-proxy`, `dns-delete`,
`tunnel-route`, `tunnel-unroute`, `purge` and `access-revoke`, under the same
rules as NetBird: named ops only, and `--force` on anything destructive. Two
extras specific to Cloudflare:

- Repointing a DNS record that currently points at the command center gets the
  louder refusal, for the same reason removing your own mesh peer does.
- The read escape hatch refuses the handful of endpoints that return a
  credential instead of describing one - the tunnel token above all. Everywhere
  else in HomelabHero "it can only issue a GET" is the whole safety argument;
  Cloudflare is the one API where that is not quite true, so the broker names
  those paths and declines them.

### Why not the Cloudflare Claude connector

Cloudflare publishes a remote MCP server that Claude can connect to directly.
It is a good product, and it is the wrong shape for this: the credential would
live with the agent instead of in the vault, nothing would constrain which verb
it used, no line would land in the broker audit log, and none of it would travel
with the `hh` install or work from cron. The connector is worth adding for
Cloudflare's *documentation* server, which holds no account access at all. For
your account, the broker keeps the guarantees the rest of HomelabHero makes.
