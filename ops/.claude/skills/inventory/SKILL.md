---
name: inventory
description: >
  Build a complete live inventory of everything running across the homelab. Use
  this whenever Evan asks what is running, what VMs / LXCs / containers / apps
  exist, "what's on <host>", "give me the full picture", "what do I have",
  capacity of guests, or wants an audit of the whole estate. Also use it as the
  grounding step before any change so you are working from current truth, not
  assumptions. Trigger it even when he does not say the word "inventory" but is
  clearly asking what exists or what is deployed where.
---

# Inventory

Goal: a current, accurate picture of every workload across every registered host.

## Get the live picture

    hh inventory            # everything, all hosts
    hh inventory <alias>    # one host
    hh inventory --save     # also snapshot into inventory/ for git history

`hh inventory` already knows how to enumerate each platform:

- Proxmox: VMs (`qm list`), LXCs (`pct list`), storage (`pvesm status`)
- TrueNAS: apps (`midclt call app.query`), instances/VMs, Docker containers, pools
- Linux: Docker/Podman containers, libvirt guests if present

## Go deeper when asked

For per-guest detail beyond the list, use the platform capability catalog and
`hh run`:

- A specific VM's config and resources: see capabilities/proxmox.md (`qm config`,
  `qm status --verbose`)
- What a container is doing: `hh run <host> "docker logs --tail 100 <name>"`
- App detail on TrueNAS: `hh run truenas "midclt call app.get_instance <name>"`

## Reporting

Present it grouped by host, then by type (VMs, containers, apps), with state and
key resources. Flag anything stopped or unhealthy. If `--save` was used, mention
the snapshot so state changes can be tracked in git over time.
