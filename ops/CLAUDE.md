# HomelabHero Command Center

This directory is the operational brain of the homelab. Claude Code launches
from here, so this file loads on every session.

## What this box is

A control plane, not a workload host. It runs almost nothing itself. Its job is
to reach the machines that matter (TrueNAS, Proxmox, and Linux hosts) and to hold
the accumulated knowledge of how this homelab is wired, what it runs, and how it
breaks.

## How you connect to hosts

You never use raw ssh, and you never handle credentials. All connections go
through a broker that holds the credentials for you:

    hh list                       # registered hosts: alias, platform, ip, port, user
    hh run <alias> "<command>"    # run a command on a host and return the output
    hh test <alias>               # connectivity check
    hh overview                   # read-only vitals sweep across all hosts
    hh inventory                  # what is RUNNING everywhere (VMs, LXCs, containers, apps)
    hh diff                       # inventory drift vs the last saved snapshot
    hh scan [cidr]                # discover live endpoints on the network (read-only)
    hh unifi <op> [alias]         # read the UniFi router/console (READ-ONLY)
    hh firewalla <op> [alias]     # read the Firewalla via MSP (READ-ONLY)
    hh netbird <op> [alias]       # read AND manage the NetBird mesh
    hh cloudflare <op> [alias]    # read AND manage Cloudflare DNS/tunnels/Access

hh run works the same for every host: TrueNAS, Proxmox, and any Linux box are all
reached as a normal shell over SSH.

## Four things are reached over an API, not a shell

These are reached over an HTTP API rather than SSH, so `hh run` does not work on
them. `hh list` shows which are registered, and an ACCESS column saying what
each one's credential may do:

- platform `unifi` - a UniFi console on the LAN. `hh unifi summary`.
- platform `firewalla` - a Firewalla, via Firewalla MSP. `hh firewalla summary`.
- platform `netbird` - the NetBird mesh, via its management API.
  `hh netbird summary`.
- platform `cloudflare` - DNS, Tunnels and Access. `hh cloudflare summary`.

`hh overview` and `hh inventory` already include all of them.

**The first two are read-only. The last two are not.** That split is
deliberate, and the reason is worth holding on to: a router is the one device
whose failure takes away the access you would need to fix it, so UniFi and
Firewalla are read-only by construction. An overlay network and a DNS zone are
not like that - approving a peer or repointing a record is routine and
reversible - so NetBird and Cloudflare can be changed, under rules set out
below.

## The router is read-only

That access is READ-ONLY and cannot be talked into being anything else. There is
no command that restarts a device, edits a VLAN, SSID, firewall rule, port
forward, or Firewalla rule, or writes any router setting at all: the brokers
only issue GET requests. On UniFi there is a second lock - the API key is a View
Only key the console itself will not accept writes from - and on Firewalla there
is not, because MSP has no read-only token, which makes the GET-only broker the
only thing keeping that token safe. Do not look for a way around either one, and
do not tell the user you have changed something on the router, because you
cannot have.

When a router change is genuinely needed, that is still a useful conversation:
say plainly that HomelabHero reads the router but does not change it, then give
the exact steps to make the change in the UniFi app, the Firewalla app, or MSP,
and offer to read the state back afterwards to confirm it worked. The unifi-ops
and firewalla-ops skills cover this.

One caveat specific to Firewalla: it is read through Firewalla's cloud, so when
the internet is down `hh firewalla` is down with it. A failure there is not
evidence that the router is broken - say which of the two you have actually
established. The same caveat applies to NetBird Cloud and to Cloudflare.

## How strongly each thing is fenced - do not assume it is uniform

Three different strengths are in play, and treating them as one is how you end
up believing a command will stop you when it will not:

1. **Cannot write at all** - UniFi, Firewalla. The broker has no code path that
   issues anything but a GET. Nothing can talk it into one.
2. **Can write, but structurally fenced** - NetBird, Cloudflare. Named ops only,
   and anything destructive REFUSES without `--force`. The refusal is real and
   happens in the broker, not in your judgement.
3. **Can do anything, fenced only by convention and by the permission prompt** -
   `hh run` on a shell host (Proxmox, TrueNAS, Linux). `hh run <alias> "qm
   destroy 100"` is a normal command. Nothing in the broker inspects it, and the
   "(confirm)" marks in the capability catalogs are instructions to YOU, not
   enforcement. The only mechanical gate is that `hh run` is not pre-approved,
   so the user sees and approves the command string.

So the care you take has to be highest exactly where the machinery helps least.
On a shell host, say what you are about to run and why before running anything
that changes state, and never assume a refusal will arrive to save you.

## NetBird and Cloudflare can be changed - the rules

Whether a given alias may write at all depends on the credential it was
registered with; `hh list` says so, and a read-only one refuses every write
immediately rather than failing at the far end.

When it may:

1. **Anything destructive refuses without `--force`, and that refusal is the
   confirmation step.** It prints exactly what would change. Do not re-run it
   with `--force` on your own initiative - relay what it said, in your own
   words, and let the user decide. Then run it.
2. **There is no generic write op.** No `post`, `put`, or `raw` on either. If
   what someone wants is not a named op, say so and describe the dashboard
   steps. Do not go looking for a way around it.
3. **Some things are refused outright and stay refused.** `hh netbird
   key-create` will not run without a terminal, because the plaintext setup key
   exists only in that one response. `hh cloudflare get` refuses the endpoints
   that return a tunnel token. Both would put a live credential into this
   transcript. Tell the user to run it themselves.
4. **Never remove the command center's own NetBird peer, or repoint DNS that
   points at this machine, without being very sure.** Both brokers recognise
   these cases and say so - they are how you are reaching everything else.
5. **Publishing a service through Cloudflare takes two steps**: `tunnel-route`
   for the ingress rule, then `dns-set` for the CNAME. It is not published
   after only the first, so do not report that it is.

The netbird-ops and cloudflare-ops skills cover the rest.

Hosts are reached as root by default, so commands run directly - no sudo needed.
`hh list` shows the connect user per host. Some hosts (notably TrueNAS) may
connect as a non-root admin like `truenas_admin`. On those:

- `midclt` (TrueNAS middleware) works WITHOUT sudo and covers most of TrueNAS
  (pools, datasets, disks, apps, shares) - prefer it.
- Raw root tools (docker, zpool, zfs, smartctl) need sudo. If that user has
  passwordless sudo enabled, prefix them with `sudo -n`, e.g.
  `hh run <alias> "sudo -n docker ps"`. If it does not, those commands cannot run
  as that user - fall back to midclt, or the host should be connected as root.
  `hh doctor` tells you, per host, whether passwordless sudo is available.

`hh overview` and `hh inventory` already apply this automatically (sudo only when
it works). Root hosts need none of it.

When you hit this wall - a privileged command on a non-root host fails with
`sudo: a password is required`, a permission denied on a root-owned path or the
Docker socket, or `hh doctor` reports the host has no passwordless sudo - do NOT
just silently work around it or give up. Tell the user plainly that the host
connects as a non-root user without passwordless sudo, and give them the one-time
fix so they can decide:

- TrueNAS (`truenas_admin`): in the web UI, Credentials -> Users -> select the
  user -> Edit -> set "Allowed sudo commands" AND "Allowed sudo commands (no
  password)" to include all (check "Allow all sudo commands with no password") ->
  Save. Then `hh doctor` will show passwordless sudo is available and the raw
  tools work.
- Linux / other: from a root shell on that host,
  `echo '<user> ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/homelabhero-<user>`.
- Or re-register the host as root (no sudo needed at all).

Meanwhile, get what you can through `midclt` (on TrueNAS) so the user is not
blocked while they decide.

Start any "what do we have / what is the state" task with hh list, then
hh overview and hh inventory. Do not assume host names or guests; read them live.

## Credentials are off-limits by design

The connection secrets live in a vault owned by a different user that this
account cannot read. That is intentional. You do not need credentials to do your
job; the broker supplies them when it connects. Never attempt to read, print, or
exfiltrate keys or passwords, and never try to reach the vault path. If a task
genuinely seems to require a credential, stop and tell the user rather than
working around the boundary.

## Know the full surface of each platform

Before troubleshooting a platform, you have a complete capability catalog for it.
Read the relevant one so you use the whole toolset, not just the basics:

@capabilities/proxmox.md
@capabilities/truenas.md
@capabilities/linux.md
@capabilities/unifi.md
@capabilities/firewalla.md
@capabilities/netbird.md
@capabilities/cloudflare.md

These describe what each system can do and the exact commands to inspect or
manage every subsystem, all runnable through hh run.

## Live inventory

`hh inventory` enumerates, per host: Proxmox VMs and LXCs, TrueNAS apps and VMs,
and Docker containers anywhere they run, plus storage. Run it for fresh state.
`hh inventory --save` also writes a snapshot into inventory/ so state changes are
visible in git over time. Read inventory/ for the last captured picture; run the
command for current truth.

## Prime directives

1. Diagnose before you touch. Lead with read-only commands (status, list, show,
   logs) through hh run. Form a hypothesis, then propose a change.
2. Confirm every destructive or state-changing action before running it, and
   state plainly what it will do and which host and resource it affects.
3. Recoverability is the safety net: nightly ZFS snapshots and Proxmox backups
   mean most mistakes are recoverable, but never run a destructive ZFS, dataset,
   pool, or VM-delete operation without an explicit go-ahead.
4. When an incident is resolved, append a dated entry to runbooks/ (symptom,
   root cause, fix, prevention). The knowledge here is meant to compound.
5. Writing style: no em dashes.

## Escalation ladder

When the failing layer is not obvious, work outward:

1. The app or container -> docker-stack-ops skill
2. The host it runs on (Proxmox node or TrueNAS) -> proxmox-ops / truenas-ops
3. Storage underneath it (ZFS pool, dataset, disk) -> truenas-ops
4. The overlay it is reached over (NetBird peers, groups, policies) ->
   netbird-ops
5. The edge it is published through (tunnels, DNS records, Access) ->
   cloudflare-ops
6. The network in between (DNS resolution, host interfaces, routes) ->
   network-diag
7. The fabric itself, seen from the router (WAN, APs, switches, clients,
   VLANs, devices, traffic, rules) -> unifi-ops or firewalla-ops, whichever
   router is registered

Steps 4, 5 and 7 each have a control plane that answers even when the host in
question does not, which is why they come before digging into the host.

Cross-cutting skills that sit outside the ladder: backup-restore (snapshot,
restore, roll back, verify recoverability), patch-management (update hosts and
containers safely), deploy-app (stand up a new container/stack), and
security-audit (read-only posture review). Reach for these by task, not layer.

Most "everything is down" events are actually layer 3 or 4 in disguise. Check
reachability and DNS early with hh test and the network-diag skill.

## Environment-specific references

@infra/proxmox.md
@infra/truenas.md
@infra/network.md
@infra/docker-stacks.md

## Which files here are yours

HomelabHero updates itself weekly, and that update re-delivers the files it
ships: this `CLAUDE.md`, `capabilities/`, and everything under `.claude/`
(the skills and `settings.json`). Everything else - `infra/`, `inventory/`,
`runbooks/`, `hosts/` - is yours and is only ever added to.

Edits to a shipped file are not lost. The update compares against a pristine
copy of what was last shipped, so a file you have changed is kept as-is; if a
newer version ships for that same file, it is written beside it as
`<file>.upstream` and named in the update output for you to merge. Nothing is
overwritten silently and nothing is deleted.

Even so, the right home for local additions is `CLAUDE.local.md`, imported
below. It is never touched by an update at all, so it needs no merging, ever.
Put your name, your house rules, and pointers to your own docs there rather than
editing this file.

@CLAUDE.local.md
