# Installing and adding machines

How to get HomelabHero onto a box, how to keep it current, and the two ways to
register the machines it will manage.

[← back to the README](../README.md)



On a fresh Ubuntu 26.04 LXC, run one command. (The installer is Ubuntu/Debian
only: it uses `apt`, `systemd`, and `visudo`. It has not been tested on other
distros.) A new LXC usually has only a root user and no curl, so this installs
curl first (drop the `apt` part if you already have curl; add `sudo` in front of
`apt` if you run as a non-root user):

    apt update && apt install -y curl && \
      curl -fsSL https://raw.githubusercontent.com/serversathome/homelabhero/main/install.sh | bash

Then just answer the prompts. The script installs everything, walks you through
signing Claude in once, finds and adds your servers, and finishes by handing you
a browser link.

When it finishes, open the web UI in your browser on **port 3001**:

    http://<your-lxc-ip>:3001

The installer prints that exact address with the IP filled in as its last line.
(3001 is the default; if you changed `PORT=` in `/etc/homelabhero/cloudcli.env`,
use that port instead.) On your first visit, create your web login, open the
`homelab-ops` project, and — if it asks — click the gear icon and turn tools on.

From that point on you live in the web UI and talk to Claude in plain language
("how is everything doing", "what's running", "restart jellyfin"). You do not
need to remember any commands.

The `hh` commands below still exist for power users and are available in the web
UI's built-in terminal, but the normal experience is the browser.

### Updating to the latest code

You do not have to do anything. Updates arrive on their own: the weekly job runs
`hh update`, and you can run it yourself any time to force the latest right now:

    hh update

That is the one command. It pulls the latest HomelabHero, re-runs the installer
non-interactively to refresh everything (CLI and broker, skills, `CLAUDE.md`,
capability docs, Node/npm at the latest LTS, the Claude Code + claudecodeui
packages, the service), then patches the OS and runs a health check. It is a
**reinstall, not a reconfigure** and fully idempotent: it keeps your users, your
credentials, your registered hosts (your `hh list` is left exactly as-is), and
your ops notes, and skips Claude sign-in if you are already signed in. See
[Staying up to date](#staying-up-to-date-with-homelabhero-itself) for exactly
what it does and does not touch.

If you are onboarding a box that predates self-update (no
`/etc/homelabhero/install.conf`), run the install one-liner once to enable it,
after which `hh update` maintains it:

    apt update && apt install -y curl && \
      curl -fsSL https://raw.githubusercontent.com/serversathome/homelabhero/main/install.sh | bash

To see which version you are on and what changed between releases:

    hh version

[CHANGELOG.md](../CHANGELOG.md) explains every release: what was added, what
changed, and anything worth knowing before you update.



`hh scan` sweeps your subnet (auto-detected, or pass a CIDR) for live management
endpoints and guesses what each is (Proxmox on 8006, SSH on 22, and so on), marking
which are already registered. `hh scan --add` turns that into a picker: choose the
numbers you want and it walks you through registering each, pre-filling the address
and platform.

It also looks for your **router**. Anything sitting at your default gateway or at
the `.1` of the subnet (`192.168.1.1`, `10.99.0.1`, and so on) gets fingerprinted,
and a UniFi console is identified by name and version:

    #    IP               OPEN PORTS           GUESS            ROLE      REGISTERED?
    1    10.99.0.1        22,80,443            unifi            gateway   new
    2    10.99.0.20       22,443               truenas?/linux   -         registered

    Found your router: a UniFi OS console running Network 9.0.114 at 10.99.0.1

Pick it during install (step 10) or any time after, and it registers with an API
key instead of SSH. This is the router integration below.



You do not have to shell in to add machines. Just ask Claude in the browser, e.g.
"add my TrueNAS at 10.0.0.20". Claude runs `hh provision`, which registers the
host and generates a keypair in the vault, then hands you the public key to paste
into the target's admin UI (TrueNAS user SSH keys, Proxmox authorized_keys, or a
Linux authorized_keys). No password ever passes through the chat, and the agent
never sees the private key. `hh test <alias>` confirms it once the key is
installed. Password-based onboarding stays in the shell-only `hh add-host` for an
admin, since a password can't be handled safely in an LLM session.
