---
name: host-ops
description: >
  Troubleshoot and manage generic Linux hosts (anything that is not Proxmox or
  TrueNAS). Use this whenever Evan points at a plain Linux server, VM, or
  container host by alias and asks about services, disk space, networking,
  updates, processes, or logs, or when a host is slow, down, or misbehaving. It
  drives systemd, packages, storage, and networking over SSH. Trigger this for
  any host-level work the Proxmox and TrueNAS skills do not cover.
---

# Host ops (Linux)

Confirm the target with `hh list`, then read capabilities/linux.md for the full
toolset. Diagnose read-only first, then propose changes and confirm before
anything state-changing.

If `hh list` shows this host connects as a non-root user, prefix privileged
commands with `sudo -n` (process names in `ss -p`, some `journalctl`, service
restarts, package installs). It is harmless when the host connects as root, so
when in doubt include it. See CLAUDE.md.

## Fast path

    hh run <alias> "systemctl --failed"                       # failed units first
    hh run <alias> "uptime; free -h; df -h"                   # pressure + space
    hh run <alias> "sudo -n ss -tulpn"                        # what is listening (PIDs need root)
    hh run <alias> "sudo -n journalctl -p err -b --no-pager | tail -40"

## Common cases

- Service down: check status and logs, restart (confirm), re-verify.
- Disk full: find the heavy consumer with `du -xh --max-depth=1 /` before
  deleting anything. Never blind-delete.
- Unreachable: usually network-diag, not the host. Confirm with `hh test`.
- Broke after an update: check `systemctl --failed`, recent `journalctl -p err`,
  and whether a reboot is pending (`ls /var/run/reboot-required` on Debian/Ubuntu).

## Containers on the host

If it runs Docker, `hh run <alias> "docker ps"` and the docker-stack-ops skill
take over for container-level work.
