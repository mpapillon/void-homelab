# dnsmasq configuration

I use `dnsmasq` on the server to relay DNS queries and resolve a private subdomain tied to my public domain (e.g. `immich.<subdomain>.<domain>`). These domains only resolve over WireGuard, so they're unreachable from outside the VPN.

## Installation

```bash
doas xbps-install dnsmasq
```

## Configuration

Enable conf dir: 
```bash
echo "conf-dir=/etc/dnsmasq.d/,*.conf" | doas tee -a /etc/dnsmasq.conf
```

Create file `/etc/dnsmasq.d/default.conf`:
```
no-resolv
no-hosts

# fallback to dns4eu
server=86.54.11.1

bind-dynamic
interface=enp1s0
interface=wg0
except-interface=lo

address=/<subdomain>.<domain>/10.0.0.1
```

> `10.0.0.1` is the server's WireGuard IP, and `interface=enp1s0`/`wg0` restricts dnsmasq to the LAN and VPN interfaces (it won't answer on `lo`).

## Start service

```bash
doas ln -s /etc/sv/dnsmasq /var/service
```
