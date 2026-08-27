# Proxmox VE - capability catalog

Everything below runs through `hh run <pve-alias> "..."`. This is the full
surface of what a Proxmox node can do and how to inspect or drive each part.
Lead with the read side; the write side is marked and needs confirmation.

## The model - two traps worth knowing

- **VMs and containers share ONE id space, cluster-wide.** Id 100 is either a
  QEMU VM or an LXC container, never both, and never on two nodes. So `qm` and
  `pct` are not interchangeable views of the same thing: running `qm stop 100`
  when 100 is a container fails in a way that reads like the guest is missing.
  `pvesh get /cluster/resources` is the one call that lists both with their
  type, and is the right way to find out which you are holding.
- **Most commands are NODE-scoped, not cluster-scoped.** `qm list` and `pct
  list` report the node you are shelled into. In a cluster, a guest you cannot
  find is usually running on a different node, not gone. `pvesh get
  /cluster/resources` again, or `pvecm nodes` to see what else exists.

## Nodes and cluster

- Version / node status: `pveversion -v`, `pvesh get /nodes/<node>/status`
- Cluster membership and quorum: `pvecm status`, `pvecm nodes`
- Node resource pressure: `cat /proc/loadavg`, `free -h`, `df -h`, `pvesh get /nodes/<node>/rrddata --timeframe hour`
- All cluster resources at once: `pvesh get /cluster/resources` (VMs, CTs, storage, nodes in one call)
- Tasks (what the node is doing / did): `pvesh get /nodes/<node>/tasks`, logs: `pvesh get /nodes/<node>/tasks/<upid>/log`

## QEMU virtual machines (`qm`)

- Inventory: `qm list`
- State + config: `qm status <id> --verbose`, `qm config <id>`
- Guest agent (if installed): `qm guest cmd <id> get-osinfo`, `qm guest exec <id> -- <cmd>`
- Console/serial: `qm terminal <id>` (interactive; usually not needed)
- Lifecycle (confirm): `qm start|stop|shutdown|reboot|reset|suspend|resume <id>`
- Snapshots (confirm): `qm listsnapshot <id>`, `qm snapshot <id> <name>`, `qm rollback <id> <name>`, `qm delsnapshot <id> <name>`
- Clone / template (confirm): `qm clone <id> <newid>`, `qm template <id>`
- Migrate (confirm): `qm migrate <id> <target-node> --online`
- Cloud-init: `qm cloudinit dump <id> user`, set via `qm set <id> --ciuser ...`
- Disks: `qm config <id> | grep -E 'scsi|virtio|ide|sata'`, resize (confirm) `qm resize <id> <disk> +<size>G`

## LXC containers (`pct`)

- Inventory: `pct list`
- State + config: `pct status <id>`, `pct config <id>`
- Run inside a container: `pct exec <id> -- <cmd>`
- Lifecycle (confirm): `pct start|stop|shutdown|reboot <id>`
- Snapshots (confirm): `pct listsnapshot <id>`, `pct snapshot <id> <name>`, `pct rollback <id> <name>`
- Clone (confirm): `pct clone <id> <newid>`
- Templates available: `pveam list <storage>`, update list `pveam update`

## Storage (`pvesm`)

- Overview + usage + health: `pvesm status`
- Backends supported: dir, LVM, LVM-thin, ZFS, ZFS-over-iSCSI, NFS, CIFS/SMB, CephFS, RBD, Proxmox Backup Server (PBS)
- Content of a store: `pvesm list <storage>`
- Path for a volume: `pvesm path <volid>`
- Add/remove storage (confirm): `pvesm add|remove ...`

## Backups

- Manual backup (confirm): `vzdump <id> --storage <store> --mode snapshot`
- Scheduled jobs: `cat /etc/pve/jobs.cfg`, `pvesh get /cluster/backup`
- Restore (confirm, creates/overwrites): `qmrestore <archive> <newid>` / `pct restore <newid> <archive>`
- If PBS is used: `proxmox-backup-client snapshot list`, `proxmox-backup-manager ...`

## High availability

- State: `ha-manager status`
- Resources/groups: `ha-manager config`, `pvesh get /cluster/ha/resources`
- Manage (confirm): `ha-manager add|remove|set vm:<id>`

## Networking and SDN

- Interfaces/bridges/bonds/VLANs: `cat /etc/network/interfaces`, `ip -br addr`, `ip -br link`
- Apply pending net changes (confirm): `ifreload -a`
- SDN (if used): `pvesh get /cluster/sdn`

## Firewall

- Status: `pve-firewall status`
- Rules: `cat /etc/pve/firewall/cluster.fw`, `cat /etc/pve/firewall/<vmid>.fw`
- Enable/disable (confirm): edit fw files or `pve-firewall ...`

## Replication (storage-level, ZFS)

- Jobs + state: `pvesr status`, `pvesr list`
- Run now (confirm): `pvesr run --id <jobid>`

## Users, roles, ACLs (`pveum`)

- Users/roles/ACL: `pveum user list`, `pveum role list`, `pveum acl list`
- API tokens: `pveum user token list <user>`

## Logs

- Core services: `journalctl -u pvedaemon -u pveproxy -u pve-cluster -n 100 --no-pager`
- Storage/kernel: `dmesg -T | tail -50`, `journalctl -k -n 80 --no-pager`

## What Proxmox cannot tell you

The hypervisor sees guests from the outside. It does NOT know:

- what is happening INSIDE a VM - whether the app is up, what its logs say -
  unless the guest agent is installed, and then only what `qm guest exec`
  reaches. For a guest that is itself a registered host, `hh run` on that host
  is the better tool.
- the health of the hardware under a storage pool that Proxmox did not create
  (a NAS exporting NFS, a SAN). `pvesm status` reports the store as Proxmox
  sees it, which is not the same as the array being healthy.
- anything about the network fabric, the mesh, or ingress. A guest that is up
  and unreachable is usually not a Proxmox problem - see network-diag.

Say which of these you actually established. "The VM is running" and "the
service is up" are different claims and only one of them is visible here.

## Performance

- `pveperf` (CPU/disk/fsync benchmark), `iostat -x 1 3` (if sysstat present)
