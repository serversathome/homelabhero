# TrueNAS SCALE

Reached over SSH as `truenas`. Bare-metal NAS, primary storage for the homelab,
and host for a set of Docker apps plus the monitoring stack.

## Fill me in

- Pool name(s): `<tank | ...>`
- Key datasets and what lives on them: `<...>`
- Apps runtime (native Docker apps vs custom compose): `<...>`
- TrueNAS version and VM/container backend: `<e.g. 25.10 = Incus (virt.instance),
  27 (and the 26 betas) = libvirt (vm.* + libvirt_lxc), 24.10 = libvirt VMs only>`
- Replication targets / schedule: `<...>`
- SMART / scrub schedule: `<...>`

## Health check must-dos

A green pool is not a green box. `zpool status`, `smartctl`, and
`midclt call alert.list` report the storage and middleware view, but they are
blind to a whole class of hardware and kernel faults that only surface in the
kernel ring buffer: PCIe AER (bus / HBA errors), NIC link flaps, ATA/SATA/SAS
disk resets and link downshifts, machine-check exceptions (MCE), and OOM kills.
A NAS can show every pool ONLINE while its HBA throws AER corrections or a disk
silently resets on its SATA link.

So never declare TrueNAS healthy without also scanning the kernel log:

    hh run truenas "journalctl -k -b -p warning --no-pager | grep -viE 'veth|br-[0-9a-f]{12}' | tail -40"

That is kernel messages (`-k`), this boot only (`-b`), warning and above (`-p
warning`), with Docker veth/bridge link churn filtered out - that noise is normal
on an app host and would otherwise bury the real signal. Empty output is the
pass. Any AER / MCE / ATA-reset / link-down / OOM line is a real finding: pivot
to the matching subsystem (HBA/PCIe, NIC, the named disk, memory) before touching
anything or reporting green.

## Pool and dataset health

    hh run truenas "zpool status -x"            # one-line all-healthy check
    hh run truenas "zpool status -v"            # full detail incl. errors
    hh run truenas "zpool list"                 # capacity and health
    hh run truenas "zfs list -o name,used,avail,refer,mountpoint"
    hh run truenas "zpool get capacity,health,fragmentation <pool>"

## Disks and SMART

    hh run truenas "lsblk -o NAME,SIZE,MODEL,SERIAL,TYPE"
    hh run truenas "smartctl -a /dev/<disk>"
    hh run truenas "smartctl -H /dev/<disk>"    # quick health verdict

## Middleware (the TrueNAS API from the shell)

`midclt` calls the same middleware the web UI uses. Prefer read calls.

    hh run truenas "midclt call system.info"
    hh run truenas "midclt call pool.query | jq '.[].name'"
    hh run truenas "midclt call app.query | jq '.[] | {name, state}'"
    hh run truenas "midclt call alert.list | jq '.[] | {level, formatted}'"
    hh run truenas "midclt call replication.query | jq '.[] | {name, state: .state.state}'"

## Scrubs and snapshots (state-changing, confirm first)

    hh run truenas "zpool scrub <pool>"                 # kick off a scrub
    hh run truenas "zfs snapshot <pool>/<dataset>@<name>"
    # Destructive. Never without explicit go-ahead:
    #   zfs destroy, zpool destroy, zpool offline/replace, disk wipe

## Virtualization backend changed by version

TrueNAS moved its VM/container engine twice, so how you inspect and drive VMs
and containers depends on the release. Never assume the method names.

- 24.10 (Electric Eel) and earlier: libvirt + QEMU/KVM VMs only, no containers.
  Middleware namespace `vm.*` (`vm.query`, `vm.start`, `vm.stop`).
- 25.04 (Fangtooth) and 25.10 (Goldeye): Incus, for both LXC containers and VMs.
  Namespace `virt.instance.*` (the `type` field is CONTAINER or VM), plus
  `virt.global.config` for the instances pool. Instance disks are zvols in a
  hidden `.ix-virt` dataset on that pool.
- 27 (pre-release; its betas were numbered 26): Incus removed, replaced by
  libvirt driving QEMU/KVM VMs (`vm.*`) and
  libvirt_lxc containers. The upgrade migrates `.ix-virt` Incus zvols into
  libvirt VM definitions.

Detect first, then act:

    hh run truenas "midclt call system.version"
    hh run truenas "midclt call core.get_methods | python3 -c \"import json,sys;[print(k) for k in sorted(json.load(sys.stdin)) if k.split('.')[0] in ('vm','virt','container')]\""

Full command set is in capabilities/truenas.md ("Virtualization"); use the
truenas-middleware skill to read live method schemas when a name is unclear.

## Known gotchas

- 27 (or 26 beta) upgrade from an Incus release (25.04/25.10): expect surprises during the
  Incus-to-libvirt migration. Reported cases: LXCs orphaned (left in hidden
  dirs), VMs that disappear from the UI while their zvols survive under
  `.ix-virt`, legacy "Containers"-screen VMs that no longer autostart, and
  libvirt_lxc containers failing to start on a filesystem-mount error. The data
  (zvols under `.ix-virt`) is usually intact even when the instance vanishes, so
  do NOT destroy anything to "clean up" - reattach the existing zvol to a new
  libvirt VM/container definition instead. Confirm recoverability first.
- `<record recurring issues here, e.g. an app that loses its dataset mount after
  reboot, a disk that throws CRC errors on a specific SATA port, scrub timing
  that collides with backups>`
