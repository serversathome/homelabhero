# The security model

How a credential reaches a machine without Claude ever seeing it, what the agent
does and does not know, and - since not every integration is fenced the same way -
exactly how strongly each one is held.

[← back to the README](../README.md)

## Credential isolation


HomelabHero uses privilege separation with a connection broker. Three users:

- your operator account (installs, registers hosts)
- `hhagent` (runs Claude and the web UI, deliberately low-privilege)
- `hhvault` (owns every credential, mode 700)

Claude runs as `hhagent`, which cannot read anything `hhvault` owns. To reach a
host, Claude runs `hh run`, which invokes the broker `hh-connect` through a single
narrow sudoers rule (`hhagent` may run only that broker, its API siblings
`hh-unifi`, `hh-firewalla`, `hh-netbird` and `hh-cloudflare`, and
`hh-provision`, and only as `hhvault`).
The broker looks the host up in the non-secret registry, reads the key or password
from the vault, and opens the connection. Claude gets the output, never the secret.
An API credential works the same way: the four API brokers read the UniFi API
key, Firewalla MSP token, NetBird service-user token or Cloudflare API token
from the vault and pass it to curl through a config file on stdin, never on the
command line, so it never appears in `/proc` where the agent user could read it.

Two of those four can also make changes (NetBird and Cloudflare), and sudoers is
not what limits that - it grants only the ability to RUN a broker. What limits it
lives inside the brokers themselves: no generic write path, only named ops with
hardcoded methods and paths, `--force` required on anything destructive, and a
per-alias record of whether its credential may write at all.
Even a fully hijacked agent cannot exfiltrate a credential, because the OS will not
let it read the vault and will not let it run anything but the broker as `hhvault`.
The broker also refuses loopback targets and unregistered aliases.

Every brokered command and host registration is recorded to
`/var/log/homelabhero-broker.log`, owned by `hhvault` and unreadable by the agent,
so a hijacked agent can neither read past activity nor erase its own tracks. The
log rotates weekly (`/etc/logrotate.d/homelabhero`). Review it as an operator with
`hh audit [lines]` (needs sudo; the agent cannot read it, by design).

What this protects: credential material never enters Claude's context and cannot be
exfiltrated. What it does not do: restrict what Claude may run on a host it is
already allowed to reach. That is handled by the approval prompts and confirm-first
rule in the ops brain. Two layers, both kept.

Register hosts from a real admin shell (not the Claude web terminal) so the secrets
you type never pass through an LLM-driven session.



- Full platform capability catalogs (`ops/capabilities/`) for Proxmox, TrueNAS, and
  Linux, so Claude uses the whole toolset of each system, not just the basics.
- Live inventory via `hh inventory`: Proxmox VMs and LXCs, TrueNAS VMs, LXCs,
  apps and pools, and Docker containers wherever they run. `hh inventory --save`
  snapshots into `ops/inventory/` so state changes show up in git over time.
- Environment-specific notes about your setup in `ops/infra/`.

## How strongly each integration is fenced

These are not held the same way, and assuming they are puts the least care
exactly where the machinery helps least. Three tiers:

| tier | which | what stops a write |
|---|---|---|
| **cannot write at all** | UniFi, Firewalla | the broker has no code path that issues anything but a GET. There is no verb to reach. |
| **can write, structurally fenced** | NetBird, Cloudflare | named operations only, each with a method and path hardcoded in the broker; anything destructive refuses without `--force` |
| **can do anything** | `hh run` on a shell host | the permission prompt, and the `(confirm)` marks in the capability catalogs - which are instructions to the model, not enforcement |

`hh run pve1 "qm destroy 100"` is an ordinary command. Nothing inspects it. The
only mechanical gate is that `hh run` is not pre-approved, so you see and approve
the command string before it runs.

### What the fences on NetBird and Cloudflare actually are

- **No generic write path.** Reads have an escape hatch (`hh netbird get`,
  `hh cloudflare get`) because a GET nobody anticipated is still only a GET.
  Writes have no equivalent: every one is a named op with a hardcoded path, so
  an endpoint nobody wrote an op for cannot be written to at all.
- **The verb is never derived from input.** Reads hardcode GET; each write
  wrapper hardcodes its own verb and passes it as a literal that is re-checked
  against an allowlist.
- **Destructive operations refuse without `--force`**, and print exactly what
  they would have done. That refusal is the confirmation step, and unlike a
  y/N prompt it still works in a non-interactive session.
- **Self-inflicted outages get a louder refusal**: removing the command
  center's own NetBird peer, or repointing a DNS record that currently points
  at it.
- **Two things are refused outright**, because both would put a live credential
  into a transcript: `hh netbird key-create` will not run without a terminal
  (NetBird returns a setup key's plaintext exactly once), and `hh cloudflare
  get` declines the endpoints that return a tunnel token. `hh netbird get`
  declines the BYOP proxy-token endpoints for the same reason.

Whether a given alias may write at all also depends on the credential it was
registered with - `hh list` shows this in its ACCESS column, and an alias
registered read-only refuses every write without even making a request.

## What this does NOT protect

Worth stating plainly, because the protections above are narrow and specific:

- **It does not limit what Claude may run on a host it can already reach.** The
  broker keeps the credential secret; it does not sandbox the command. `hh run`
  is a shell.
- **It does not protect against you approving something.** The permission prompt
  is the gate for `hh run`; if you approve a destructive command, it runs.
- **It does not make a router change safe.** UniFi and Firewalla are read-only
  precisely because that is the one device whose failure takes away the access
  you would need to fix it.
