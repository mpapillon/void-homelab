# Nginx configuration

Access the server's applications through subdomains rather than ports, by combining Nginx and dnsmasq.

## Installation

```bash
doas xbps-install nginx
doas ln -s /etc/sv/nginx /var/service
doas mkdir -p /etc/nginx/conf.d
```

## Create config

The default config of nginx provided by Void does not use `conf.d`. 
I made my own config for reverse proxying in this repo in `nginx/nginx.conf`.

## One virtual host per application
 
Each application gets its own config file in `/etc/nginx/conf.d/`.
 
`/etc/nginx/conf.d/immich.conf`:
```nginx
server {
    listen 80;
    listen [::]:80;
    server_name immich.<subdomain>.<domain>;

    location / {
        proxy_pass http://127.0.0.1:2283;
    }
}
```

## Finalize

```bash
# check config
doas nginx -t
# reload Nginx
doas sv reload nginx
```


