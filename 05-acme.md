# SSL setup with acme.sh

Certificates are issued via DNS-01 challenge against OVH's API, so no port 80/443 exposure is needed just to prove domain ownership.
Renewal runs unprivileged, only the final deploy step (copying the cert where Nginx reads it, then reloading) needs root, through a single allowed `doas` command.

## Installation

```bash
doas xbps-install acme.sh snooze
```

## Dedicated user

`acme.sh` talks to the OVH API and runs as a long-lived process (via `snooze-daily`), it shouldn't run as root.

```bash
doas useradd -mr -s /usr/sbin/nologin acme
```

`doas.conf` only permits `wheel` to act `as root` so far (see [Void install](01-void-install.md#doas)).
Running commands as `acme` needs its own rule:

```bash
echo "permit persist :wheel as acme" | doas tee -a /etc/doas.conf
```

## OVH API keys

Create an [OVH API application](https://api.ovh.com/createToken/) scoped to `GET/PUT/POST/DELETE /domain/zone/<domain>/*`, then store the keys in a file readable only by `acme`:

```bash
doas -u acme tee /home/acme/.ovh_keys <<'EOF'
OVH_AK=<application_key>
OVH_AS=<application_secret>
OVH_CK=<consumer_key>
OVH_END_POINT=ovh-eu
EOF
doas chmod 600 /home/acme/.ovh_keys
```

> `acme.sh`'s `dns_ovh` plugin reads these as environment variables, hence sourcing the file before calling it rather than passing keys as arguments (which would leak them into shell history/process list).

## Use Let's Encrypt

The xbps package only installs the script itself, unlike the official installer it doesn't initialize `acme`'s home directory, create it first:

```bash
doas -u acme mkdir -p /home/acme/.acme.sh
```

`acme.sh` defaults to ZeroSSL as CA, switch the default to Let's Encrypt:

```bash
doas -u acme acme.sh --set-default-ca --server letsencrypt
```

## Issue the certificate

```bash
doas -u acme sh -c '. /home/acme/.ovh_keys && acme.sh --issue --dns dns_ovh -d <domain> -d "*.<subdomain>.<domain>"'
```

The cert and key land under `/home/acme/.acme.sh/<domain>/`.

## Deploy to Nginx

`acme.sh` can't write into `/etc/nginx` (owned by root), so deployment goes through a small root-owned script, the only thing `acme` is allowed to run as root:

```bash
doas mkdir -p /etc/nginx/ssl
```

```bash
doas tee /usr/local/sbin/deploy-cert.sh <<'EOF'
#!/bin/sh
set -e
cp /home/acme/.acme.sh/<domain>/fullchain.cer /etc/nginx/ssl/<domain>.crt
cp /home/acme/.acme.sh/<domain>/<domain>.key /etc/nginx/ssl/<domain>.key
sv reload nginx
EOF
doas chmod 700 /usr/local/sbin/deploy-cert.sh
```

Allow `acme` to run only this script as root:

```bash
echo "permit nopass acme as root cmd /usr/local/sbin/deploy-cert.sh args" | doas tee -a /etc/doas.conf
```

Register it as the reload hook so it runs automatically after every renewal:

```bash
doas -u acme sh -c '. /home/acme/.ovh_keys && acme.sh --install-cert -d <domain> --reloadcmd "doas /usr/local/sbin/deploy-cert.sh"'
```

## Automatic renewal

`acme.sh --cron` only renews certs nearing expiry (< 30 days), so a daily check is enough. The `snooze` package ships a `snooze-daily` service that runs every script in `/etc/cron.daily/`:

`snooze-daily` runs as root, so the script drops to `acme` via `su` before calling `acme.sh` (the reload hook configured above then escalates back to root only for `deploy-cert.sh`):

```bash
doas tee /etc/cron.daily/acme-renew <<'EOF'
#!/bin/sh
exec su -s /bin/sh acme -c '. /home/acme/.ovh_keys && acme.sh --cron'
EOF
doas chmod +x /etc/cron.daily/acme-renew
doas ln -s /etc/sv/snooze-daily /var/service
```
