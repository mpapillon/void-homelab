# Void Server

Notes on running a minimalist home server on [Void Linux](https://voidlinux.org/), written mostly for myself, shared in case it helps someone else.

## Philosophy

Opinionated and minimal: no systemd, no unnecessary daemons, no abstraction I can't explain. Every package and service earns its place.

## Hardware

- Dell Wyse 5070 (low-power thin client, not very performant CPU), 16 GB RAM
- 128 GB internal SSD for the system (`/`)
- 2 HDDs: `/mnt/storage` (data) and `/mnt/backup` (backups)

## Guides

1. [Void Linux install](01-void-install.md) — base system, partitions, doas, bootloader
2. [WireGuard](02-wireguard.md) — VPN access to the server
3. [dnsmasq](03-dnsmasq.md) — private subdomains, reachable only over WireGuard
4. [Immich](04-immich.md) — self-hosted photo backup, with hardware transcoding
5. [Nginx](05-nginx.md) — reverse proxy, one subdomain per app
