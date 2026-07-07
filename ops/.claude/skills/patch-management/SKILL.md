---
name: patch-management
description: >
  Update and patch the managed hosts and their containers safely. Use whenever
  Evan asks to update, upgrade, or patch a host, VM, node, or app; asks "are we
  patched", "any updates", "update proxmox/truenas/ubuntu", "update my
  containers", or wants to apply pending OS or image updates. Covers Debian/Ubuntu
  hosts, Proxmox, TrueNAS, and Docker containers. Diagnose what's pending first,
  snapshot before applying, confirm, then verify. This is about the MANAGED
  hosts, not the HomelabHero control plane.
---

# Patch management

Updates the machines HomelabHero manages and the containers on them. It does NOT
update the control-plane LXC itself - that is the operator-only `hh update`.

On non-root hosts prefix privileged commands with `sudo -n` (see CLAUDE.md). This
is a state-changing workflow: diagnose what's pending, propose it, get a go-ahead,
and prefer a snapshot/backup first (use the backup-restore skill), especially for
OS, kernel, and hypervisor updates.

## Golden rules

- Snapshot/back up before an OS, kernel, or hypervisor update. Offer it every
  time for those; container image bumps are lower risk but still confirm.
- One host at a time. Apply, verify it came back (`hh test`, `hh overview`), then
  move on. Never update the whole estate in one shot.
- Watch for required reboots and say so; do not reboot without a go-ahead.
- Verify after: the service is back, the app works, nothing new is in
  `systemctl --failed` / the container is healthy.

## Debian / Ubuntu hosts

    hh run <alias> "sudo -n apt-get update && apt list --upgradable 2>/dev/null"   # what's pending
    hh run <alias> "sudo -n DEBIAN_FRONTEND=noninteractive apt-get -y upgrade"     # apply (confirm)
    hh run <alias> "ls /var/run/reboot-required 2>/dev/null && echo REBOOT-NEEDED" # kernel/libc?

## Proxmox

Update package lists and apply; kernel updates need a reboot. On a cluster do one
node at a time and migrate guests off first. Back up VMs (vzdump or PBS) before a
major upgrade.

    hh run pve1 "pveupdate && pveupgrade --shell no 2>/dev/null; apt list --upgradable 2>/dev/null"
    hh run pve1 "apt-get -y dist-upgrade"                      # apply (confirm; reboot if kernel)

## TrueNAS

TrueNAS is an appliance - do NOT `apt upgrade` it. Updates are train-based and are
safest applied from the web UI. Check availability over SSH, but hand the actual
apply to the UI unless Evan asks otherwise (it reboots and manages the boot
environment for rollback).

    hh run truenas "midclt call update.check_available"   # is an update staged? (midclt needs no sudo)
    # Applying: TrueNAS UI -> System -> Update (creates a boot environment you can roll back to).

## Docker containers

Pull new images and recreate. Location depends on the layout in
`infra/docker-stacks.md`:

    # single-file layout
    hh run <dockerhost> "cd /mnt/<pool>/docker && sudo -n docker compose pull && sudo -n docker compose up -d"
    # per-stack (Dockge)
    hh run <dockerhost> "cd /opt/stacks/<stack> && sudo -n docker compose pull && sudo -n docker compose up -d"
    # reclaim space afterward (safe - images only, never volumes)
    hh run <dockerhost> "sudo -n docker image prune -f"

If Watchtower or Tugtainer is running, image updates may be automated already -
check before doing it by hand. Note: Watchtower does not touch TrueNAS catalog
apps; those use `WATCHTOWER_DISABLE_CONTAINERS=ix*`, and catalog apps update from
the TrueNAS UI, not here.

## After

Confirm the host/containers are healthy (`hh overview`, `hh test <alias>`, or the
app's own check). If a reboot is pending, say so and let Evan choose the window.
If an update broke something, that's a runbook entry (symptom, cause, fix).
