# Changelog

Notable changes to HomelabHero, newest first.

The version lives in `HH_VERSION` at the top of `bin/hh` and is printed by
`hh version`. Versioning is semantic: MAJOR for a breaking change to an existing
command, MINOR for new functionality, PATCH for fixes.

To move between versions, re-run the installer (see README). `hh update` pulls
the latest and needs no manual migration for any release below.

## Linking to a release

Every version heading carries a stable anchor of the form
`v<major>-<minor>-<patch>`, so a GitHub release body, an issue, or a commit can
link straight to the notes instead of duplicating them:

    https://github.com/serversathome/homelabhero/blob/main/CHANGELOG.md#v1-1-0

The anchor is written explicitly rather than relying on the heading text,
because GitHub strips the dots out of `## 1.1.0` and generates `#110`, which is
easy to get wrong and changes if a date is added to the heading.

When adding a version, keep the three in sync: the anchor (`v1-1-0`), the git
tag (`v1.1.0`), and `HH_VERSION` in `bin/hh` (`1.1.0`).

<a id="v1-5-0"></a>

## 1.5.0 (2026-08-27)

Follow-ups to 1.4.0, from putting both integrations in front of a real account.

### NetBird Bring Your Own Proxy

BYOP makes NetBird an ingress path as well as an overlay: a service can be
published under a domain you own, terminated by a reverse proxy you run, and
forwarded to a peer over WireGuard.

New read ops `proxies`, `services`, `service` and `domains` report the clusters
and how many proxies are live, what is published through them, and the apex
domains. `summary` gains proxy and service lines, and stays silent when BYOP is
not in use rather than printing a reassuring zero. Creating and editing a
service stays dashboard work.

`services` reports exposure as **public** or **mesh-only**. That is the detail
most easily misread from the dashboard: a mesh-only service has a real domain
and a real certificate and is deliberately not on the internet.

Because ingress can now be either path, `network-diag` asks both NetBird and
Cloudflare before concluding a service is unpublished, and `cloudflare-ops`
notes that a service missing from `tunnel-show` may simply be published through
NetBird instead.

A management server older than 0.72 answers 404 on every path under
`/api/reverse-proxies`. The named BYOP ops say so plainly and exit clean, rather
than relaying a bare HTTP 404; `summary` simply omits its BYOP lines. `hh
netbird get` still reports the 404 verbatim, because someone typing a path by
hand wants to know exactly what came back.

`hh netbird get` now refuses the `proxy-tokens` endpoints. A proxy access
token's plaintext is shown once at creation and registers a proxy against the
whole account; NetBird's docs do not say whether the list endpoint returns it,
and that is not a thing to establish by trying it with a live credential. This
is the same guard `hh-cloudflare` carries for the tunnel token - one place in
each API where "it can only issue a GET" stops being a sufficient safety
argument.

### Cloudflare account resolution

The first real token to meet this broker could not resolve an account, and the
message it got back was true but useless: "the token works, but it cannot see
any Cloudflare account". The token was fine.

`GET /accounts` lists accounts only when the token carries **Account Settings:
Read**, and a token scoped to Cloudflare Tunnel and Access - exactly what `hh
add-cloudflare` tells you to create - does not carry it. Cloudflare answers 200
with an empty list rather than an error, so the broker relayed "no accounts",
which is never true of a working token.

Resolution now falls back to the zone list, where every zone carries the account
it belongs to. Zone: Read is already required for the DNS ops, so this works on
the narrower token at no extra cost. Failing both, the error names the two real
fixes - grant Account Settings: Read, or set `ACCOUNT=` in the registry entry -
and points out that the zone-scoped ops need neither.

New `hh cloudflare account` reports which account an alias resolves to and
whether that came from the cache or from Cloudflare just now. The failure was
hard to see precisely because every account-scoped op failed identically and
none said what account it was looking for.

The registration prompt lists Account Settings: Read with an explanation of what
it is for, and registration now resolves the account while the operator is still
at the keyboard rather than on some later call.

### Documentation

Both capability catalogs now open with a **model section** - what the objects
are and how they relate - ahead of the command list. The catalogs described what
each op returns and the skills described when to reach for one, but neither said
what a group or a tunnel actually *is*, which left the domain knowledge to be
inferred.

For NetBird that means stating outright that policies name groups and never
individual peers, so access is granted by moving a peer between groups rather
than editing a rule; that a connected peer may still be allowed to reach
nothing; and that revoking a setup key does not remove the peers enrolled with
it.

For Cloudflare it means separating three layers that get conflated: a hostname
is published only when an ingress rule AND a CNAME to
`<tunnel-id>.cfargotunnel.com` both exist, Access sits in front of a hostname
independently of how it is served, and turning a proxied record dns-only
publishes the origin address in a way no later change undoes.

### Capability boundaries

Five of the seven capability catalogs had no section saying what their platform
CANNOT tell you. Only `unifi.md` and `firewalla.md` did, and that section is the
most direct guard against overclaiming: it is where "the VM is running" gets
separated from "the service is up". All seven now have one.

`proxmox.md` also gains the two model traps that produce confidently wrong
answers: VMs and containers share one id space cluster-wide, so `qm` and `pct`
are not interchangeable views of the same thing; and most commands are
node-scoped, so a guest you cannot find in a cluster is usually on another node
rather than gone.

`ops/CLAUDE.md` now states that the three integrations are not fenced equally.
UniFi and Firewalla cannot write at all; NetBird and Cloudflare can, behind a
broker that refuses destructive ops without `--force`; and `hh run` on a shell
host can do anything, fenced only by the permission prompt and by the
"(confirm)" marks in the catalogs, which are instructions to the model rather
than enforcement. Assuming that machinery is uniform is how a shell host gets
treated more casually than the integrations that are actually the safer ones.

### Fixes

- `op_summary` and `op_account` in `hh-cloudflare` called `_account` inside a
  command substitution, so the account name it resolved was discarded with the
  subshell and the summary line printed a bare id for a name that had just been
  looked up successfully.
- `cmd_netbird`'s inline usage still listed the `policy` op, missed when the
  read ops were renamed in 1.4.0 to avoid prefix-matching the write ops.

<a id="v1-4-0"></a>

## 1.4.0 (2026-08-27)

Two new networking integrations, and the first two that can change something.

**NetBird mesh - `hh netbird`.** HomelabHero could already reach hosts over the
mesh; it could not see the mesh itself except by asking one peer
(`hh run <alias> "netbird status"`), which is one peer's opinion and is
unavailable exactly when it matters - when the host you would ask is the host
that is down. This asks NetBird's management API instead.

Reads: `summary ping info peers peer groups networks routers resources policies
policy-show dns keys posture events traffic get`. `hh netbird summary` names
offline peers and how long they have been gone, peers waiting on approval, and
peers running an older agent than the rest of the fleet - the last being the
most common cause of a mesh that works unevenly, and invisible from any one
peer. Built on `/api/networks` rather than the Routes resource NetBird has
deprecated.

Writes (Admin service-user token only): `rename approve ssh expiration
group-add group-rm policy-enable policy-disable key-create key-revoke rm-peer
rm-policy rm-group`.

**Cloudflare - `hh cloudflare`** (also `hh cf`). Same problem at the other end:
`cloudflared tunnel list` on a host tells you nothing when that host is down.

Reads: `summary ping info zones records tunnels tunnel-show access-apps get`.
`tunnel-show` prints the hostname-to-service ingress table, which is usually the
answer to "why does this name not reach my service", and says so plainly when a
tunnel is locally managed and its ingress lives in a file on the host instead.

Writes (Edit token only): `dns-set dns-proxy dns-delete tunnel-route
tunnel-unroute purge access-revoke`. `dns-set` creates or updates in one op and
expands a bare label against the zone.

### The write model

UniFi and Firewalla remain read-only by construction and are not changing. A
router is the one device whose failure takes away the access you would need to
fix it. An overlay network and a DNS zone are not like that, so these two can be
changed - under fences that are part of the design, not conventions:

- **No generic write path.** Reads keep their `get` escape hatch, because a GET
  nobody anticipated is still only a GET. Writes have no equivalent: every one
  is a named op with a method and path hardcoded in the broker, so an endpoint
  nobody wrote an op for cannot be written to.
- **The verb is never derived from input.** `_read` hardcodes GET; each write
  wrapper hardcodes its own verb and passes it as a literal that is re-checked
  against an allowlist.
- **Destructive ops refuse without `--force`**, printing exactly what they would
  have done. That refusal is the confirmation step, and it works in a
  non-interactive session where a y/N prompt would not.
- **Self-inflicted outages get a louder refusal**: removing the command center's
  own NetBird peer, or repointing a DNS record that currently points at it.
- **Two things are refused outright.** `hh netbird key-create` will not run
  without a terminal, because NetBird returns a setup key's plaintext exactly
  once. `hh cloudflare get` refuses the endpoints that return a tunnel token.
  Both would otherwise put a live credential into a transcript.

A read-only credential is fully supported for both - the registry records what
each token may do, and a read-only alias refuses every write immediately without
making a request.

### Also in this release

- `hh list` gains an ACCESS column saying whether each entry is `shell`,
  `read-only`, or `READ/WRITE`.
- Platform detection is keyed off `PLATFORM` throughout. It previously
  identified UniFi by `AUTH=apikey`, which was unambiguous while UniFi was the
  only credentialled API host and would have matched three things once NetBird
  and Cloudflare arrived.
- `hh repin` now also covers a self-hosted NetBird management server presenting
  its own certificate, and explains itself instead of erroring on platforms that
  have no pin to refresh.
- No read op is a prefix of a write op, in either integration. Claude's
  permission rules match on a command prefix, so allow-listing `hh cloudflare
  dns` would have silently granted `dns-set`, `dns-proxy` and `dns-delete`. The
  read ops affected were renamed (`records`, `tunnel-show`, `access-apps`,
  `policy-show`); the older names still work when typed, they are simply not
  allow-listed.
- The agent permission set allows the read ops of both integrations and leaves
  every write op to prompt. `hh add-netbird` and `hh add-cloudflare` are denied
  outright, like the other registration commands.
- `network-diag`, `unifi-ops`, `firewalla-ops` and the capability catalogs no
  longer say the mesh and tunnels are invisible, because they are not. New
  skills `netbird-ops` and `cloudflare-ops`, new catalogs
  `capabilities/netbird.md` and `capabilities/cloudflare.md`.

<a id="v1-3-3"></a>

## 1.3.3 (2026-08-25)

The 1.3.2 transition works as intended now, rather than flattening local edits
once on the way in.

### Fixed

- The shipped-file baseline is seeded by the installer, so the update that
  introduces it no longer resets your edits. 1.3.2 put that seeding in
  `hh-update`, which cannot work and never once did: `hh-update` pulls and then
  runs the installer, and the installer is what replaces `hh-update`, so during
  the very update that first needs a baseline the `hh-update` on the box is
  still the old one from before the code existed. Every box therefore took the
  fallback path - update applied, previous file saved as `<file>.bak-<stamp>` -
  which loses nothing but flattens every local edit once and leaves a backup
  beside every file that changed, edited or not.

  The seeding now lives in the installer, which IS already the new version at
  that point, and recovers the previous revision from `ORIG_HEAD` (set by the
  `git reset --hard` that `hh-update` just did). On a simulated 1.3.1 box with
  local edits: 16 untouched files updated silently, 1 genuine conflict kept with
  its `.upstream`, and no backups at all, where before every shipped file was
  replaced and backed up.

  If you already updated to 1.3.2, you have taken this hit and your baseline
  exists - nothing further to do, and your `.bak-` files can be deleted once you
  have re-applied anything you wanted. If you have not updated yet, the
  transition will be clean.

  Found by @bnaert, who verified the 1.3.2 behaviour on a real install and
  reported exactly what happened.

- The unreachable copy in `hh-update` is removed rather than left in place. Code
  that claims to do something it structurally cannot is worse than no code, and
  this is the second bug in a row caused by putting update logic where it could
  not run.

<a id="v1-3-2"></a>

## 1.3.2 (2026-08-24)

`hh update` no longer throws away your edits to the files it ships.

### Fixed

- Local edits to shipped files survive an update. The installer restored
  `.claude/` (every skill and `settings.json`), `capabilities/`, and `CLAUDE.md`
  from the shipped copy unconditionally on every run, and `hh update` re-runs
  the installer weekly by cron - so a renamed operator in a skill description,
  an environment note added to a capability doc, or a paragraph appended to
  `CLAUDE.md` was reverted, with no warning, no log line, and no backup. The
  only way to notice was to keep the ops brain in git and diff after every
  update.

  HomelabHero now keeps a pristine copy of what it last delivered, in
  `/etc/homelabhero/shipped/`, and compares three ways on each update, the way
  dpkg handles a config file: an untouched file takes the update silently; a
  file you edited where nothing new shipped is left alone silently; and a file
  you edited where a new version DID ship keeps your copy, writes the new one
  beside it as `<file>.upstream`, and names it in the update output. Nothing is
  overwritten without saying so, and nothing is deleted.

  On the first update after this change there is no pristine copy yet, so an
  edit cannot be told from an old version: that run still applies the update,
  but saves the previous file as `<file>.bak-<timestamp>` first, so even the
  one-time bootstrap loses nothing. Every run after it preserves in place.

  Reported by @bnaert, who lost work to this three times before identifying the
  cause.

### Added

- `CLAUDE.local.md`, a supported local layer for the ops brain. `CLAUDE.md`
  imports it and the installer never touches it, so anything in it survives
  every update by construction rather than by merge. It is the right home for
  your name, your house rules, and pointers to your own docs. Created empty on
  install if absent.

- `hh doctor` reports the ops brain: how many shipped files have local edits,
  whether any `.upstream` versions are waiting to be merged, and whether
  `CLAUDE.local.md` exists. Preserving an edit is only trustworthy if you can
  see that it happened without going through git history.

### Changed

- The shipped skills no longer hardcode a personal name. Their descriptions
  named one specific person, which was wrong for everyone else and made
  personalising 15 files the single most common reason to edit a shipped file
  at all - the top casualty of the bug above. They now say "the user", which
  reads correctly for everybody and triggers no worse. If you want Claude to
  use your name, say so in `CLAUDE.local.md`.

<a id="v1-3-1"></a>

## 1.3.1 (2026-08-21)

Firewalla aliases now mean one box.

### Fixed

- A Firewalla alias is pinned to a single box, and every per-box read is
  filtered to it. An MSP personal access token is scoped to an ACCOUNT, not to
  a box, and 1.3.0 filtered by nothing at all: on an account with more than one
  Firewalla, `devices`, `alarms`, `flows`, `bandwidth`, `rules`, `lists`, and
  `summary` returned every box's data merged into one table, with no column
  saying which row came from where. A device at another site appeared under an
  alias its owner would reasonably read as "my router". On a single-box account
  none of this was visible.

  `hh add-firewalla` now resolves the boxes the token can see and, when there is
  more than one, asks which the alias means, storing it as `GID=` in the
  registry entry. Registering a second box is another `hh add-firewalla` run
  with the same token and a different alias, and `hh firewalla <op> <alias>`
  picks between them. To change which box an alias reads:
  `hh rm-host <alias> && hh add-firewalla`.

  An entry registered under 1.3.0 has no pin. On a single-box account the broker
  resolves it on first use and caches it back, silently, because nothing about
  the answer was ever in doubt. On a multi-box account the per-box ops REFUSE
  and name the boxes to choose from, rather than guessing: a plausible table
  from the wrong site is worse than no table.

  Three ops stay account-wide on purpose and say so where it matters: `boxes`
  (which is how you find the other boxes, and which now marks the one an alias
  reads), `ping` (a connectivity check, which has to work before a pin exists),
  and `stats` (every supported type ranks boxes against each other).

  Reported, diagnosed, and tested against a live two-box account by @lesterktm.

### Changed

- `hh firewalla trends` says that it is account-wide. The trends endpoints
  filter by MSP group rather than by box, so the box pin cannot narrow them;
  rather than let an account-wide number pass as one box's, the output names the
  limit and points at the fix - put the box in an MSP group of its own, then
  read that group with `hh firewalla get '/v2/trends/flows' 'group=<id>'`. The
  README and the capability catalog say the same. Per-box numbers obtained this
  way sum back to the account-wide total (confirmed live by @lesterktm).

- The raw escape hatch expands `{gid}` in the path and in query values, so an
  ad-hoc query can scope itself the way the named ops do:
  `hh firewalla get '/v2/flows' 'query=box.id:{gid} total:>50MB'`.

- `hh repin` on a Firewalla explains that there is no TLS pin to refresh and
  points at re-registration if what was meant was changing the box.

<a id="v1-3-0"></a>

## 1.3.0 (2026-08-20)

Firewalla routers can be read the way UniFi consoles already could, and a
natively installed Claude Code survives the weekly update.

### Added

- Read-only Firewalla support. A Firewalla (Gold, Gold SE, Gold Plus, Purple,
  Blue Plus) registers with `hh add-firewalla` and is read with
  `hh firewalla <op>`: `summary`, `boxes`, `devices`, `device`, `alarms`,
  `flows`, `bandwidth`, `rules`, `lists`, `trends`, `stats`, `info`, `ping`,
  and a raw `get` escape hatch for any other MSP endpoint. It appears in
  `hh list` with platform `firewalla`, and `hh overview`, `hh inventory`,
  `hh test`, and `hh doctor` all include it. `hh run` refuses it and says why,
  the same as for a UniFi console.

  Firewalla ships no supported local API, so this reads Firewalla MSP -
  Firewalla's own management portal - over the internet, which means an MSP
  account is required and the integration goes down when your internet does.
  That makes it a poor first probe for "is the internet up" and a good one for
  everything else.

  It is read-only by construction: `hh-firewalla` issues HTTP GET and has no
  code path that can POST, PUT, PATCH, or DELETE. That guarantee carries more
  weight here than it does on UniFi. A UniFi API key is minted under a View Only
  admin, so the console refuses writes on its own; Firewalla MSP has no
  read-only token scope, so the token in the vault carries the account's full
  permissions and the GET-only broker is the only thing making it safe to hold.
  The token is stored in the vault where the agent user cannot read it and is
  passed to curl through a config file on stdin, never on the command line. The
  new `firewalla-ops` skill and `capabilities/firewalla.md` tell Claude the rule
  plainly, and tell it what to do instead when a change is genuinely needed.

  There is no TLS pin, unlike UniFi, and that is deliberate: pinning exists to
  make a self-signed LAN certificate trustworthy, and an MSP domain is a public
  host with a publicly trusted certificate, so ordinary CA verification applies
  and is the stronger check. Certificate verification is never disabled.

  Thanks to @lesterktm for the request and the research that started it.

### Fixed

- A native Claude Code install now survives, and is preferred. On some machines
  npm never resolves the platform-specific optional dependency that carries the
  actual claude binary (`@anthropic-ai/claude-code-linux-x64`): the install
  reports success, lands one package instead of two, and leaves a claude that
  cannot start, so the command center service crash-loops. Anthropic's native
  installer works on those boxes, but nothing here could see or keep its result.

  Two things blocked it. The generated systemd unit built its `PATH` from the
  nvm prefix alone, so a native claude in `~/.local/bin` was invisible to the
  service; that directory is now first on the unit's PATH, and on the PATH
  `hh doctor` and `hh login` use, so all three agree on which claude the box
  runs. And `hh update` re-runs the installer weekly, so the unconditional npm
  install recreated its bin link and clobbered any native install on every cron
  run - the same weekly-clobber dynamic the `--allow-scripts` fix had to solve
  one layer up. A working native claude now wins: the npm `claude-code` package
  is skipped entirely while one is present, and it keeps itself updated anyway.

  When there is no native install, the npm result is no longer taken on trust.
  The installer runs it, and if it cannot start, falls back to Anthropic's
  native installer, verifies that, and retires the broken npm copy so exactly
  one claude is left on the box.

  Thanks to @escrima76 for the detailed report.

### Changed

- `hh doctor` prints the path claude was resolved from next to its version.
  When an npm copy and a native copy disagree, which one the box actually runs
  is the first thing worth knowing.

<a id="v1-2-1"></a>

## 1.2.1 (2026-08-15)

Installs on TrueNAS 26 that died on the first line of setup now work.

### Fixed

- The installer no longer aborts when `no_new_privs` is set on the attaching
  shell alone. The preflight read the flag from `/proc/self/status` and stopped
  there, so a TrueNAS web shell or `lxc-attach` session - both of which set the
  flag per session, on containers whose PID 1 is clean - failed immediately
  after `Starting setup...`, with advice to recreate the container as
  privileged. That advice could not have worked: the flag was never a property
  of the container, and on TrueNAS 26 the ID Map Type is fixed at creation, so
  following it cost a full rebuild and changed nothing.

  The flag is now read from `/proc/1/status` and `/proc/self/status`
  separately, because the two mean different things. Set on PID 1, the whole
  container is constrained - including the command center service, which PID 1
  forks - and the install still stops with the privileged-recreate or
  run-in-a-VM advice, which applies there and only there. Set on the shell
  alone, the install continues when it is already root, since nothing has to
  escalate, and stops for a non-root user with the fix that actually works:
  get a shell from PID 1 with `systemd-run --pty --quiet /bin/bash`, or SSH in
  rather than attaching from the host UI. The flag is one-way and cannot be
  cleared, so such a shell has to be replaced, not repaired. If
  `/proc/1/status` cannot be read, the check says nothing rather than guessing.

### Changed

- The README names the web UI's port. It described the installer as finishing
  with "a browser link" without ever saying `3001`, so anyone who scrolled past
  the final banner had nothing to go back to. The address, the `PORT=` override
  in `/etc/homelabhero/cloudcli.env`, and the first-visit steps are now written
  out in the install section.

<a id="v1-2-0"></a>

## 1.2.0 (2026-08-05)

Your router joins the homelab. HomelabHero can now discover a UniFi console
during setup and read it over its local API, so the gateway stops being the one
piece of the network Claude has to guess about.

It is **read-only** and cannot be talked out of it. Reading the router is
enormously useful; letting an agent write to it is not, because the router is
the one device whose failure takes away the access you would need to fix it.

### Added

- `hh scan` looks for your router. Anything at the default gateway or at the
  `.1` of the subnet (`192.168.1.1`, `10.99.0.1`) is fingerprinted, and a UniFi
  console is identified by name and version through its unauthenticated status
  endpoint, falling back to its TLS certificate. The results table gained a
  `ROLE` column, and a found router is called out by name, since it is the one
  device nobody thinks of as "a server to add".
- `hh add-unifi` registers a UniFi console with an API key. Offered directly
  from `hh scan --add` and from step 10 of the installer, so the normal path is
  simply to accept it during setup. Operator- and shell-only, like password
  auth: an API key is a secret being typed, and a secret typed into a chat
  session has already been seen by the LLM.
- `hh unifi <op> [alias]` reads the console: `summary`, `health`, `devices`,
  `clients`, `networks`, `info`, `sites`, `device`, `stats`, `ping`, and a
  read-only `get` escape hatch for any other path under `/proxy/network/`
  (`{site}` and `{siteName}` are substituted for you). The alias may be omitted
  when only one console is registered, which is the usual case.
- `hh overview` and `hh inventory` include the console: WAN and internet health,
  LAN and WiFi status, adopted devices with firmware state, and client counts.
  `hh doctor` and `hh test` check it too.
- A `unifi-ops` skill and a `capabilities/unifi.md` catalog, plus gateway-first
  guidance in `network-diag` and `infra/network.md`. An offline switch or access
  point explains every host behind it, so checking the fabric first saves
  troubleshooting those hosts one at a time.
- `hh repin <alias>` re-pins a console's TLS public key after you legitimately
  change its certificate.

### Security

- **Read-only in three independent places.** The `hh-unifi` broker issues HTTP
  `GET` and has no code path that can `POST`, `PUT`, `PATCH`, or `DELETE`, so no
  prompt and no jailbreak can reconfigure the network through it. Registration
  tells you to mint the key under a **View Only** UniFi admin, so the console
  refuses writes on its own. The ops brain and the skill state the rule plainly
  and redirect to "tell the user what to change, then read it back to confirm".
- The API key never reaches the agent. It lives in the vault (mode 600,
  `hhvault`), and `hh-unifi` hands it to curl through a config file on stdin
  rather than a command-line header, so it never appears in `/proc`, which is
  world readable and would otherwise expose it to the very user the vault exists
  to keep it from.
- The console's TLS public key is pinned on first contact (trust on first use,
  like SSH's `accept-new`) and verified on every later call. A UniFi console
  ships a self-signed certificate, so ordinary CA validation cannot apply; a
  changed certificate now fails closed with instructions rather than quietly
  trusting a new identity.
- `hh-connect` refuses an API-key host with a pointer to `hh unifi`, and
  `hh-provision` refuses to register one at all, so there is no path from the
  chat to a stored credential.

### Fixed

- Registry values may now contain `=`. Both brokers split on the first `=` by
  hand instead of using `IFS='='`, which silently dropped a trailing `=` and so
  truncated the base64 padding of a pinned key into one that could never match.
- `hh scan` no longer aborts when the default route cannot be read. With
  `pipefail`, a missing `ip` or an LXC with no default route turned a lookup
  that is allowed to fail into a fatal one, and the scan produced nothing at
  all.

<a id="v1-1-1"></a>

## 1.1.1 (2026-07-27)

### Changed

- TrueNAS apps are formatted as a name/state/version table in `hh inventory`,
  the same treatment VMs and LXCs got in 1.1.0. They were still printing as raw
  JSON truncated at 3000 characters, so a box with a dozen apps produced an
  unreadable blob, and an empty app list printed a bare `[]`.

### Fixed

- An unreadable middleware response is now reported instead of silently
  producing an empty section. Previously any parse failure was swallowed, so a
  changed API shape would look identical to "nothing is running", which is the
  exact blind spot this reporting exists to remove. A namespace the running
  version does not have is still quiet, since that is normal and expected rather
  than a fault.

<a id="v1-1-0"></a>

## 1.1.0 (2026-07-27)

TrueNAS VMs and LXC containers now show up in the inventory, at parity with how
Proxmox guests have always been reported.

### Added

- `hh inventory` reports TrueNAS VMs and LXC containers. It previously listed
  pools, Docker containers, and apps, but no guests at all, so a VM or LXC on
  the NAS was invisible to every command that builds on inventory.
- Guest reporting covers all three TrueNAS virtualization backends, because the
  middleware namespace changed with the engine:
  - 24.10 and earlier: libvirt VMs only, `vm.*`
  - 25.04 (Fangtooth) and 25.10 (Goldeye): Incus for both VMs and LXC,
    `virt.instance.*`
  - 26: Incus removed, libvirt drives VMs and libvirt_lxc containers, `vm.*`
    again
  Both namespaces are queried and whatever answers is reported, so one binary
  works across all of them with no per-host configuration.
- Version-aware TrueNAS virtualization docs in `capabilities/truenas.md`,
  `infra/truenas.md`, and the `truenas-ops` / `truenas-middleware` skills,
  including a live `core.get_methods` probe so the method surface is read off
  the box rather than assumed.
- A documented gotcha for the 26 Incus-to-libvirt migration: orphaned LXCs and
  VMs that vanish from the UI while their zvols survive under the hidden
  `.ix-virt` dataset. The data is usually intact, so the guidance is to reattach
  the existing zvol rather than delete and rebuild.

### Changed

- TrueNAS guests are formatted as a name/type/state table instead of raw
  truncated JSON, matching the readability of the Proxmox `qm list` and
  `pct list` output:

      docker-vm              VM         RUNNING
      pihole-lxc             CONTAINER  STOPPED

- `hh inventory` section labels on TrueNAS: `# Containers` is now `# Docker`,
  and guests appear under `# VMs / LXCs`. The old label was ambiguous once LXC
  containers entered the picture, since it actually meant Docker.
- The `homelab-triage` skill runs `hh inventory` alongside `hh overview` in step
  one, and states that overview lists no guests on any platform. Previously a
  "state of the homelab" answer could report healthy while a VM or LXC was
  stopped, because overview covers vitals and pool health only.

### Notes

- `hh overview` is unchanged and remains a fast vitals sweep. Guest state comes
  from `hh inventory`.
- If TrueNAS 26 ships LXC under a namespace that is neither `virt.instance` nor
  `vm`, those containers will not be listed yet. Confirm the real name on a 26
  box with the `core.get_methods` probe documented in `capabilities/truenas.md`.

<a id="v1-0-0"></a>

## 1.0.0 (2026-07-18)

Initial release. One command turns a fresh LXC into a homelab command center:
Claude Code plus a web UI, preloaded skills for TrueNAS, Proxmox, Docker, and
networking, and a credential broker that connects to managed hosts over SSH
without exposing secrets to the agent.
