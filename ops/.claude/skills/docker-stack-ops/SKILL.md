---
name: docker-stack-ops
description: >
  Troubleshoot and manage the Docker / Dockge stacks over SSH, especially the
  arr media stack. Use this whenever Evan mentions a container, Docker, Dockge, a
  compose stack, or any specific app such as Jellyfin, qBittorrent, gluetun,
  Radarr, Sonarr, Prowlarr, Seerr, Immich, Seafile, SearXNG, or similar, and
  whenever the symptom is app-level: a container is down, restarting, unhealthy,
  downloads are stalled, requests are not processing, or a service is
  unreachable while its host is fine. Trigger this even if he just names an app
  and says it is broken.
---

# Docker stack ops

Reached over SSH to the docker host(s). Read `infra/docker-stacks.md` for host
aliases, the compose layout, and stack membership before acting.

Where compose files live depends on the setup and is recorded in
`infra/docker-stacks.md`: it may be a single `/mnt/<pool>/docker/docker-compose.yml`
(the TrueNAS layout), per-stack `/opt/stacks/<stack>/compose.yaml` (Dockge), or
stacks defined in Portainer. This skill is for troubleshooting/operating existing
stacks; to stand up a NEW app or stack, use the deploy-app skill.

## Diagnose first

    hh run <dockerhost> "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
    hh run <dockerhost> "docker ps -a --filter status=exited --format '{{.Names}}\t{{.Status}}'"
    hh run <dockerhost> "docker logs --tail 120 <container>"
    hh run <dockerhost> "docker inspect -f '{{.State.Health.Status}}' <container>"

## The gluetun rule (most common arr failure)

If downloads are dead but the rest of the stack is fine, suspect the VPN sidecar
before touching qBittorrent.

    hh run <dockerhost> "docker logs --tail 60 gluetun"
    hh run <dockerhost> "docker exec gluetun wget -qO- https://ipinfo.io/ip"

If that IP is the home IP or the call fails, the tunnel is down. Fix order:
restart gluetun, wait for healthy, confirm the egress IP is the VPN's, then
restart qBittorrent. Never let qBittorrent run with a leaked (home) IP.

## Common cases

- Container restart loop: read the tail of its logs for the fatal line; check a
  bad config volume, a missing dependency container, or a port clash.
- App reachable internally but not externally: this is usually network-diag
  territory (Cloudflare Tunnel or reverse proxy), not the container.
- Everything in a stack down after boot: order sensitivity. Bring up
  dependencies first (VPN, db), then the rest.

## State-changing (confirm first)

    # from the compose dir: Dockge => /opt/stacks/<stack>, single-file => /mnt/<pool>/docker
    hh run <dockerhost> "cd <composedir> && docker compose restart <service>"
    hh run <dockerhost> "cd <composedir> && docker compose up -d"
    hh run <dockerhost> "cd <composedir> && docker compose pull && docker compose up -d"

Do not `docker compose down -v` or prune volumes without an explicit go-ahead;
the `-v` and prune paths delete app data. Image pruning is fine, volume pruning
is not.
