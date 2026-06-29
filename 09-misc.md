# Miscellaneous

## SSD TRIM

Weekly TRIM keeps the SSD healthy by letting the controller reclaim deleted blocks.

Enable the weekly runner (`snooze` is already installed from [SSL setup](05-acme.md)):

```sh
doas ln -s /etc/sv/snooze-weekly /var/service
```

Create the weekly TRIM script:

```sh
doas mkdir /etc/cron.weekly
cat <<'EOF' | doas tee /etc/cron.weekly/fstrim
#!/bin/sh
fstrim /
EOF
doas chmod +x /etc/cron.weekly/fstrim
```

## USB Drive APM

By default, USB hard drives aggressively park their heads to save power, causing excessive load cycles that wear out the drive prematurely. APM level 127 disables standby while still allowing some power management.

Install `hdparm` and create the udev rule:

```sh
doas xbps-install hdparm
```

```sh
cat <<'EOF' | doas tee /etc/udev/rules.d/99-hdparm-apm.rules
ACTION=="add|change", SUBSYSTEM=="block", KERNEL=="sd[a-z]", SUBSYSTEMS=="usb", RUN+="/usr/bin/hdparm -B 127 /dev/%k"
EOF
```

The rule fires each time a drive is detected. To apply immediately without a reboot:

```sh
doas hdparm -B 127 /dev/sdb
doas hdparm -B 127 /dev/sdc
```

Verify the current APM level:

```sh
doas hdparm -B /dev/sdb
```
