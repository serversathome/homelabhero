# Updating, auto-updates and health

What `hh update` does, what runs weekly on its own, and how to check the box is well.

[← back to the README](../README.md)

## Auto-updates and health


One command does everything. A weekly cron job (`/etc/cron.d/homelabhero`, Sundays at
04:00) runs `hh update`, logging to `/var/log/homelabhero-update.log`. Edit that one
file to change the schedule, or delete it to turn auto-update off. Run it any time with
`hh update`.

`hh update` does three things in order:

1. **Update HomelabHero itself** (see below).
2. **Update the OS packages** (`apt`).
3. **Run a health check** (`hh doctor`).

### Staying up to date with HomelabHero itself

For step 1, `hh update` `git pull`s the branch you installed from (`main` unless you
changed it) and **re-runs the installer non-interactively** - so an update produces
exactly what a fresh install does:
the `hh` CLI and broker, the shipped skills / `CLAUDE.md` / capability docs, Node and
npm at the latest LTS, the Claude Code + claudecodeui packages (reinstalled with the
correct `--allow-scripts` set so their native modules always build), and the systemd
unit. Improvements and fixes pushed to the repo reach existing boxes on their own;
nobody has to re-run the installer by hand.

Because it re-runs the real installer, there is no "some changes only the installer can
apply" gap - `hh update` **is** the installer, plus the OS pass. Node tracks the latest
LTS automatically each week.

What it will and will not touch is deliberate:

- **Refreshed** (HomelabHero-owned): the CLI binaries, `.claude/skills/`,
  `.claude/settings.json`, `CLAUDE.md`, `capabilities/`, the logrotate/sudoers/service
  templates, and the Node/npm stack.
- **Never touched** (yours): `CLAUDE.local.md`, your environment notes under `infra/`,
  `inventory/`, `runbooks/`, `hosts/`, your edited cron schedule, and `cloudcli.env`.
  Your own custom skills in `.claude/skills/` are preserved too.

**Your edits to a shipped file are not overwritten.** HomelabHero keeps a pristine
copy of what it last delivered, under `/etc/homelabhero/shipped/`, and compares three
ways on every update - the same way `dpkg` handles a config file:

| your file vs. last shipped | upstream changed? | what happens |
|---|---|---|
| unchanged | yes | the update lands, silently |
| you edited it | no | left alone, silently |
| you edited it | yes | **your copy is kept**; the new one is written beside it as `<file>.upstream` and named in the update output |

Nothing is overwritten without saying so, and nothing is deleted. `hh doctor` reports
how many shipped files you have edited and whether any `.upstream` versions are
waiting to be merged.

The first update after this behaviour shipped is the one that has no pristine copy to
compare against yet. The installer handles it by seeding one from the revision your box
was already running, recovered from the checkout, so that update is exact too: untouched
files take it silently and only your real edits are flagged. If that revision cannot be
recovered - a re-cloned checkout, or a hand-run installer with no pull behind it - the
update still lands and your previous file is saved as `<file>.bak-<timestamp>` first, so
nothing is lost either way.

The baseline holds only the files HomelabHero ships. Your notes under `infra/`,
`inventory/`, `runbooks/` and `hosts/` are not in it and are not compared, so editing
them - which is what they are for - never shows up as a modified shipped file.

Even so, the best home for local additions is **`CLAUDE.local.md`**, which `CLAUDE.md`
imports and the installer never touches. Put your name, your house rules, and pointers
to your own docs there and there is nothing to merge, ever. The ops brain is also a git
repo, so `git -C ~hhagent/homelab-ops diff` still shows what an update changed.

Because an update can occasionally break something, `hh doctor` checks the whole
chain in one pass: the users, the broker, vault permissions, the service, Claude's
version, every host's reachability, and the last update result. Run it any time; the
auto-update runs it for you after each update.
