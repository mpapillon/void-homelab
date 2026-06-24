# My Void Linux Server Install Guide

Opinionated, minimalist install guide for a Void Linux server. Headless, no systemd, essential packages only.

Stack: `doas` (sudo replacement), `systemd-boot`/gummiboot (bootloader), `dhcpcd` (network), `nftables` (firewall).

Keyboard layout:
```
# loadkeys fr
```

## Partitions

> Void Handbook: [Partitioning Notes](https://docs.voidlinux.org/installation/live-images/partitions.html), [Prepare Filesystems](https://docs.voidlinux.org/installation/guides/chroot.html#prepare-filesystems)

Useful commands:
  * List drives/partitions: `lsblk`
  * Create partitions: `fdisk /dev/sda`
  * Create filesystems: `mkfs.vfat` for UEFI, `mkfs.ext4` for /

My layout:

  * 521 MB (EFI Partition) - /boot
  * 4 GB - Swap 
  * MAX - ext4 - /

## Installation via chroot

> [Void Handbook](https://docs.voidlinux.org/installation/guides/chroot.html)

Mount the target partitions:
```
# mount /dev/sda2 /mnt
# mkdir /mnt/boot
# mount /dev/sda1 /mnt/boot
```

### Install via XBPS

> [The XBPS Method](https://docs.voidlinux.org/installation/guides/chroot.html#the-xbps-method)

Set variables:
```
# REPO=https://repo-default.voidlinux.org/current
# ARCH=x86_64
```

Copy the RSA keys from the installation medium to the target root, required for `xbps-install` to verify packages:
```
# mkdir -p /mnt/var/db/xbps/keys
# cp /var/db/xbps/keys/* /mnt/var/db/xbps/keys/
```

Install the base system and every package needed for the rest of this guide:
```
# XBPS_ARCH=$ARCH xbps-install -S -r /mnt -R "$REPO" base-minimal linux linux-firmware-intel bash file less ncurses man-pages mdocml kbd dhcpcd openssh chrony socklog-void iputils git wget opendoas gummiboot
```

## Configuration

### Configure Filesystems

> [Configure Filesystems](https://docs.voidlinux.org/installation/guides/chroot.html#configure-filesystems)

```
# xgenfstab -U /mnt > /mnt/etc/fstab
```

### Entering the Chroot

```
# xchroot /mnt /bin/bash
```

### Hostname

Edit file: `/etc/hostname`

### Locale

Edit files:
  * `/etc/rc.conf` - keymap
  * `/etc/default/libc-locales` - uncomment fr_FR

```
[xchroot /mnt] # xbps-reconfigure -f glibc-locales
```

### Timezone

```
[xchroot /mnt] # ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
```

### Pre-enable services

`runit` only starts services symlinked under `runsvdir/default`:
```
[xchroot /mnt] # ln -s /etc/sv/{chronyd,dhcpcd,sshd,socklog-unix,nanoklogd} /etc/runit/runsvdir/default/
```

### User creation

`-G wheel` is required for `doas` access below, root login stays disabled (no `passwd root`):
```
[xchroot /mnt] # useradd -mG wheel <username>
[xchroot /mnt] # passwd <username>
```

### doas

Add to `/etc/doas.conf`:
```
permit persist :wheel as root
```

`:wheel` grants any wheel member, not just one user. `persist` caches auth for a few minutes instead of `nopass`, which never asks at all. `doas` refuses to run if the config file isn't strictly owned/permissioned:
```
[xchroot /mnt] # chown -c root:root /etc/doas.conf
[xchroot /mnt] # chmod 0400 /etc/doas.conf
```

## Install Intel Microcode

Should enable non-free repo before:
```
[xchroot /mnt] # xbps-install -S void-repo-nonfree
[xchroot /mnt] # xbps-install -S intel-ucode
```

Regenerate initramfs:
```
[xchroot /mnt] # xbps-reconfigure -f linux<version>
```

## Install systemd-boot (ex: gummiboot)

```
[xchroot /mnt] # bootctl install --path /boot
```

The boot entry is created automatically by the kernel hooks during the `linux` package's `xbps-reconfigure` (see Finalization below).

## Finalization

Reruns all package hooks (kernel, boot entry, locales, etc.) against the final config:
```
[xchroot /mnt] # xbps-reconfigure -fa
```

Leave the chroot and reboot into the new system:
```
[xchroot /mnt] # exit
# umount -R /mnt
# reboot
```
