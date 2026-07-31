# Cron replacement: snooze

Void has no cron daemon by default, and none is installed here. [`snooze`](https://github.com/leahneukirchen/snooze) plus runit supervision fills that role instead. `snooze` just waits for a scheduled time then execs a command, pairing it with runit rather than a persistent cron daemon means no daemon idles in memory between runs, and it's supervised like any other service (`sv status`, `sv once`, `log/`) instead of needing its own bespoke tooling.

## Installation

```sh
doas xbps-install snooze
```

## Cadence services

The package ships pre-built runit services for the classic cron cadences, each just wrapping `run-parts` over the matching `/etc/cron.<cadence>/` directory:

- `snooze-daily` runs `/etc/cron.daily/`
- `snooze-weekly` runs `/etc/cron.weekly/`
- `snooze-monthly` runs `/etc/cron.monthly/`
- `snooze-hourly` runs `/etc/cron.hourly/` (not used here)

## Enabling a cadence

```sh
doas mkdir -p /etc/cron.daily   # skip if it already exists
doas ln -s /etc/sv/snooze-daily /var/service
```

## Adding a job

Drop an executable script in the matching `/etc/cron.<cadence>/` directory. Jobs actually running on this server:

- `acme-renew` (daily): cert renewal check, see [ACME setup](06-acme.md#automatic-renewal)
- `xbps-sync` (daily): refreshes the xbps repo cache for the MOTD, see [Bash configuration](11-bash.md#pending-updates-xbps-sync)
- `backup-local` (daily): backup script with Borg, see [Borg backup](12-borg-backup.md#daily-job)
- `fstrim` (weekly): SSD TRIM, see [Miscellaneous](10-misc.md#ssd-trim)
- `backup-local-verify` (monthly): Borg compact + integrity check, see [Borg backup](12-borg-backup.md#monthly-check)

## Logging

[Snooze](https://github.com/leahneukirchen/snooze/tree/master/sv) only provides `run` script, on the assumption the admin adds their own logging like for any runit service. `socklog-void` already reserves a `cron` syslog facility for exactly this kind of job:

```sh
doas mkdir -p /etc/sv/snooze-daily/log
```

`/etc/sv/snooze-daily/log/run`:

```sh
#!/bin/sh
exec vlogger -t snooze-daily -p cron
```

```sh
doas chmod +x /etc/sv/snooze-daily/log/run
```

Same for `snooze-weekly` and `snooze-monthly`, with `-t snooze-weekly`/`-t snooze-monthly`.

By default `run-parts` doesn't tag each script's own output with its name (only `--verbose` does that, and the shipped `run` doesn't pass it), so everything landing in the `cron` facility for a given cadence is just the raw concatenated output of whatever ran that cycle. There are only 1-2 jobs per cadence here, small enough to eyeball without per-job tagging.

```sh
svlogtail cron
```
