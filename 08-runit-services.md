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
exec svlogd -t /var/log/<service>
```

Writes straight to a directory dedicated to this service, instead of going through `vlogger`/`socklog` and piling everyone's output into the shared `daemon` facility. `svlogd` handles rotation itself (`current`, rotated to `@<timestamp>.s` past the size limit) and `-t` prefixes each line with a TAI64N timestamp.

The directory must exist before the service starts:

```sh
doas mkdir -p /var/log/<service>
```

## Permissions

Both `run` scripts must be executable:

```sh
doas chmod +x /etc/sv/<service>/run /etc/sv/<service>/log/run
```

## Reading logs

Each service's own logs live under `/var/log/<service>/`, written directly by its `log/run`. No `socklog`/`vlogger` in the path, so nothing to filter by tag:

```sh
tail -f /var/log/<service>/current
```

With `-t`, each line in `current` gets a TAI64N timestamp prefixed (e.g. `@4000000068889abc12345678 <line>`), not human-readable on its own. Pipe through `tai64nlocal` to convert it to local time, or drop `-t` in `log/run` if you'd rather keep plain lines with no timestamp.

System-level logging (kernel, auth, and anything else emitting through the syslog socket) still goes through `socklog-void`, enabled in [Void install](01-void-install.md), under `/var/log/socklog/<facility>/`. Reusing an existing facility that fits semantically beats a dedicated `svlogd` directory when several small jobs share the same nature. See [Cron](02-cron.md#logging) for `snooze` piggybacking on the pre-defined `cron` facility via `vlogger`.

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

`/etc/sv/rubisd/log/run` (directory created first with `doas mkdir -p /var/log/rubisd`):

```sh
#!/bin/sh
exec svlogd -t /var/log/rubisd
```

Reading logs:

```sh
tail -f /var/log/rubisd/current
```
