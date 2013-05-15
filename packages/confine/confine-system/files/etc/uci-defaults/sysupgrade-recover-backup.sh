#!/bin/sh

mkdir -p /tmp/boot
mount -t ext2 -o rw,noatime /dev/sda1 /tmp/boot

if [ -f /tmp/boot/fstab ]; then
    mv /tmp/boot/fstab /etc/config/fstab
    mkdir /overlay /home
    /etc/init.d/fstab enable
    mount -o remount,ro /tmp/boot
    umount -l /tmp/boot
    reboot -f
elif [ -f /tmp/boot/conf.tgz ]; then
    tar -C / -xzf /tmp/boot/conf.tgz
    rm /tmp/boot/conf.tgz
    mount -o remount,ro /tmp/boot
    umount -l /tmp/boot
    reboot -f
fi

mount -o remount,ro /tmp/boot
umount -l /tmp/boot
rmdir /tmp/boot

exit 0
