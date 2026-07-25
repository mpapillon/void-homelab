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

## USB Autosuspend
 
By default, the kernel suspends USB devices after a few seconds of bus inactivity (`power/control` set to `auto`). For external HDDs, this becomes a problem during operations where the drive is busy internally but generates little USB traffic, notably `fsck` at boot and SMART extended self-tests. The kernel cuts power mid-operation, which can cause:
 
  * `UNEXPECTED INCONSISTENCY` errors on boot, forcing an emergency shell
  * `Buffer I/O error` / `lost async page write` in dmesg
  * SMART extended self-tests (`smartctl -t long`) aborting early, always around the same point (`Aborted by host`, ~90% remaining)
  * ATA errors logged at the same LBA across multiple occurrences (often LBA 2048, the start of the first partition, read early during boot/fsck)
 
Fix: disable USB autosuspend globally via a kernel boot parameter (acceptable here since only the two backup/storage HDDs are ever connected via USB, no other device benefits from autosuspend).

`/boot/loader/entries/*.conf` is rebuilt on every kernel update by the `50-systemd-boot` kernel hook, so editing it directly doesn't persist. The hook reads `CMDLINE` from `/etc/default/systemd-boot` if set, so put the parameter there instead:

```sh
doas cat /boot/loader/entries/<the-void-entry>.conf   # note the current root=UUID=...
```

```
# /etc/default/systemd-boot
CMDLINE="rootfstype=ext4 root=UUID=xxxx-xxxx quiet rw usbcore.autosuspend=-1"
```

Apply immediately without waiting for the next kernel update:

```sh
doas xbps-reconfigure -f linux<installed-version>
```

Verify:
 
```sh
cat /proc/cmdline
for f in /sys/bus/usb/devices/*/power/autosuspend_delay_ms; do echo "$f: $(cat $f)"; done
```
 
`autosuspend_delay_ms` should read `-1000` (i.e. disabled) on every device. `power/control` may still show `auto`, that's expected and harmless since an infinite delay means the kernel never actually triggers the suspend.

## Intel iGPU IOMMU flicker

`intel_iommu=igfx_off` excludes the integrated GPU from IOMMU DMA remapping. Added to fix intermittent monitor flickering, likely caused by IOMMU faults on the iGPU.

Add it to the same `CMDLINE` as above (see [USB Autosuspend](#usb-autosuspend) for how this persists across kernel updates):

```
# /etc/default/systemd-boot
CMDLINE="rootfstype=ext4 root=UUID=xxxx-xxxx quiet rw usbcore.autosuspend=-1 intel_iommu=igfx_off"
```

```sh
doas xbps-reconfigure -f linux<installed-version>
```
