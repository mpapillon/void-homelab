# Bash configuration

`config/bash/` holds the interactive shell setup: prompt, completions, aliases, and a login banner with a quick server status overview.

## Installation

```sh
cp config/bash/bashrc ~/.bashrc
cp config/bash/bash_profile ~/.bash_profile
mkdir -p ~/.bashrc.d
cp config/bash/bashrc.d/*.sh ~/.bashrc.d/
cp config/bash/motd.sh ~/.motd.sh
chmod +x ~/.motd.sh
```

## bashrc.d

`~/.bashrc` sources every `~/.bashrc.d/*.sh` snippet, for any interactive shell, login or not. Files are numbered to control load order:

- `00-bash-completion.sh`: loads `bash-completion` if installed
- `01-doas-completion.sh`: reuses its `_command` completion for `doas`
- `10-prompt.sh`: colored `[user@host path]$` prompt
- `20-aliases.sh`: `ls`/`ll` aliases, `--color=auto` on `grep`/`diff`/`dmesg`, `ip -c`

## Login banner

`~/.motd.sh` prints uptime, load average, RAM/swap, disk usage, pending package updates, and the last 3 logins. `~/.bash_profile` runs it (not sourced) only for interactive login shells, so it fires once per SSH session rather than on every new tmux pane.

Pending updates come from the local xbps cache, kept fresh by the script below, so `~/.motd.sh` itself never needs root.

## Pending updates: xbps-sync

[Cron](02-cron.md) to refresh the repository cache daily so the MOTD's update count stays current:

```sh
doas tee /etc/cron.daily/xbps-sync <<'EOF'
#!/bin/sh
xbps-install -S
EOF
doas chmod +x /etc/cron.daily/xbps-sync
```
