# Proxmox VE - capability catalog

Everything below runs through `hh run <pve-alias> "..."`. This is the full
surface of what a Proxmox node can do and how to inspect or drive each part.
Lead with the read side; the write side is marked and needs confirmation.

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

## Performance

- `pveperf` (CPU/disk/fsync benchmark), `iostat -x 1 3` (if sysstat present)
