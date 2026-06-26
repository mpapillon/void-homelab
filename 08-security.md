# Security

## SSH

Void ships a sane default at `/etc/ssh/sshd_config.d/default.conf`. Verify it contains at minimum:

```
PermitRootLogin no
PasswordAuthentication no
```

## Firewall with nftables

The config in this repo (`config/nftables.conf`) drops all inbound traffic by default, only allowing WireGuard from the internet and SSH from the local network.

## Installation

```sh
doas xbps-install nftables
# apply config
doas cp config/nftables.conf /etc
doas ln -s /etc/sv/nftables /var/service
```

## How it works

The input chain accepts in order:

- ICMP: ping and network diagnostics
- UDP 51820 on `enp1s0`: WireGuard, the only port exposed to the internet
- TCP 22 on `enp1s0` from 192.168.1.0/24: SSH from the local network only
- everything on `wg0`: once inside the VPN, full access to SSH, Nginx, etc.

## Testing

When testing remotely, load the config with an automatic rollback in case the new rules cut SSH access:

```sh
doas nft -f /etc/nftables.conf; sleep 60; doas nft flush ruleset
```

Cancel with Ctrl+C before the 60 seconds if everything works, then reload via the service. If the config locks you out, the flush runs automatically and restores access.

Load the config without automatic rollback:

```sh
doas nft -f /etc/nftables.conf
```

Inspect the active ruleset:

```sh
doas nft list ruleset
```
