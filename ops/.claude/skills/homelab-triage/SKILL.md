---
name: homelab-triage
description: >
  Top-level triage and health-overview workflow for the homelab. Use this
  whenever Evan asks broad or symptom-first questions like "what's wrong",
  "is everything okay", "something's down", "the homelab feels slow", "give me
  an overview", "health check", "status of everything", or reports a problem
  without naming the layer. Also use it as the first step for any incident where
  the failing component is not yet obvious, before dropping into the
  host-specific skills. Reach for this even when Evan does not say the word
  "triage" but is clearly asking for a whole-system look or reporting a vague
  fault.
---

# Homelab triage

Purpose: quickly localize a problem to a layer, then hand off to the specific
skill. Do not fix blindly from here. Localize first.

## Step 1: get the wide view

Run the overview sweep. It is read-only and safe.

    hh overview

If you need the raw inventory first, `hh list` shows every registered host. To
spot-check one, `hh run <alias> "uptime; df -h /"`.

### Health check: never green without the kernel log

`hh overview` and the pool/SMART/alert views miss a class of hardware and kernel
faults - PCIe AER, NIC link flaps, ATA/disk resets, MCEs, and OOM kills. Before
you report the homelab (or any TrueNAS host) healthy, scan the kernel ring
buffer:

    hh run truenas "journalctl -k -b -p warning --no-pager | grep -viE 'veth|br-[0-9a-f]{12}' | tail -40"

Empty output is the pass. Any AER / MCE / ATA-reset / link-down / OOM line is a
real finding - localize it (Step 3) before declaring green. Same principle for
other hosts: a clean overview is not a clean dmesg. See "Health check must-dos"
in infra/truenas.md for the full rationale.

## Step 2: check reachability and DNS early

A surprising share of "everything is broken" reports are network, not the apps.

    ping -c2 <each host mesh ip>
    hh run <alias> "echo ok"
    netbird status

If a host answers on LAN but not on its mesh IP, treat it as a mesh problem and
go to network-diag, not the host skill.

## Step 3: localize by layer

Walk the escalation ladder from CLAUDE.md and pick the matching skill:

- A single app or download is broken, hosts fine -> docker-stack-ops
- A whole VM or container host is off or thrashing -> proxmox-ops
- Storage errors, pool degraded, dataset missing, disk failing -> truenas-ops
- Broad unreachability, DNS, mesh, tunnels, switch -> network-diag
- "What is running / what changed" across the estate -> inventory skill; run
  `hh diff` to see exactly what changed since the last saved snapshot (a recent
  change is often the cause)
- Need to restore, roll back, or verify a backup exists -> backup-restore

Not a fault but a "is this exposed / are we patched" question -> security-audit.

## Step 4: report before acting

Summarize what you found in plain terms: which layer, which host, the evidence,
and the single most likely cause. Propose the next diagnostic or the fix, and
wait for a go-ahead before anything state-changing.

## Step 5: after resolution

If this turned into a real incident, append a runbook entry (see
`runbooks/README.md`) so the next occurrence is faster.
