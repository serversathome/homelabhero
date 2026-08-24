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
