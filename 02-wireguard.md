# WireGuard configuration

## Installation

```bash
doas xbps-install wireguard-tools
```

Wireguard runit service loads every *.conf from `/etc/wireguard/`, to avoid conflicts I created sub-dirs :
  * `/etc/wireguard/peers`: conf files for wg peers
  * `/etc/wireguard/keys`: public and private keys

```bash
doas mkdir /etc/wireguard/{peers,keys}
```

## Key generation

WireGuard authenticates with cryptographic keys. Generate **one key pair per peer**: this lets you revoke a single device without affecting the others.

```bash
# Server keys
wg genkey | doas tee /etc/wireguard/keys/server_private.key | wg pubkey | doas tee /etc/wireguard/keys/server_public.key
doas chmod 600 /etc/wireguard/keys/server_private.key

# Peer keys
wg genkey | doas tee /etc/wireguard/keys/<peer>_private.key | wg pubkey | doas tee /etc/wireguard/keys/<peer>_public.key
doas chmod 600 /etc/wireguard/keys/<peer>_private.key
```

## Server configuration

Create `/etc/wireguard/wg0.conf`:

```ini
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = <SERVER_PRIVATE_KEY>

[Peer]
# Phone
PublicKey = <PHONE_PUBLIC_KEY>
AllowedIPs = 10.0.0.2/32

[Peer]
# Laptop
PublicKey = <LAPTOP_PUBLIC_KEY>
AllowedIPs = 10.0.0.3/32
```

Each device gets a unique WireGuard IP (`10.0.0.2`, `10.0.0.3`, etc.). To revoke a device, just remove its `[Peer]` block and reload the config:

```bash
doas wg syncconf wg0 <(doas wg-quick strip wg0)
```

## Peer configuration
 
Create `/etc/wireguard/peers/<name>.conf`:
 
```ini
[Interface]
PrivateKey = <PEER_PRIVATE_KEY>
Address = 10.0.0.2/24
DNS = 10.0.0.1
 
[Peer]
PublicKey = <SERVER_PUBLIC_KEY>
Endpoint = <domain>:51820
AllowedIPs = 10.0.0.0/24
PersistentKeepalive = 25
```
 
> `AllowedIPs` limited to the home network = **split tunnel**: only traffic to the home network goes through WireGuard, internet traffic stays direct.

## Enable service

```bash
doas ln -s /etc/sv/wireguard /var/service/
```

## Show config and peers

```bash
doas wg show
```
