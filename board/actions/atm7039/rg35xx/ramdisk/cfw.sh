#!/bin/ash

export PATH=/bin:/sbin:/usr/bin:/usr/sbin

if [ -f /misc/enableADB ]
then
    echo 0 > /sys/monitor/usb_port/config/run

    echo 1 > /sys/monitor/usb_port/config/idpin_debug
    /usbmond.sh USB_A_OUT && /usbmond.sh USB_B_IN
fi

mkdir -p /new_root /sys /proc
#mount -t proc  -o nodev,noexec,nosuid proc  /proc   
#mount -t sysfs -o nodev,noexec,nosuid sysfs /sys

mount -t devtmpfs none /dev
#mkdir -p /dev/pts
#mount -t devpts devpts /dev/pts

umount /misc
fsck.fat -y /dev/mmcblk0p1
mount /dev/mmcblk0p1 /misc

#losetup /dev/block/loop7 /misc/boot/batocera
#mount -r -w -o loop -t ext4 /dev/block/loop7 /new_root

# Knulli: el build deixa el rootfs com a boot/knulli.update; el primer
# arrencada (o una actualitzacio) el renombra a boot/knulli. Es manté
# boot/batocera com a alternativa per a targetes antigues de Koriki.
if [ -f /misc/boot/knulli.update ]; then
    mv -f /misc/boot/knulli.update /misc/boot/knulli && busybox sync
fi
ROOTFS=/misc/boot/knulli
[ -f "$ROOTFS" ] || ROOTFS=/misc/boot/batocera
mount "$ROOTFS" /new_root

mount -o bind /dev /new_root/dev
#mount -o bind /dev/pts /new_root/dev/pts
mount -o bind /sys /new_root/sys
mount -o bind /proc /new_root/proc
#mount -o bind /run /new_root/run

#mount --move /dev /new_root/dev
#mount --move /sys /new_root/sys
#mount --move /proc /new_root/proc

busybox chroot /new_root source /etc/profile

busybox chroot /new_root /etc/init.d/rcS
#busybox chroot /new_root /bin/bash

#exec switch_root /new_root /sbin/init


