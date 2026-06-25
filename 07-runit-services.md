# Runit Services

> [Void Handbook: Services](https://docs.voidlinux.org/config/services/index.html)

## Service directory structure

A service directory requires one executable named `run`, which is expected to exec a process in the foreground. Optionally it may contain:

- `finish`: run on shutdown/process stop
- `conf`: environment variables to be sourced in `run`
- `log/`: a pipe will be opened from the output of `run` to the input of `log/run`

```
/etc/sv/<service>/
├── run
├── finish      (optional)
├── conf        (optional)
└── log/
    └── run
```

## Enabling a service

```sh
doas ln -s /etc/sv/<service> /var/service/
```

To test a service before fully enabling it:

```sh
doas touch /etc/sv/<service>/down
doas ln -s /etc/sv/<service> /var/service/
doas sv once <service>
```

If everything works, remove the `down` file to enable the service.

## run script

```sh
#!/bin/sh -e
exec 2>&1
exec chpst -u <user> /usr/local/bin/<binary> [flags]
```

- `exec 2>&1`: merges stderr into stdout so both reach the logger pipe
- `chpst -u <user>`: drops privileges to the given system user
- `exec`: replaces the shell process with the daemon

## log/run script

```sh
#!/bin/sh
exec vlogger -t <service> -p daemon
```

Sends all output to socklog under the `daemon` facility, tagged with the service name.

## Permissions

Both `run` scripts must be executable:

```sh
doas chmod +x /etc/sv/<service>/run /etc/sv/<service>/log/run
```

## Reading logs

Requires `socklog-void`, enabled in [Void install](01-void-install.md). Logs are saved in sub-directories of `/var/log/socklog/`. Reading logs requires being `root` or a member of the `socklog` group.

```sh
# All daemon logs (live)
svlogtail daemon

# Filter by service tag
svlogtail daemon | grep <service>

# Available facilities
ls /var/log/socklog/
# cron  daemon  debug  errors  everything  kernel  ...
```

`svlogtail <facility>` tails `/var/log/socklog/<facility>/current`. There is no per-service directory, filter with `grep` for custom services using `vlogger`.

## Example: rubisd

`rubis` is a personal project, not public yet. Used here simply as an example.

`chpst -u rubisd` below needs the user to exist first, dedicated so the daemon doesn't run as root:

```sh
doas useradd -mr -s /usr/sbin/nologin rubisd
```

`/etc/sv/rubisd/run`:

```sh
#!/bin/sh -e
exec 2>&1
exec chpst -u rubisd /usr/local/bin/rubis \
  -addr 127.0.0.1:4001 \
  -db-path /var/lib/rubis/rubis.db \
  -base-url https://rubis.<subdomain>.<domain>
```

`/etc/sv/rubisd/log/run`:

```sh
#!/bin/sh
exec vlogger -t rubisd -p daemon
```

Reading logs:

```sh
svlogtail daemon | grep rubisd
```
