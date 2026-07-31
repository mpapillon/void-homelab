# Backups with Borg

One [Borg](https://www.borgbackup.org/) repository per client, stored under `/mnt/backup/repo-<client>`. A dedicated `backup` system user on the server owns all the repos. Each client's key is restricted to only the path of its own repo, so a compromised or lost client key can't touch another client's backups or run arbitrary commands on the server.

## Server setup

### Installation

```bash
doas xbps-install borg
```

### Dedicated user

```bash
doas useradd -r -m -d /home/backup -s /bin/sh -p '*' backup
```

> `useradd -r` locks the password field (`!`) by default. Void's `sshd` runs `UsePAM yes`, which also validates account status for pubkey logins, not just passwords. A locked account gets rejected even with a valid key, so `-p '*'` sets an invalid-but-not-locked hash instead.

`doas.conf` only permits `wheel` to act `as root` so far (see [Void install](01-void-install.md#doas)). Managing `backup`'s own `~/.ssh` without full root needs its own rule:

```bash
echo "permit nopass <username> as backup" | doas tee -a /etc/doas.conf
```

### SSH key directory

```bash
doas -u backup mkdir -m 700 /home/backup/.ssh
doas -u backup touch /home/backup/.ssh/authorized_keys
doas -u backup chmod 600 /home/backup/.ssh/authorized_keys
```

### Per-client repo directory

One directory per client, owned by `backup`:

```bash
doas mkdir -p /mnt/backup/repo-<client>
doas chown backup:backup /mnt/backup/repo-<client>
doas chmod 700 /mnt/backup/repo-<client>
```

### Restrict SSH access per client

Each client authenticates with its own key pair (generated on the client, see below). Add the public key to `backup`'s `authorized_keys` with a forced command that restricts it to `borg serve` on that client's repo only:

```bash
echo 'command="borg serve --restrict-to-path /mnt/backup/repo-<client>",restrict ssh-ed25519 <key> <client>-backup' | doas -u backup tee -a /home/backup/.ssh/authorized_keys
```

`command="..."` forces the session to run `borg serve` no matter of what the client asks for, ignoring anything. `--restrict-to-path` limits that `borg serve` to the one repo directory. `restrict` disables port/agent/X11 forwarding, PTY allocation, and similar features, so this key can only speak the Borg protocol, nothing else.

### Allow SSH login for the `backup` user

`/etc/ssh/sshd_config.d/default.conf` defaults to no `AllowUsers` restriction beyond what's already there (see [Security](09-security.md#ssh)). Add `backup` to the list:

```
AllowUsers <username> backup
```

```bash
doas sv reload sshd
```

## Client setup

### Key pair

One key pair per client, dedicated to backups (not the client's general SSH key), so it can be revoked independently by deleting its line from `authorized_keys`:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_backup -C "<client>-backup"
```

### SSH config

The server's SSH port is only reachable from the LAN or over WireGuard (see [Security](09-security.md#firewall-with-nftables)), so a client off the LAN connects via the server's WireGuard IP. An SSH config alias keeps the repo URL short and keeps the dedicated key from colliding with any default key.

`~/.ssh/config` on the client:

```
Host backup-server
    HostName 10.0.0.1
    User backup
    IdentityFile ~/.ssh/id_ed25519_backup
    IdentitiesOnly yes
```

> `10.0.0.1` is the server's WireGuard address (see [WireGuard](03-wireguard.md#server-configuration)), swap for the LAN IP if the client is always local.

### Initialize the repo

```bash
borg init --encryption=none ssh://backup-server/mnt/backup/repo-<client>
```

### Test

```bash
borg create --stats --progress ssh://backup-server/mnt/backup/repo-<client>::test ~/Documents
borg list ssh://backup-server/mnt/backup/repo-<client>
borg delete ssh://backup-server/mnt/backup/repo-<client>::test
```

### Vorta

Actual backups run through [Vorta](https://vorta.borgbase.de/), a GUI/scheduler wrapper around Borg, instead of a hand-rolled timer. It already covers scheduling, retention and tray notifications, so there's no need to reinvent that with cron or a systemd timer on the client.

- Add existing repository, URL: `ssh://backup-server/mnt/backup/repo-<client>` (Vorta shells out to the system `ssh`, so the `~/.ssh/config` alias above is picked up automatically).
- Sources: pick the directories to back up.
- Schedule: enable, pick a cadence.
- Prune: keep 7 daily, 4 weekly, 6 monthly, 2 yearly, enable autoprune so it runs after each backup.

## Backing up the server itself

The server backs up its own data the same way it receives backups from clients: into its own repo under `/mnt/backup`. The difference is there's no SSH involved, and the daily job (below) needs raw root access to read directories and to `docker exec` into the Immich container. [Restrict SSH access](#restrict-ssh-access-per-client) and [allow SSH login](#allow-ssh-login-for-the-backup-user) don't apply here, so the repo stays root-owned:

```bash
doas mkdir -p /mnt/backup/repo-server
doas chmod 700 /mnt/backup/repo-server
doas borg init --encryption=none /mnt/backup/repo-server
```

Alongside the database dumps below, this repo also picks up the data drive, every home directory, and the git server:

- `/mnt/storage`
- `/home`
- `/srv/git`

`borg create` can't work directly on live database files: copying a SQLite file or a Postgres data directory mid-write risks capturing a torn, inconsistent state. Each database needs to produce a consistent snapshot or dump into a staging directory first, which `borg` then picks up:

```bash
doas mkdir -p /var/backups/local/sqlite /var/backups/local/immich-postgres
```

### SQLite

`sqlite3_rsync` copies a live database without stopping the writer. It only transfers the changed pages. It ships in the `sqlite-tools` package.

```bash
doas xbps-install sqlite-tools
```

```bash
doas sqlite3_rsync /var/lib/rubis/rubis.db /var/backups/local/sqlite/rubis.db
```

(`/var/lib/rubis/rubis.db` is the `rubisd` example from [Runit services](08-runit-services.md#example-rubisd))

> As of writing, upstream Void's `sqlite-tools` doesn't build `sqlite3_rsync` yet. It's pending in [void-packages#61737](https://github.com/void-linux/void-packages/pull/61737).

### Postgres (Immich)

Immich's own [backup docs](https://docs.immich.app/administration/backup-and-restore) recommend `pg_dumpall` against the running container. Skip their `gzip` step: compressing before Borg only works against its deduplication.

```bash
docker exec -t immich_postgres pg_dumpall --clean --if-exists --username=<db_username> > /var/backups/local/immich-postgres/immich-database.sql
```

### Daily job

`config/backup-local` runs as root via `snooze-daily`. It stays root the whole way through instead of dropping to a dedicated user, reading every user's home directory, `/srv/git`, `rubis.db`, and the `docker exec` into Immich's container, all need root anyway. The `--exclude` paths skip Immich's regenerable caches (thumbnails, transcoded video), the same way its own backup docs do (see [Postgres](#postgres-immich) above):

```bash
doas cp config/backup-local /etc/cron.daily/backup-local
doas chmod +x /etc/cron.daily/backup-local
```

`borg prune` only marks archives as deleted, it doesn't free the underlying chunks. That's `compact`'s job. Running `compact` daily works but does a full scan of the repo, wasted effort for how little `prune` actually removes day to day, so it's pushed to the monthly job below instead alongside a full integrity check.

### Monthly check

`snooze-monthly` isn't enabled yet (see [Cron](02-cron.md#cadence-services)):

```bash
doas mkdir -p /etc/cron.monthly
doas ln -s /etc/sv/snooze-monthly /var/service
```

`config/backup-local-verify` reclaims the space `prune` freed up and checks repo/archive integrity. Both are worth doing less often than daily, since they walk the whole repo:

```bash
doas cp config/backup-local-verify /etc/cron.monthly/backup-local-verify
doas chmod +x /etc/cron.monthly/backup-local-verify
```

Set up logging for the newly-enabled `snooze-monthly` the same way as `snooze-daily` (see [Cron](02-cron.md#logging)), swapping in `-t snooze-monthly`.
