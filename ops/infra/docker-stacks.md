# Docker stacks

Containers are managed with Dockge (compose files) across the docker host(s).
The flagship is the arr media stack; there is also a long tail of self-hosted
apps.

## Fill me in

- Which host(s) run Docker, and their SSH aliases: `<...>`
- Dockge stacks directory (where compose files live): `<e.g. /opt/stacks>`
- Compose command in use: `<docker compose | docker-compose>`

## The arr stack

Single Dockge compose file. Members:

- Indexers / management: Prowlarr, Profilarr, Reclaimerr
- *arrs: Radarr, Sonarr, Oscarr
- Requests / UI: Seerr, qui
- Player: Jellyfin
- Download: qBittorrent behind gluetun (WireGuard). The VPN sidecar is the
  usual suspect when downloads stall.
- Automation / housekeeping: Newtarr, Unpackerr, Watchtower, Dozzle

Other self-hosted apps seen in this environment: Termix, Seafile, Immich,
RustDesk, DockFlare, Syncthing, OpenCloud, SearXNG, Arcane, Dockhand.

## Everyday commands

    hh run <dockerhost> "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
    hh run <dockerhost> "docker logs --tail 100 <container>"
    hh run <dockerhost> "docker stats --no-stream"
    hh run <dockerhost> "cd <stacks>/<stack> && docker compose ps"
    hh run <dockerhost> "cd <stacks>/<stack> && docker compose logs --tail 80 <service>"

## VPN sidecar (gluetun) checks

Downloads dead but everything else fine usually means the tunnel dropped.

    hh run <dockerhost> "docker logs --tail 60 gluetun"
    # qBittorrent shares gluetun's network, so verify egress IP through it:
    hh run <dockerhost> "docker exec gluetun wget -qO- https://ipinfo.io/ip"
    # If that IP is your home IP or the call fails, the tunnel is down. Restart
    # gluetun, then qbittorrent, and confirm the IP is the VPN's before resuming.

## Lifecycle (state-changing, confirm first)

    hh run <dockerhost> "cd <stacks>/<stack> && docker compose restart <service>"
    hh run <dockerhost> "cd <stacks>/<stack> && docker compose up -d"
    hh run <dockerhost> "cd <stacks>/<stack> && docker compose pull && docker compose up -d"

## Known gotchas

- `<record recurring issues here, e.g. a container that needs gluetun healthy
  before it starts, an app whose config volume must not be pruned, a stack that
  is order-sensitive on boot>`
