# Host registry (non-secret)

This folder is a placeholder in the repo. On an installed system the live
registry lives at `/etc/homelabhero/hosts.d/*.conf`, one file per host. Those
files hold only non-secret connection metadata that Claude is allowed to read:

    PLATFORM=proxmox
    HOST=10.10.0.11
    PORT=22
    USER=root
    AUTH=key
    CRED=pve1.key      # basename of the credential in the vault

API-reached platforms carry a few more non-secret keys, written at registration:

    PIN=sha256//...    # UniFi console or self-hosted NetBird: pinned TLS key
    WRITE=yes|no       # NetBird, Cloudflare: whether the token may change things
    SITE=... SITE_NAME=...   # UniFi: which site this alias reads
    GID=... BOX=...          # Firewalla: which box this alias reads
    ACCOUNT=...              # Cloudflare: account id, cached on first use

The actual credential (`pve1.key`) lives in `/etc/homelabhero/vault/`, owned by
the `hhvault` user, mode 700, and is NOT readable by the agent user that runs
Claude. Claude reaches hosts only through `hh run`, which calls the broker that
reads the vault on its behalf. Manage entries with `hh add-host` / `hh rm-host`,
never by hand-editing secrets.
