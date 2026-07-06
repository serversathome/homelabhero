# Linux host - capability catalog

For any generic Linux box (Debian/Ubuntu/RHEL family) reached via
`hh run <alias> "..."`. Read side first; writes need confirmation.

## Identity and load

- OS/release: `cat /etc/os-release`, `uname -a`, `hostnamectl`
- Uptime/load: `uptime`, `cat /proc/loadavg`
- CPU/memory: `lscpu`, `free -h`, `vmstat 1 3`
- Top consumers: `ps aux --sort=-%cpu | head`, `ps aux --sort=-%mem | head`

## Services (systemd)

- Running services: `systemctl list-units --type=service --state=running`
- Failed units (fast health check): `systemctl --failed`
- One service: `systemctl status <svc>`, logs `journalctl -u <svc> -n 100 --no-pager`
- Boot time / analyze: `systemd-analyze`, `systemd-analyze blame | head`
- Control (confirm): `systemctl start|stop|restart|enable|disable <svc>`

## Storage and filesystems

- Block devices: `lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,MODEL,SERIAL`
- Usage: `df -h`, `du -xh --max-depth=1 / 2>/dev/null | sort -h | tail`
- Mounts / fstab: `findmnt`, `cat /etc/fstab`
- LVM (if used): `pvs`, `vgs`, `lvs`
- SMART (if smartmontools): `smartctl -H /dev/<disk>`
- Resize/mount/format (confirm; format is destructive): `mount`, `resize2fs`, `mkfs.*`

## Networking

- Addresses/links/routes: `ip -br addr`, `ip -br link`, `ip route`
- Listening sockets (what is exposed): `ss -tulpn`
- DNS: `resolvectl status | head -30`, `dig <name>`
- Connectivity: `ping -c3 <host>`, `curl -sSI <url>`
- NetworkManager (if present): `nmcli device`, `nmcli connection`
- Firewall: `ufw status` / `nft list ruleset` / `iptables -S`

## Packages and updates

- Debian/Ubuntu: `apt list --installed 2>/dev/null | wc -l`, upgradable `apt list --upgradable`
- RHEL family: `dnf list installed | wc -l`, `dnf check-update`
- Update (confirm): `apt-get update && apt-get -y upgrade` / `dnf -y upgrade`

## Containers (if Docker/Podman present)

- Detect: `command -v docker || command -v podman`
- Running: `docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'`
- Logs/stats: `docker logs --tail 100 <c>`, `docker stats --no-stream`
- Compose stacks: `docker compose ls`, `cd <dir> && docker compose ps`
- Lifecycle (confirm): `docker restart <c>`, `docker compose up -d`

## Virtualization (if libvirt/KVM)

- Detect: `command -v virsh`
- Guests: `virsh list --all`
- Lifecycle (confirm): `virsh start|shutdown|reboot <dom>`

## Logs and diagnostics

- Journal (recent + errors): `journalctl -n 100 --no-pager`, `journalctl -p err -b --no-pager`
- Kernel: `dmesg -T | tail -60`
- Auth/security: `journalctl -u ssh -n 50 --no-pager`, `lastlog | head`

## Hardware

- `lspci`, `lsusb`, `dmidecode -t system` (may need root), `sensors` (if lm-sensors)
