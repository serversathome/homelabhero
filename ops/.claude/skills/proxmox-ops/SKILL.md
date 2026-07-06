---
name: proxmox-ops
description: >
  Troubleshoot and manage Proxmox VE over SSH. Use this whenever Evan mentions
  Proxmox, PVE, a VM or LXC container, a hypervisor node, "qm", "pct", cluster
  quorum, HA, migration, a VM that won't boot or is stuck, a node running hot or
  unreachable, VM/container backups (vzdump), or Proxmox storage. Trigger this
  even if he only names a VM or container by ID or purpose and wants it started,
  stopped, checked, or fixed. Prefer this over generic shell reasoning for
  anything hypervisor-level.
---

# Proxmox ops

Reached over SSH as `pve1` / `pve2`. Read `infra/proxmox.md` for this
environment's node names, VMIDs, and storage layout before acting.

For the complete command surface of this platform, read capabilities/proxmox.md.

## Diagnose first

    hh run pve1 "pvesh get /version"                 # API alive
    hh run pve1 "qm list && pct list"                # inventory + states
    hh run pve1 "cat /proc/loadavg; free -h; df -h /"# node pressure
    hh run pve1 "pvesm status"                        # storage health/usage
    hh run pve1 "pvecm status"                        # quorum, if clustered
    hh run pve1 "ha-manager status"                   # HA, if used

## Common cases

- VM won't start: check `qm status <id> --verbose`, then
  `journalctl -u pvedaemon -n 100`, then the VM config
  `qm config <id>` for a missing disk or ISO still mounted.
- VM stuck / unresponsive: `qm monitor <id>` info, consider `qm reset <id>`
  (confirm first, it is a hard reset).
- Storage full blocking operations: `pvesm status` and `df -h`; clear old
  vzdump archives or snapshots, do not delete VM disks.
- Node hot or thrashing: identify the VM with `qm list` + guest load; often a
  backup window or a runaway guest.

## State-changing (confirm first, name the target and effect)

    hh run pve1 "qm snapshot <id> pre-change-$(date +%F)"   # snapshot before risk
    hh run pve1 "qm start|stop|reboot|shutdown <id>"
    hh run pve1 "pct start|stop|reboot <id>"
    hh run pve1 "qm migrate <id> <target-node> --online"     # if clustered
    hh run pve1 "vzdump <id> --storage <backupstore> --mode snapshot"

Never run `qm destroy` / `pct destroy` or storage-wiping operations without an
explicit go-ahead, and prefer a fresh backup or snapshot first.

## Handoff

If the fault is inside the guest OS, SSH into the guest itself. If it is the
storage under the node (ZFS on TrueNAS), switch to truenas-ops.
