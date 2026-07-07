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

hh run works the same for every host: TrueNAS, Proxmox, and any Linux box are all
reached as a normal shell over SSH.

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
4. The network between them (mesh, switch, gateway, DNS, tunnels) -> network-diag

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
