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
I made my own config for reverse proxying in this repo in `config/nginx.conf`.

## One virtual host per application
 
Each application gets its own config file in `/etc/nginx/conf.d/`.

Example for [Immich](04-immich.md), in `/etc/nginx/conf.d/immich.conf`. The extra directives below (body size, buffering, timeouts) aren't generic Nginx boilerplate: they're there because Immich uploads large photo/video files and uses WebSocket for realtime updates. HTTPS (cert, HTTP→HTTPS redirect) is handled once for every subdomain in `config/nginx.conf`, see [acme.sh](05-acme.md), each vhost only needs `listen 443 ssl`.
```nginx
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name immich.<subdomain>.<domain>;

    # allow large file uploads (photos/videos)
    client_max_body_size 50000M;

    # don't buffer uploads on disk/memory, pass them straight through
    proxy_request_buffering off;
    client_body_buffer_size 1024k;

    # large uploads and transcoding can take a while
    proxy_read_timeout 600s;
    proxy_send_timeout 600s;
    send_timeout 600s;

    location / {
        proxy_pass http://127.0.0.1:2283;

        # Immich uses WebSocket (Socket.IO) for realtime updates;
        # overrides the global `Connection ""` from nginx.conf.
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
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


