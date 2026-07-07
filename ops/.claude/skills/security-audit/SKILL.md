---
name: security-audit
description: >
  Read-only security-posture review of a managed host or the whole estate:
  pending updates, listening services and open ports, SSH hardening, user
  accounts and sudo, failed logins, firewall state, and platform-specific
  exposure. Use whenever Evan asks to audit, harden, or security-check a box, or
  asks "is this exposed", "what ports are open", "any security issues", "are we
  patched", or wants a hardening review. Diagnose and report first; propose fixes
  and get an explicit go-ahead before changing anything.
---

# Security audit

Read-only first. Sweep a host (or all hosts) for common exposure, report findings
ranked by risk, then propose hardening for the user to approve. Everything runs
through `hh run <alias> "<command>"`; on non-root hosts prefix privileged checks
with `sudo -n` (see CLAUDE.md). Change nothing without an explicit go-ahead - this
is diagnosis.

## Checks (per host)

Patching:

    apt-get -s upgrade 2>/dev/null | grep -c ^Inst      # Debian/Ubuntu/Proxmox: count
    apt list --upgradable 2>/dev/null | tail -n +2      # what, specifically
    # TrueNAS: midclt call update.check_available

Listening services / exposure (the highest-signal check):

    sudo -n ss -tulpn                                   # what listens, on which IPs
    # Flag anything bound to 0.0.0.0 / :: that should be LAN- or localhost-only.

SSH hardening:

    sudo -n sshd -T 2>/dev/null | grep -Ei \
      'permitrootlogin|passwordauthentication|pubkeyauthentication|permitemptypasswords'
    # Want: PermitRootLogin no|prohibit-password, PasswordAuthentication no,
    #       PubkeyAuthentication yes, PermitEmptyPasswords no.

Accounts and privilege:

    awk -F: '$3==0{print $1}' /etc/passwd               # UID-0 accounts (expect only root)
    getent passwd | awk -F: '$7 ~ /(bash|sh|zsh)$/{print $1}'   # login shells
    sudo -n awk -F: '($2==""){print $1}' /etc/shadow    # empty passwords (should be none)
    sudo -n cat /etc/sudoers /etc/sudoers.d/* 2>/dev/null | grep -v '^#'  # broad NOPASSWD?

Intrusion signals:

    sudo -n lastb 2>/dev/null | head                    # failed logins
    sudo -n grep -iE 'fail|invalid user' /var/log/auth.log 2>/dev/null | tail

Firewall (is anything actually filtering?):

    sudo -n nft list ruleset 2>/dev/null || sudo -n iptables -S 2>/dev/null || ufw status

## Platform specifics

- Proxmox: web UI on 8006 - who can reach it? `pveum user list`, is 2FA on, is the
  Datacenter/Node firewall enabled?
- TrueNAS: exposed shares (SMB/NFS/iSCSI) and the UI on 443; `midclt call
  user.query` for accounts; is root login disabled and 2FA on? Use the
  truenas-middleware skill for method details.
- Docker hosts: containers publishing to 0.0.0.0, running as root, or
  `--privileged`: `docker ps` then `docker inspect` the suspicious ones.

## Report, then propose

1. Rank findings by severity - service exposed on 0.0.0.0 or password SSH = high;
   missing updates or broad sudo = medium; cosmetic = low - and cite the evidence
   (the command output) for each.
2. Propose specific, minimal fixes; for each say what it changes and the risk of
   applying it.
3. Change nothing until the user approves. Then apply, re-check, and if it was a
   real remediation, add a runbook entry.

Note: the HomelabHero control plane has its own deliberate posture (the
privilege-separated broker, the vault, the narrow sudoers rule). Auditing it is
fine, but do not "fix" a finding by weakening the vault, broker, or sudoers - that
separation is intentional (see the top-level README and CLAUDE.md).
