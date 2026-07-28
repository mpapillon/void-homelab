# Void Server

Notes on running a minimalist home server on [Void Linux](https://voidlinux.org/), written mostly for myself, shared in case it helps someone else.

## Philosophy

Opinionated and minimal: no systemd, no unnecessary daemons, no abstraction I can't explain. Every package and service earns its place.

## Hardware

- Dell Wyse 5070 (low-power thin client, not very performant CPU), 16 GB RAM
- 128 GB internal SSD for the system (`/`)
- 2 HDDs: `/mnt/storage` (data) and `/mnt/backup` (backups)

## Guides

1. [Void Linux install](01-void-install.md) - base system, partitions, doas, bootloader
2. [Cron](02-cron.md) - `snooze` + runit as a cron replacement
3. [WireGuard](03-wireguard.md) - VPN access to the server
4. [dnsmasq](04-dnsmasq.md) - private subdomains, reachable only over WireGuard
5. [Immich](05-immich.md) - self-hosted photo backup, with hardware transcoding
6. [acme.sh](06-acme.md) - SSL certificates via OVH DNS API
7. [Nginx](07-nginx.md) - reverse proxy, one subdomain per app
8. [Runit services](08-runit-services.md) - supervising custom daemons
9. [Security](09-security.md) - SSH hardening, nftables firewall
10. [Miscellaneous](10-misc.md) - SSD TRIM, USB drive APM
11. [Bash configuration](11-bash.md) - prompt, completions, login banner
