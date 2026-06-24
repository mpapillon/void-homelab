# Immich installation

## Docker

```bash
doas xbps-install docker docker-compose
doas ln -s /etc/sv/docker/ /var/service
```

## Immich 

> Simply follow the [official guide](https://docs.immich.app/install/docker-compose).

My setup differs slightly from the official guide:
   * I use a dedicated user for immich instead of running as root,
   * I keep the DB volume under `/var/lib`, following the standard Unix hierarchy, instead of `/opt` as the official docs suggest.

### Database volume
   
```bash
doas mkdir -p /var/lib/immich/db
```

Edit the `.env` to set:
```
DB_DATA_LOCATION=/var/lib/immich/db
```

### User configuration

```bash
doas useradd --no-create-home --shell /sbin/nologin immich
doas id -u immich # get the user id, in my case 1001
```

Then, into the `docker-compose.yml` add user config:
```yml
services:
  immich-server:
    # [...]
    user: "1001:1001" # or any id given by the id command.
    # [...]
```

Photo/video storage lives on the `/mnt/storage` HDD rather than the system SSD:
```bash
doas mkdir -p /mnt/storage/immich
doas chown immich:immich /mnt/storage/immich
```
Point the `UPLOAD_LOCATION` in the `.env` to that path.

### Hardware Transcoding

The server's CPU is quite weak, so I enabled HW transcoding using the proprietary VAAPI driver `intel-media-driver`.

> This driver pulls in Wayland as a dependency, which is a bit annoying on a headless box. It's probably possible to build it without that via `xbps-src`, but I'd rather keep things simple here.

```bash
doas xbps-install intel-media-driver libva-utils
# check if it works
vainfo
```

Then I follow the official [Hardware Transcoding guide](https://docs.immich.app/features/hardware-transcoding).

