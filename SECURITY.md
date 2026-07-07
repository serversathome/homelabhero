# Security Policy

HomelabHero puts an LLM agent in front of your infrastructure, so its security
model is the whole point of the project. This document summarizes that model and
explains how to report a problem.

## Reporting a vulnerability

Please report suspected vulnerabilities privately, **not** as a public issue:

- Use GitHub's private ["Report a vulnerability"](https://github.com/serversathome/homelabhero/security/advisories/new)
  advisory form, or
- email the maintainers at the address on the `serversathome` GitHub profile.

Include the affected version/commit, a description, and a proof of concept if you
have one. We aim to acknowledge reports within a week. Please give us a
reasonable window to ship a fix before any public disclosure.

## Threat model

HomelabHero assumes the **agent itself may be adversarial or hijacked** (prompt
injection, a compromised dependency, a bad model turn) and is built so that even
a fully hijacked agent cannot steal a credential.

Three OS users provide the boundary:

- your operator account: installs, registers hosts, holds sudo
- `hhagent`: runs Claude and the web UI, deliberately low-privilege
- `hhvault`: owns every credential (`/etc/homelabhero/vault`, mode 700)

`hhagent` cannot read anything `hhvault` owns and, via a single narrow sudoers
rule, may run **only** the two broker helpers (`hh-connect`, `hh-provision`) and
**only** as `hhvault`. The broker reads the key or password, opens the SSH
connection, and returns output; credential material never enters the agent's
context. The broker validates the alias, refuses loopback targets, and confirms
the credential path lives inside the vault.

Every brokered command and every provisioning event is written to
`/var/log/homelabhero-broker.log`, which is owned by `hhvault` and unreadable by
`hhagent`: a hijacked agent can neither read past activity nor erase its tracks.

### What the model protects

- Credential material never enters the LLM context and cannot be exfiltrated by
  the agent, because the OS will not let it read the vault or run anything but
  the broker as `hhvault`.

### What it explicitly does **not** do

- It does not restrict *what* Claude may run on a host it is already allowed to
  reach. That is handled by the approval prompts and the confirm-first rule in
  the ops brain (`ops/CLAUDE.md`) plus the permission posture in
  `ops/.claude/settings.json` — a separate, softer layer.
- The vault keys are stored unencrypted (they must be, for non-interactive
  automation). Their safety rests entirely on the `hhvault` user boundary, so
  **anything that copies the LXC filesystem copies the keys**: treat snapshots
  and backups of this LXC as secret material.
- The web UI (claudecodeui) is only as protected as you make it. By default it
  listens on all interfaces over plain HTTP; put it behind TLS / a reverse proxy
  / a VPN if the LAN is not fully trusted.

## Good operating practice

- Register hosts from a real admin shell, never the Claude web terminal, so a
  typed password never passes through an LLM-driven session. Prefer key auth.
- Keep the LXC updated (the weekly auto-update does this) and review
  `/var/log/homelabhero-broker.log` periodically.
- Give the broker's SSH keys the least privilege the task needs on each target.
