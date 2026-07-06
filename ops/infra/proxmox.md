# Proxmox VE

Reached over SSH as `pve1` (and `pve2` if present). Root shell, so the full
`qm` / `pct` / `pvesm` / `pvecm` toolset is available.

## Fill me in

- Node names and mesh IPs: `<pve1>`, `<pve2>`
- Cluster or single node: `<single | cluster>`
- Local storage layout (LVM-thin, ZFS, directory): `<...>`
- Important VMIDs / CTIDs and what they run: `<e.g. 100 = TrueNAS-adjacent, 101 = docker host>`
- Where the command-center LXC itself lives (VMID): `<...>`

## Everyday commands

    hh run pve1 "pvesh get /version"           # API reachable, version
    hh run pve1 "qm list"                       # VMs on this node
    hh run pve1 "pct list"                      # LXC containers
    hh run pve1 "pvesm status"                  # storage pools and usage
    hh run pve1 "pvecm status"                  # cluster quorum (if clustered)
    hh run pve1 "ha-manager status"             # HA resource state (if used)

## Lifecycle (state-changing, confirm first)

    hh run pve1 "qm start <vmid>"   / "qm stop <vmid>"   / "qm reboot <vmid>"
    hh run pve1 "pct start <ctid>"  / "pct stop <ctid>"  / "pct reboot <ctid>"
    hh run pve1 "qm snapshot <vmid> <name>"     # snapshot before risky changes
    hh run pve1 "vzdump <vmid> --storage <backupstore>"   # manual backup

## Health and logs

    hh run pve1 "journalctl -u pveproxy -u pvedaemon -n 100 --no-pager"
    hh run pve1 "systemctl status pve-cluster pvedaemon pveproxy"
    hh run pve1 "cat /proc/loadavg && free -h && df -h /"
    hh run pve1 "qm status <vmid> --verbose"

## Known gotchas

- `<record recurring issues here, e.g. a VM that needs a specific boot order,
  a node that runs hot under backup, a storage that fills during vzdump>`
