---
name: backup-restore
description: >
  Understand and operate the homelab's snapshots and backups: how they work on
  each platform and how to take, list, verify, and restore/roll back safely. Use
  this whenever Evan asks to snapshot, back up, restore, roll back, or recover a
  VM, LXC, dataset, pool, config, or app; asks "can I undo this", "is there a
  backup", "how do snapshots work here", or "are the backups current"; or right
  before you propose a risky/destructive change and want to offer a snapshot as a
  safety net. Do NOT snapshot everything pre-emptively on every task - reach for
  this when recovery is the actual subject, or to offer one safety net before a
  specific dangerous operation.
---

# Backups and snapshots

Recoverability is the safety net this homelab is built on (see CLAUDE.md). This
skill is the knowledge for using it: what each platform offers, and how to take,
inspect, and restore. Everything runs through `hh run <alias> "<command>"`. On a
non-root host (e.g. `truenas_admin`) prefix privileged commands with `sudo -n`
(see CLAUDE.md); `hh list` shows the connect user.

Golden rules:
- Taking a snapshot is safe and cheap. Deleting one, rolling back, or restoring
  OVER live data is destructive of newer state - treat it like any destructive
  op: state exactly what it affects and get an explicit go-ahead first.
- Before you propose a risky change (dataset/pool/VM edit or delete, a migration,
  a bulk config change), OFFER to snapshot first and name it clearly. Offer it
  for the specific risky op; do not snapshot on every routine task.
- A rollback is not a merge. ZFS `rollback` discards everything written after the
  snapshot and destroys intermediate snapshots. Always confirm target and loss.
- Prefer non-destructive restore first: clone / restore to a NEW name, verify,
  then swap. Overwrite-in-place only when the user accepts losing newer state.

## TrueNAS (ZFS)

    zfs list                                   # datasets; zpool list for pools
    zfs snapshot tank/data@before-change       # take one (-r = recursive)
    zfs list -t snapshot -r tank/data          # list, with USED space each
    zfs list -t snapshot -o name,creation -s creation | tail   # most recent
    zfs rollback tank/data@before-change       # DESTRUCTIVE: discards newer state
                                               # (-r also destroys later snapshots)
    zfs clone  tank/data@snap tank/data-restore  # non-destructive: mount + verify
    zfs destroy tank/data@snap                  # remove a snapshot

Restore a single file without rolling back: snapshots are browsable read-only
under the dataset's hidden `.zfs/snapshot/<name>/` directory - copy the file out.

Scheduled protection lives in the middleware (use the truenas-middleware skill to
read method schemas before creating anything):

    midclt call pool.snapshottask.query        # periodic snapshot tasks
    midclt call replication.query              # replication (off-box copies)
    midclt call cloudsync.query                # cloud/rsync backup tasks

## Proxmox (VM/LXC snapshots + vzdump backups)

Snapshots (fast, same-host, point-in-time):

    qm snapshot  <vmid> before-change [--vmstate 1]   # VM (+RAM with vmstate)
    qm listsnapshot <vmid>
    qm rollback  <vmid> before-change                 # DESTRUCTIVE (current state)
    qm delsnapshot <vmid> before-change
    pct snapshot/listsnapshot/rollback/delsnapshot <ctid> ...   # LXC equivalents

Backups (full, restorable to a new guest or storage):

    vzdump <vmid> --storage <stor> --mode snapshot    # no downtime
    pvesm list <stor>                                  # list backups on a storage
    qmrestore <backupfile> <newvmid>                   # restore VM (new id = safe)
    pct restore <newctid> <backupfile>                 # restore CT (new id = safe)

Restoring over an existing id needs `--force` and destroys it - confirm first.
Check the schedule/last run: `pvesh get /cluster/backup` (and Proxmox Backup
Server if used).

## Linux hosts

No universal snapshot facility - detect what exists first:

    command -v zfs lvs restic borg timeshift snapper 2>/dev/null

- ZFS/LVM present: snapshot the relevant filesystem/volume as above (LVM:
  `lvcreate -s -n snap -L 5G /dev/vg/lv`).
- restic/borg present: `restic snapshots` / `borg list` to inspect; restore per
  their docs.
- Config-only change: before editing, copy the file aside with a dated suffix
  (`cp foo.conf foo.conf.bak-YYYYMMDD`) - the minimal, honest safety net.
- If nothing snapshot-capable exists, say so plainly rather than implying an undo
  that isn't there.

## Verify backups are real and recent

Do this when asked "are we covered" and as the first step of any restore:
- TrueNAS: newest snapshot per important dataset (command above); snapshot and
  replication tasks enabled and not erroring.
- Proxmox: newest vzdump per guest is within the expected cadence; the scheduled
  job actually ran.
- Flag anything stale (older than its schedule) as a gap - that is a finding, not
  a footnote.

## Restore workflow

1. Identify exactly what to restore and where (in place vs to a new name).
2. Go non-destructive first (clone / new vmid / copy-out), verify it, then swap.
3. State the blast radius, confirm, execute, then verify the result.
4. If this was a real recovery, append a runbook entry (symptom, cause, fix).
