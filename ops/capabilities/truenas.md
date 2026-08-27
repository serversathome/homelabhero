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

## Virtualization (version-dependent - detect the backend first)

The VM/container backend changed twice, so the right method names depend on the
release. NEVER assume; read the version, then use the matching namespace. All of
this is over `midclt` on the local socket, which is unaffected by the REST API
removal in 26 - the SSH + midclt path stays valid on every version.

    hh run truenas "midclt call system.version"     # e.g. 24.10.2, 25.04.2, 25.10.1, 26.0-BETA.x
    # then confirm which namespaces actually exist on this box:
    hh run truenas "midclt call core.get_methods | python3 -c \"import json,sys;[print(k) for k in sorted(json.load(sys.stdin)) if k.split('.')[0] in ('vm','virt','container')]\""

Three eras, three backends:

- 24.10 (Electric Eel) and earlier - libvirt + QEMU/KVM VMs only, no containers.
  Namespace `vm.*`:
    `midclt call vm.query | jq '.[] | {id, name, status: .status.state}'`
    Start/stop (confirm): `midclt call vm.start <id>` / `midclt call vm.stop <id>`
    Devices: `midclt call vm.device.query`

- 25.04 (Fangtooth) and 25.10 (Goldeye) - Incus, for BOTH LXC containers and
  QEMU/KVM VMs (the "Containers" and "Virtual Machines" screens). Namespace
  `virt.instance.*`; the `type` field is `CONTAINER` or `VM`:
    `midclt call virt.instance.query | jq '.[] | {name, type, status}'`
    Start/stop (confirm): `midclt call virt.instance.start <name>` / `.stop`
    Global config (pool that holds instances): `midclt call virt.global.config`
    Also: `virt.device.query`, `virt.volume.query`
    Incus storage lives in a hidden `.ix-virt` dataset on the instances pool;
    zvols under it are the instance disks.

- 26 (beta) - Incus REMOVED, replaced by libvirt managing QEMU/KVM VMs and
  libvirt_lxc containers. VMs are managed through the `vm.*` namespace again;
  LXC containers through their own namespace (discover the exact name with the
  `core.get_methods` filter above - it is still shifting in beta). The upgrade
  migrates Incus `.ix-virt` zvols into libvirt VM definitions. Known beta
  pitfalls: orphaned LXCs, VMs that vanish from the UI while their zvols survive
  under `.ix-virt`, and libvirt_lxc mount/startup failures - see the gotchas in
  infra/truenas.md before touching a migrated instance.

When the method name is not obvious (especially on 26), use the
truenas-middleware skill to read the live surface and each method's schema rather
than guessing. Treat any `.start`/`.stop`/`.create`/`.update`/`.delete` as
state-changing and confirm first.

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

## What TrueNAS cannot tell you

- Whether a share is actually being USED, or by whom, beyond current
  connections. A dataset with no recent writes may be abandoned or may be a
  perfectly healthy archive; nothing here distinguishes them.
- Whether a SMART-passing disk is about to fail. SMART is evidence, not a
  verdict; report the attributes rather than a prediction.
- What an app's container is doing internally - `midclt call app.query` reports
  the app's state as the middleware sees it, which can be `RUNNING` while the
  service inside answers errors.
- Anything off this box: the network, the mesh, other hosts.

One caveat specific to this platform: the middleware (`midclt`) and the shell
can disagree, because the middleware reports intended configuration and the
shell reports what the kernel is actually doing. When they differ, say so rather
than picking whichever supports the answer you already had.

## Logs

- Middleware: `tail -100 /var/log/middlewared.log`
- System: `journalctl -n 100 --no-pager`, `dmesg -T | tail -50`
