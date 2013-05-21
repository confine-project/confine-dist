#!/bin/sh

mkdir -p /tmp/boot
mount -t ext2 -o rw,noatime /dev/sda1 /tmp/boot

if [ -f /tmp/boot/fstab ]; then
    mv -f /tmp/boot/fstab /etc/config/fstab
    mkdir -p /overlay /home
    /etc/init.d/fstab enable
    mount -o remount,ro /tmp/boot
    umount -l /tmp/boot
    reboot
elif [ -f /tmp/boot/conf.tgz ]; then
    tar -C / -xzf /tmp/boot/conf.tgz
    rm /tmp/boot/conf.tgz
    mount -o remount,ro /tmp/boot
    umount -l /tmp/boot
    reboot
fi

mount -o remount,ro /tmp/boot
umount -l /tmp/boot
rmdir /tmp/boot

exit 0
