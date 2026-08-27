# NetBird mesh - capability catalog

For a NetBird mesh (Cloud or self-hosted) registered with a service-user token.
Everything runs through `hh netbird <op> [alias]`. `hh run` does NOT apply here:
the mesh is reached over the management API, not SSH.

## The model - what these objects are

Read this before acting on anything below. Most wrong answers about NetBird come
from assuming it works like a firewall, where rules name hosts. It does not.

- **Peer** - one device running the NetBird agent. Has a stable mesh IP, an OS,
  an agent version, and belongs to zero or more groups.
- **Group** - a bag of peers. It is a label, not a network segment.
- **Policy** - a rule: source group(s) -> destination group(s), a protocol and
  ports, accept or drop.

  **Policies are written against GROUPS, never against individual peers.** This
  is the fact everything else follows from. To give a host access to something,
  you do not edit a rule to mention it - you put it in a group a policy already
  names (`group-add`). To take access away, you remove it from that group
  (`group-rm`). Reaching for a policy edit when a group move is the answer is
  the most common way to get this wrong.

- **Setup key** - an enrolment credential, optionally auto-assigning groups to
  whatever joins with it. **Revoking a key does not remove the peers already
  enrolled with it**; it only stops it being used again. "Revoke the key" is
  often said when "remove the peer" is meant - `rm-peer` is that.
- **Approval** - where the account requires it, a newly enrolled peer sits out
  of the mesh until approved. It is registered, visible, and cannot reach
  anything. `approve` releases it.
- **Network / router / resource** - how things that are NOT peers get reached. A
  routing peer (router) advertises a route into a subnet on its side; resources
  name what is exposed there. A network with no connected router reaches
  nothing, however correct its policies are.
- **Posture check** - a device condition (agent version, OS) attached to a
  policy's source, so a rule can require a peer be up to date as well as in the
  right group.
- **Login expiration** - periodic re-authentication for a peer. Normal for
  laptops, usually turned off for servers, because an expired server peer drops
  off the mesh until a human signs it back in.

Two things follow that are worth stating outright: a peer being `connected` says
nothing about whether policy lets it reach anything, and a policy being
`enabled` says nothing about whether any peer is in the groups it names.

## Read and write, and which you have

Unlike the UniFi and Firewalla catalogs, this one has write capabilities. They
are available only when the alias was registered with an **Admin** service-user
token; with a **User** (read-only) token every read below still works and every
write refuses immediately, before making a request.

`hh list` says which: the ACCESS column reads `READ/WRITE` or `read-only`.

The fencing around the writes:

- there is no generic write path - only the named ops below, each with a method
  and a path hardcoded in the broker;
- anything destructive refuses without `--force`, printing what it would do;
- the command center's own peer is recognised and specially guarded;
- `key-create` refuses to run without a terminal, because the plaintext setup
  key exists only in that one response.

## Overall state

- One-screen picture: `hh netbird summary`
- Reachability and token capability: `hh netbird ping`
- Raw account object: `hh netbird info`

`summary` names rather than counts: offline peers, peers waiting for approval,
and peers running an agent version behind the rest of the fleet.

## Peers

- All peers, offline first: `hh netbird peers`
- One peer in full: `hh netbird peer <name|ip|id>`

A peer resolves by id, exact IP, exact name or hostname, then by substring - in
that order, and an ambiguous substring is refused rather than guessed.

## Access control

- Groups and membership: `hh netbird groups`
- Policies, one row per rule: `hh netbird policies`
- One policy in full: `hh netbird policy-show <name>`
- Posture checks: `hh netbird posture`

## Routed networks

- Networks: `hh netbird networks`
- Routing peers across every network: `hh netbird routers`
- What a network exposes: `hh netbird resources <network>`

Networks replaced the older Routes resource, which NetBird now marks deprecated.

## Bring Your Own Proxy (BYOP)

Present only if the account runs its own reverse proxies. All read-only:
creating and editing a service is dashboard work.

- Proxy clusters and live proxy counts: `hh netbird proxies`
- Published services: `hh netbird services`
- One service in full: `hh netbird service <name>`
- Apex domains and validation: `hh netbird domains`

`services` reports EXPOSURE as **public** (on the internet, gated by AUTH) or
**mesh-only** (reachable only over NetBird, gated by group membership). A
mesh-only service has a domain and a certificate and is still not published
externally.

A cluster with 0 connected proxies is registered but not running - that is a
container on a host, reachable via `hh run <host> "curl -s
http://localhost:8080/healthz"`.

**Not readable here:** the `proxy-tokens` endpoints. `hh netbird get` refuses
them. A proxy token's plaintext is shown once at creation and registers a proxy
against the whole account, so it is dashboard-only.

## DNS, keys, history

- Nameserver groups and settings: `hh netbird dns`
- Setup keys, values masked: `hh netbird keys`
- Audit log, who changed what: `hh netbird events [n]`
- Flow events (paid plans): `hh netbird traffic [n]`

## Anything else

- Any GET under `/api/`: `hh netbird get /api/... [name=value ...]`

## Writes - confirm before running

Each of these changes the mesh. Those marked **--force** will not run without it
and will print exactly what they would do first; treat that refusal as the
confirmation prompt and put it to the user rather than re-running it yourself.

- Approve a waiting peer: `hh netbird approve <peer>`
- Rename a peer: `hh netbird rename <peer> <new-name>`
- Add to a group (grants reach): `hh netbird group-add <peer> <group>`
- Remove from a group: `hh netbird group-rm <peer> <group>` **--force**
- Enable a policy: `hh netbird policy-enable <policy>` **--force** if it accepts
- Disable a policy: `hh netbird policy-disable <policy>` **--force**
- NetBird SSH server: `hh netbird ssh <peer> on|off` **--force** to turn on
- Login expiration: `hh netbird expiration <peer> on|off`
- Remove a peer: `hh netbird rm-peer <peer>` **--force**
- Delete a policy: `hh netbird rm-policy <policy>` **--force**
- Delete a group: `hh netbird rm-group <group>` **--force**
- Revoke a setup key: `hh netbird key-revoke <key>` **--force**
- Create a setup key: `hh netbird key-create <name> [reusable|one-off] [days]
  [group ...]` - **terminal only**, never in an agent session

## Not available here

Anything not in the list above. There is no `post`, `put`, or `raw`. Creating
networks, editing posture checks, and changing account settings are dashboard
work; HomelabHero can tell the user exactly what to do and then read back the
result.
