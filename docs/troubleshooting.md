# Troubleshooting

Every line `hh doctor` can print and what to do about it, then the install and
runtime failures that have actually happened, with their fixes. If a problem is
not here, [open an issue](https://github.com/serversathome/homelabhero/issues)
with the `hh doctor` output and the relevant log.

[← back to the README](../README.md)

## Start with hh doctor

    sudo hh doctor

Run it with sudo from an admin shell: without it, the Claude version and the
ops-brain checks say "fine if not run with sudo" instead of reporting. Each line
is `[ok]`, `[warn]` or `[FAIL]`; the `RESULT` line counts them. The agent can
run it too (it is allow-listed), so "run hh doctor" is a reasonable thing to say
in the web UI.

| line | meaning | fix |
|---|---|---|
| `missing user hhagent` / `hhvault` | the installer never finished step 2 | re-run the install one-liner |
| `broker missing at /usr/local/bin/hh-connect` | the CLI was installed without the brokers | `hh update` |
| `<name> broker missing ... (run: hh update)` | an integration broker predates this install | `hh update` |
| `vault perms are '...', expected '700 hhvault'` | something changed ownership of `/etc/homelabhero/vault` | `chown hhvault:hhvault /etc/homelabhero/vault && chmod 700 /etc/homelabhero/vault` |
| `broker audit log perms are ...` | same, for `/var/log/homelabhero-broker.log` | `chown hhvault:hhvault` and `chmod 600` it |
| `service homelab-cc not active` | the web UI is down | see [the web UI will not start](#the-web-ui-will-not-start) |
| `could not read claude version here` | normal without sudo; with sudo, claude is missing | see [Claude is missing](#claude-is-missing-or-the-ui-says-the-binary-is-not-found) |
| `N shipped file(s) edited locally` | informational: your edits are being kept | nothing |
| `N newer shipped version(s) waiting as *.upstream` | upstream changed a file you also edited | merge what you want from each `.upstream`, then delete it |
| `no CLAUDE.local.md yet` | box predates the local-notes file | `hh update` creates it |
| `no pristine copy at /etc/homelabhero/shipped yet` | first run under the 1.3.1 update rules has not happened | `hh update` once |
| `cannot reach <alias>` | SSH failed | see [a host cannot be reached](#a-host-cannot-be-reached) |
| `reach <alias> (<user>) - no passwordless sudo` | works, but root tools will not | see [reachable but no passwordless sudo](#reachable-but-no-passwordless-sudo) |
| `<alias> logs in with group full` (RouterOS) | the login can change the switch | make a `read`-group user if you want it read-only |
| `cannot reach <alias> over the <kind> API` | credential rejected, device offline or certificate changed | the `detail:` line names which; see the integration sections below |
| `<alias> has no TLS pin` (UniFi) | registered before pinning existed | `hh repin <alias>` |
| `no weekly auto-update job` | `/etc/cron.d/homelabhero` is gone | `hh update` reinstalls it, or restore the file |
| `last update ran N days ago` | the weekly job is not firing | check `systemctl status cron` and the log |
| `the last update run hit an installer error` | `hh update` stopped partway | see [the weekly update stopped partway](#the-weekly-update-stopped-partway) |

## Install failures

### The installer stops at once with "no new privileges"

The container has `no_new_privs` set, which stops sudo from gaining root, and
the broker runs through sudo. The message says which of two cases it is:

- **Set on PID 1**: the whole container is constrained. On Proxmox this does not
  happen by default. On TrueNAS, recreate the instance as privileged; if it
  still fails, run HomelabHero in a VM instead.
- **Set on this shell only**: the container is fine; the TrueNAS web shell and
  `lxc-attach` set the flag per session. Get a shell from PID 1 instead:
  `systemd-run --pty --quiet /bin/bash`, or SSH into the container. Do not
  recreate the container for this: it is not a container setting.

### "systemd not detected"

HomelabHero runs the web UI as a systemd service, so it needs a real LXC or VM
(Proxmox, TrueNAS Instances, or any Ubuntu/Debian VM). A Docker container is not
enough.

### The installer hangs at Claude's theme prompt

Seen once on Debian Trixie: the sign-in screen appears, the theme choice never
advances, and the login link never shows. Switching the LXC to Ubuntu resolved
it, and Ubuntu is what the installer is written for and tested on. If you are
already past install, `hh login` restarts the sign-in from a shell.

### The install one-liner was run as a sudo user and asked for a password twice

Normal: once for the installer, once when `hh scan --add` registers hosts. Run
as root on a fresh LXC to avoid both.

## Runtime failures

### The web UI will not start

    systemctl status homelab-cc
    journalctl -u homelab-cc -n 50 --no-pager

Three causes account for nearly every case:

- **Claude is missing** (the log says "native binary not found"): next section.
- **A native module failed to build** (the log mentions `better-sqlite3`,
  `node-pty` or `bcrypt`): npm blocked their install scripts. `hh update` re-runs
  the install with the right allow-list.
- **The port is taken** (`EADDRINUSE`): change `PORT=` in
  `/etc/homelabhero/cloudcli.env` and `systemctl restart homelab-cc`.

### Claude is missing, or the UI says the binary is not found

The npm package ships the real binary as a platform-specific optional
dependency, and on some boxes npm never resolves it: the install reports
success and leaves a `claude` that cannot run. Since 1.3.0 the installer
detects this and falls back to Anthropic's native installer, so the fix is:

    hh update

If that still ends without a working claude, install it by hand as the agent
user and run the update again; the installer finds a native install and keeps
it, on this run and every weekly run after:

    sudo -u hhagent -i bash -c 'curl -fsSL https://claude.ai/install.sh | bash'
    hh update

### The web UI is up but not reachable from the browser

- `hh doctor` says the service is active: check the address. The installer
  prints `http://<ip>:3001` as its last line; `ip -4 addr` on the LXC gives the
  IP, and `PORT=` in `/etc/homelabhero/cloudcli.env` gives the port.
- `HOST=127.0.0.1` in that file means it is deliberately bound to the LXC only;
  see [the port, and keeping the UI off the
  LAN](install.md#the-port-and-keeping-the-ui-off-the-lan).
- The LXC has a firewall or the host does: port 3001 TCP inbound.

### Claude asks to sign in, or the UI says it is not authenticated

    hh login

That starts Claude Code as the agent user from the ops brain; run `/login`
inside it, then `/exit`. Sign-in state lives in `~hhagent/.claude`, so it
survives updates.

### "cannot read CLAUDE.md" as hhagent, usually on TrueNAS

A ZFS/NFSv4 ACL inherited from the dataset denies the read even though the mode
bits say 644. The installer warns about this at step 6 and prints the fix:

    setfacl -R -m u:hhagent:rX /home/hhagent/homelab-ops

### The weekly update stopped partway

Before 1.6.1, every weekly run died at the sudoers step: cron starts jobs with
`PATH=/usr/bin:/bin`, and `visudo` lives in `/usr/sbin`. The CLI binaries still
updated, so `hh version` looked current while skills, Node and Claude stayed
old. To see whether a box was affected:

    grep -c "sudoers template failed" /var/log/homelabhero-update.log*

Any count above zero means it was. One manual `hh update` on 1.6.1 or later
fixes it for good, and `hh doctor` now reports an installer error in the last
run so a repeat cannot be silent. The log is at
`/var/log/homelabhero-update.log`; the previous week's is the `.1` file.

### A host cannot be reached

`hh test <alias>` tries the connection and says which side failed. In order of
likelihood:

- **The key is not authorized yet.** Registration printed the public key; it is
  still in the vault. Show it again and install it on the host:

      sudo cat /etc/homelabhero/vault/<alias>.key.pub

  Proxmox and Linux: `~/.ssh/authorized_keys` for the connect user. TrueNAS:
  the user's SSH keys in the web UI, and SSH itself enabled as a service.
  RouterOS: `/user ssh-keys import public-key-file=<file> user=<user>`.
- **The host key changed** (reinstalled host, same address). The broker accepts
  a host key on first contact and refuses a different one afterwards, exactly
  like SSH. Remove the stale line from the vault user's known hosts and test
  again:

      sudo -u hhvault ssh-keygen -R <host-or-ip> -f /home/hhvault/.ssh/known_hosts

- **Wrong user or port.** `hh list` shows what was registered. Fix it with
  `hh rm-host <alias>` and register again.
- **RouterOS**: the login works but the sweep showed UNREACHABLE before 1.6.0;
  `hh update`. Also make sure the entry has `PLATFORM=routeros`, not `linux`.

### Reachable but no passwordless sudo

The connect user is not root and cannot run `sudo -n`, so `midclt` on TrueNAS
still works but `docker`, `zpool` and `smartctl` do not. Either re-register the
host as root, or on TrueNAS: Credentials -> Users -> the user -> Edit -> "Allow
all sudo commands with no password".

### After an update, files ending in .upstream appeared

You edited a shipped file and upstream changed it too. Your copy was kept; the
new one is beside it. Merge what you want, then delete the `.upstream` file.
`hh doctor` counts them until you do. Put local notes in `CLAUDE.local.md` and
this never happens for them.

## Integrations

### UniFi: the key did not work

- The console must be UniFi OS on Network 9.0 or newer; API keys do not exist
  on the old self-hosted application.
- The whole key must be pasted; UniFi shows it once.
- `cannot reach ... (cert changed)` after a firmware update or installing your
  own certificate: `hh repin <alias>` accepts the new one. Until you do, calls
  fail closed on purpose.
- A key minted under a full admin works too, but then only HomelabHero's GET-only
  broker is keeping it from writing; mint it under a View Only admin.

### Firewalla: "is an IP address" at registration, or nothing comes back

Firewalla has no local API. Register your MSP domain (`yourname.firewalla.net`),
not the box's LAN address, and create the token under Account Settings in MSP.
With more than one box on the account, registration asks which one the alias
means; `hh firewalla boxes` lists them and marks the pinned one.

### NetBird: the token stopped working

NetBird tokens are created with an expiry. Create a new one under the same
service user, then `hh rm-host <alias>` and `hh add-netbird`. A self-hosted
server whose certificate you replaced wants `hh repin <alias>`. A read-only
alias refusing a write is not a failure: it was registered with the User role,
and the message says so.

### Cloudflare: "could not resolve an account" or empty tunnel lists

The token needs `Account Settings: Read` to list accounts, or at least one zone
it can see, from which the account is read instead. `hh cloudflare account`
shows what it resolved. Empty `records` means the token is scoped to other
zones than the one you asked about.

### A NetBird or Cloudflare write "refused" and printed a command

That is the confirmation step, not an error. The printed line is the same
command with `--force` added; run it to proceed. Nothing destructive ever
happens on the first try, and the refusal works in a non-interactive session
where a y/N prompt would not.

## Where the logs are

| log | what | who can read it |
|---|---|---|
| `/var/log/homelabhero-update.log` | every `hh update` run, including the installer's output | anyone |
| `/var/log/homelabhero-broker.log` | every brokered command and registration, with `--force` noted | `hhvault` only; `hh audit` shows it with sudo |
| `journalctl -u homelab-cc` | the web UI service | root |
