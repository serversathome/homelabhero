# NetBird

[← back to the README](../../README.md)

## Your NetBird mesh (read, and write if you let it)


The mesh is how the command center reaches hosts wherever they are, and until
now HomelabHero could only see it from inside one peer:

    hh run <alias> "netbird status"

That is one peer's opinion, and it is unavailable exactly when it matters -
when the host you would ask is the host that is down. Registering NetBird asks
the control plane instead:

    hh netbird summary
    hh netbird peers
    hh netbird policies

`summary` names things rather than counting them: which peers are offline and
how long they have been, which are waiting for approval, and which are running
an older agent than the rest of the fleet. That last one is the most common
cause of a mesh that works unevenly, and it is invisible from any single peer.

Register it from an admin shell:

    hh add-netbird

It asks you to create a NetBird **service user** - a non-interactive account
made for exactly this - and a token under it. The role you give that service
user is the important choice:

- **User** is read-only. Every read op still works - peers, groups, policies,
  routes, BYOP services, the audit log.
- **Admin** can also change the mesh, which turns on `approve`, `group-add`,
  `policy-enable`, `rm-peer` and the rest.

Pick User unless you actually want Claude able to change the mesh. HomelabHero
records which you chose, and a read-only alias refuses every write immediately
rather than failing at the far end.

If you pick Admin, here is the honest trade. Every read then runs with a
credential that could have written, so the broker's shape is the only lock
rather than the second one. That shape is: no generic write path at all - only
named ops with methods and paths hardcoded in the broker - and anything
destructive refuses to run without `--force`, printing exactly what it would
have done first. Removing the command center's own peer gets a louder refusal
still, because that is the one change that takes away the mesh you would use to
undo it.

One thing is refused outright and stays refused: `hh netbird key-create` will
not run without a terminal. NetBird shows a setup key's plaintext exactly once,
so running it in an agent session would put the only copy into a transcript.

If you run **Bring Your Own Proxy**, that is covered too: `hh netbird proxies`,
`services` and `domains` show the clusters, what is published through them, and
whether each service is public or mesh-only. Worth knowing because it makes
ingress two paths rather than one - a service missing from your Cloudflare
tunnels may simply be published through NetBird instead. Proxy access tokens are
deliberately out of reach: `hh netbird get` refuses those endpoints.

Self-hosted NetBird works too - give `hh add-netbird` your management host
instead of `api.netbird.io`, and if it presents its own certificate rather than
a publicly trusted one, HomelabHero pins it the way it pins a UniFi console.
