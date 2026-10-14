---
name: host-ops
description: >
  Troubleshoot and manage generic Linux hosts (anything that is not Proxmox or
  TrueNAS). Use this whenever the user points at a plain Linux server, VM, or
  container host by alias and asks about services, disk space, networking,
  updates, processes, or logs, or when a host is slow, down, or misbehaving. It
  drives systemd, packages, storage, and networking over SSH. Trigger this for
  any host-level work the Proxmox and TrueNAS skills do not cover.
---

# Host ops (Linux)

Confirm the target with `hh list`, then read `capabilities/linux.md` for the
full toolset (it is not loaded up front). Diagnose read-only first, then propose
changes and confirm before anything state-changing.

Hosts connect as root by default, so commands run bare. On a host registered
with a non-root user, root-only commands need `sudo -n`, which only works when
that user has passwordless sudo (`hh doctor` says, per host). When it does not,
do not work around it silently: say so, and give the user the one-time fix so
they can decide. From a root shell on that host:

    echo '<user> ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/homelabhero-<user>

The alternative is to re-register the host as root, which needs no sudo at all.

## Fast path

    hh run <alias> "systemctl --failed"                       # failed units first
    hh run <alias> "uptime; free -h; df -h"                   # pressure + space
    hh run <alias> "ss -tulpn"                                 # what is listening
    hh run <alias> "journalctl -p err -b --no-pager | tail -40"

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
