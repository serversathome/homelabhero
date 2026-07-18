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
`midclt` (the middleware) is the preferred way to inspect and change TrueNAS - it
covers pools, datasets, disks, apps, and shares (see the truenas-middleware
skill), and needs no sudo. The raw tools below (zpool, zfs, smartctl, docker) need
root: if this host connects as `truenas_admin`, prefix them with `sudo -n` (works
when passwordless sudo is enabled for that user; `hh doctor` shows whether it is,
and if not, use the midclt equivalent). As root they run bare - see CLAUDE.md.

For the complete command surface of this platform, read capabilities/truenas.md. For a method that is not documented there, use the truenas-middleware skill to discover it live.

## Diagnose first

    hh run truenas "zpool status -x"     # fast "all healthy?" verdict
    hh run truenas "zpool list"          # capacity + health per pool
    hh run truenas "zpool status -v"     # per-vdev/per-disk errors if not healthy
    hh run truenas "midclt call alert.list | jq '.[] | {level, formatted}'"
    hh run truenas "df -h; zfs list -o name,used,avail,refer,mountpoint"

Mandatory before you call it healthy - scan the kernel log. Pools, SMART, and
alert.list miss PCIe AER, NIC link flaps, ATA/disk resets, MCEs, and OOM kills;
those only surface here:

    hh run truenas "journalctl -k -b -p warning --no-pager | grep -viE 'veth|br-[0-9a-f]{12}' | tail -40"

Empty output is the pass; read it before reporting green. See "Health check
must-dos" in infra/truenas.md for the full rationale.

## Common cases

- Pool DEGRADED / disk errors: `zpool status -v` names the vdev and disk.
  Map the disk to a serial with `lsblk -o NAME,SERIAL,MODEL`, confirm with
  `smartctl -a /dev/<disk>`. Do not `zpool replace` or offline a disk
  without an explicit go-ahead and a confirmed replacement plan.
- Dataset "missing" / app lost its data: check the mount
  `zfs get mounted,mountpoint <pool>/<dataset>` and whether the app's host
  path still resolves. Often a mount or app-config issue, not data loss.
- Pool nearly full: `zpool list` capacity, then find the heavy datasets
  `zfs list -o name,used -s used`. Old snapshots are a common hidden
  consumer: `zfs list -t snapshot -o name,used -s used | tail`.
- Replication failing: `midclt call replication.query | jq '.[] | {name, state: .state.state}'`
  then the task's error, plus SSH connectivity to the target.
- SMART concern: `smartctl -H /dev/<disk>` for the verdict,
  `smartctl -a /dev/<disk>` for the full attribute table.

## State-changing (confirm first)

    hh run truenas "zpool scrub <pool>"                    # safe but I/O heavy
    hh run truenas "zfs snapshot <pool>/<dataset>@manual-$(date +%F)"

For a full backup / restore / rollback workflow (clone vs rollback, verifying
that recoverability actually exists), use the backup-restore skill.

Never without explicit go-ahead: `zfs destroy`, `zpool destroy`,
`zpool offline`/`replace`, `wipefs`, or anything that writes to a raw disk.
Recoverability comes from snapshots and replication, so verify those exist
before any risky change.

## Apps on TrueNAS

    hh run truenas "midclt call app.query | jq '.[] | {name, state}'"
    hh run truenas "docker ps"      # if custom Docker apps are in use
