---
name: truenas-ops
description: >
  Troubleshoot and manage TrueNAS SCALE over SSH. Use this whenever Evan
  mentions TrueNAS, the NAS, ZFS, a pool or dataset, a scrub, a snapshot,
  replication, a failing or degraded disk, SMART data, an SMB/NFS/iSCSI share, a
  TrueNAS app, or storage that is full, slow, or throwing errors. Trigger this
  for anything storage-layer even when the symptom first shows up as an app or
  VM that lost its data mount. Prefer this over generic shell reasoning for pool,
  disk, dataset, and share work.
---

# TrueNAS ops

Reached over SSH as `truenas`. Read `infra/truenas.md` for pool names, datasets,
and schedules before acting. Bias hard toward read-only until the cause is clear.

Modern TrueNAS connects as `truenas_admin` (root SSH is disabled). Two paths:

- `midclt` (the middleware) works WITHOUT sudo - call it plain. Prefer it for
  reads and changes where a method exists (pools, datasets, disks, apps, shares).
  See the truenas-middleware skill.
- The raw CLI tools (`zpool`, `zfs`, `smartctl`, `lsblk`, `docker`) do need root.
  They are shown below with `sudo -n`, which works once the box has passwordless
  sudo enabled for `truenas_admin` - HomelabHero enables that at onboarding (see
  the add-server skill), and `hh doctor` flags it if missing. If a raw command
  fails with a sudo/password error, use the midclt equivalent instead.

For the complete command surface of this platform, read capabilities/truenas.md. For a method that is not documented there, use the truenas-middleware skill to discover it live.

## Diagnose first

    hh run truenas "sudo -n zpool status -x"     # fast "all healthy?" verdict
    hh run truenas "sudo -n zpool list"          # capacity + health per pool
    hh run truenas "sudo -n zpool status -v"     # per-vdev/per-disk errors if not healthy
    hh run truenas "midclt call alert.list | jq '.[] | {level, formatted}'"
    hh run truenas "df -h; sudo -n zfs list -o name,used,avail,refer,mountpoint"

## Common cases

- Pool DEGRADED / disk errors: `sudo -n zpool status -v` names the vdev and disk.
  Map the disk to a serial with `sudo -n lsblk -o NAME,SERIAL,MODEL`, confirm with
  `sudo -n smartctl -a /dev/<disk>`. Do not `zpool replace` or offline a disk
  without an explicit go-ahead and a confirmed replacement plan.
- Dataset "missing" / app lost its data: check the mount
  `sudo -n zfs get mounted,mountpoint <pool>/<dataset>` and whether the app's host
  path still resolves. Often a mount or app-config issue, not data loss.
- Pool nearly full: `sudo -n zpool list` capacity, then find the heavy datasets
  `sudo -n zfs list -o name,used -s used`. Old snapshots are a common hidden
  consumer: `sudo -n zfs list -t snapshot -o name,used -s used | tail`.
- Replication failing: `midclt call replication.query | jq '.[] | {name, state: .state.state}'`
  then the task's error, plus SSH connectivity to the target.
- SMART concern: `sudo -n smartctl -H /dev/<disk>` for the verdict,
  `sudo -n smartctl -a /dev/<disk>` for the full attribute table.

## State-changing (confirm first)

    hh run truenas "sudo -n zpool scrub <pool>"                    # safe but I/O heavy
    hh run truenas "sudo -n zfs snapshot <pool>/<dataset>@manual-$(date +%F)"

For a full backup / restore / rollback workflow (clone vs rollback, verifying
that recoverability actually exists), use the backup-restore skill.

Never without explicit go-ahead: `zfs destroy`, `zpool destroy`,
`zpool offline`/`replace`, `wipefs`, or anything that writes to a raw disk.
Recoverability comes from snapshots and replication, so verify those exist
before any risky change.

## Apps on TrueNAS

    hh run truenas "midclt call app.query | jq '.[] | {name, state}'"
    hh run truenas "sudo -n docker ps"      # if custom Docker apps are in use
