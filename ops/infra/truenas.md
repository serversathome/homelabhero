# TrueNAS SCALE

Reached over SSH as `truenas`. Bare-metal NAS, primary storage for the homelab,
and host for a set of Docker apps plus the monitoring stack.

## Fill me in

- Pool name(s): `<tank | ...>`
- Key datasets and what lives on them: `<...>`
- Apps runtime (native Docker apps vs custom compose): `<...>`
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

## Known gotchas

- `<record recurring issues here, e.g. an app that loses its dataset mount after
  reboot, a disk that throws CRC errors on a specific SATA port, scrub timing
  that collides with backups>`
