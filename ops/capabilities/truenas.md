# TrueNAS SCALE - capability catalog

Everything runs through `hh run <truenas-alias> "..."`. `midclt call <method>`
reaches the same middleware API the web UI uses; prefer read methods and pipe
through `jq`. Lead with the read side; writes are marked and need confirmation.

This catalog covers the common methods. For anything beyond it (the full
method list, exact names, or parameter schemas), use the truenas-middleware
skill to read the live surface off the box instead of guessing.

## System

- Info / version / uptime: `midclt call system.info`
- General config: `midclt call system.general.config`
- Alerts (the fastest "is anything wrong"): `midclt call alert.list | jq '.[] | {level, formatted}'`
- Services and their state: `midclt call service.query | jq '.[] | {service, state, enable}'`
- Updates: `midclt call update.check_available`, apply (confirm) via `update.update`
- Boot environments: `midclt call bootenv.query | jq '.[] | {id, active}'`

## ZFS storage

- Pools + health + capacity: `zpool list`, `zpool status -x`, `zpool status -v`
- Datasets/zvols: `zfs list -o name,used,avail,refer,mountpoint,compression`
- Dataset detail: `zfs get all <pool>/<dataset>`
- Snapshots: `zfs list -t snapshot -o name,used,creation -s creation`
- Snapshot usage (find hidden consumers): `zfs list -t snapshot -o name,used -s used | tail`
- ARC / cache stats: `arcstat 1 3` (if present), `cat /proc/spl/kstat/zfs/arcstats | head`
- Create/scrub (confirm): `zpool scrub <pool>`, `zfs snapshot <pool>/<ds>@<name>`
- Destructive (never without explicit go-ahead): `zfs destroy`, `zpool destroy`, `zpool offline|replace`
- Via middleware too: `midclt call pool.query`, `midclt call pool.dataset.query`

## Disks and SMART

- Physical map: `lsblk -o NAME,SIZE,MODEL,SERIAL,TYPE,ROTA`
- Middleware disk view: `midclt call disk.query | jq '.[] | {name, serial, size, model}'`
- Health verdict: `smartctl -H /dev/<disk>`
- Full attributes / errors: `smartctl -a /dev/<disk>`
- Enclosure / temperatures: `midclt call disk.temperatures`

## Sharing

- SMB: `midclt call sharing.smb.query | jq '.[] | {name, path, enabled}'`
- NFS: `midclt call sharing.nfs.query | jq '.[] | {path, enabled, networks}'`
- iSCSI (targets/extents/portals): `midclt call iscsi.target.query`, `iscsi.extent.query`, `iscsi.portal.query`
- Active SMB sessions: `midclt call smb.status` (if available), or `smbstatus`

## Apps (Docker-based on SCALE)

- Installed apps + state: `midclt call app.query | jq '.[] | {name, state, version: .version}'`
- App detail: `midclt call app.get_instance <name>`
- Underlying containers: `docker ps --format '{{.Names}}\t{{.Status}}'` (SCALE runs Docker)
- Container logs: `docker logs --tail 100 <container>`
- Start/stop an app (confirm): `midclt call app.start <name>` / `app.stop <name>`
- Catalog / available apps: `midclt call catalog.query`

## Virtualization (Incus/KVM instances)

- Instances: `midclt call virt.instance.query | jq '.[] | {name, type, status}'`
  (older releases: `midclt call vm.query`)
- Start/stop (confirm): `midclt call virt.instance.start <name>` / `.stop`

## Data protection

- Replication tasks + state: `midclt call replication.query | jq '.[] | {name, state: .state.state}'`
- Cloud sync tasks: `midclt call cloudsync.query | jq '.[] | {description, enabled}'`
- Rsync tasks: `midclt call rsynctask.query`
- Periodic snapshot tasks: `midclt call pool.snapshottask.query`
- Run a replication now (confirm): `midclt call replication.run <id>`

## Users, groups, directory services

- Local users/groups: `midclt call user.query | jq '.[] | {username, uid}'`, `group.query`
- Directory services (AD/LDAP): `midclt call activedirectory.get_state`, `ldap.get_state`

## Networking

- Interfaces / config: `ip -br addr`, `midclt call interface.query | jq '.[] | {name, state}'`
- Static routes / DNS: `midclt call network.configuration.config`
- Link speed (10GbE sanity): `ethtool <iface> | grep -i speed`

## Certificates

- Certs: `midclt call certificate.query | jq '.[] | {name, common: .common}'`

## Logs

- Middleware: `tail -100 /var/log/middlewared.log`
- System: `journalctl -n 100 --no-pager`, `dmesg -T | tail -50`
