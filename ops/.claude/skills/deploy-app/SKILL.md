---
name: deploy-app
description: >
  Stand up a NEW containerized app or compose stack on a docker host. Use
  whenever Evan wants to deploy, install, add, spin up, or "set up" a new
  container or stack (Jellyfin, Radarr, Sonarr, qBittorrent, Immich, a new arr
  app, a dashboard, etc.), or add a service to an existing stack. For fixing or
  operating an app that already exists, use docker-stack-ops instead; for
  updating images, use patch-management.
---

# Deploy a new app / stack

Adding or starting containers is state-changing: propose the compose, confirm,
then bring it up.

## First, learn THIS homelab's layout - do not assume

Read `infra/docker-stacks.md` for the host alias, which compose model is in use,
the pool name, and the config/media paths. There are a few common structures and
this homelab may use any of them:

- **Single compose file** - one `/mnt/<pool>/docker/docker-compose.yml` holding
  every service; per-app config at `/mnt/<pool>/configs/<app>`; a single
  `/mnt/<pool>/media` mount.
- **Per-stack (Dockge)** - `/opt/stacks/<stack>/compose.yaml`, with the app's
  volumes kept inside the stack directory.
- **Portainer** - stacks pasted/edited in the Portainer UI.

If `infra/docker-stacks.md` does not say, ask which one before writing paths.

## A common convention worth knowing (the "servers@home" / TrueNAS *arr layout)

This is one widely used structure, not the only correct one - match what the box
actually uses:

- One `media` dataset with **subdirectories** `movies`, `tv`, `downloads` (a
  single mount so the *arr apps can **hardlink** instead of copying); one
  `configs` dataset with a **sub-dataset per app**.
- Volumes: `/mnt/<pool>/configs/<app>:/config` and `/mnt/<pool>/media:/media`.
- `PUID`/`PGID`: **568/568** on TrueNAS (the `apps` group); commonly **1000/1000**
  on Ubuntu/Proxmox hosts. Always set `TZ`. Dataset perms `770`, no spaces or
  capitals in names.
- Images: `lscr.io/linuxserver/<app>` or `ghcr.io/hotio/<app>`; `restart:
  unless-stopped`; ports as `HOST:CONTAINER`.

Service template:

    services:
      radarr:
        image: lscr.io/linuxserver/radarr:latest
        container_name: radarr
        environment:
          - PUID=568
          - PGID=568
          - TZ=America/New_York
        volumes:
          - /mnt/tank/configs/radarr:/config
          - /mnt/tank/media:/media
        ports:
          - 7878:7878
        restart: unless-stopped

## Download clients behind a VPN (killswitch)

Route a download client through a VPN container so it cannot leak the home IP.
The client defines **no ports of its own** - the ports go on the VPN container,
and the client joins its network. No `depends_on` is needed.

    services:
      gluetun:                       # or a linuxserver/wireguard container
        image: qmcgaw/gluetun
        cap_add: [NET_ADMIN]
        environment:
          - VPN_SERVICE_PROVIDER=...
          - VPN_TYPE=wireguard
          - WIREGUARD_PRIVATE_KEY=...
          - FIREWALL_VPN_INPUT_PORTS=6881
        ports:
          - 8080:8080               # the qBittorrent WebUI port lives HERE
          - 6881:6881/tcp
      qbittorrent:
        image: lscr.io/linuxserver/qbittorrent:latest
        network_mode: "service:gluetun"   # shares the VPN's network stack
        # NO ports: block here

After it's up, confirm the egress IP is the VPN's, not home (see the gluetun rule
in docker-stack-ops).

## Workflow

1. Confirm app, image, ports, and the layout/paths from `infra/docker-stacks.md`.
2. Create the config dir/dataset with the right owner and `770` (on TrueNAS,
   create the dataset in the UI or `mkdir` under the configs dataset).
3. Add the service block (single file) or create the stack dir (Dockge/Portainer).
   Show Evan the compose and confirm before applying.
4. Bring it up (state-changing):

       hh run <dockerhost> "cd <composedir> && docker compose up -d <service>"

5. Verify: `docker ps`, `docker logs --tail 80 <name>`, and the
   WebUI on its port.
6. External access wanted? Add it to the Cloudflare Tunnel (Zero Trust -> the
   tunnel -> add public hostname) or the reverse proxy - see network-diag and
   `infra/`. Do not publish anything externally without an explicit go-ahead.

Record the new app in `infra/docker-stacks.md` so the picture stays current.
