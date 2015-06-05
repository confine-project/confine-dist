#!/bin/sh

TO_REMOVE="/etc/config/confine-defaults /usr/lib/opkg /.extroot.md5sum /etc/extroot.md5sum /etc/.extroot-uuid /var/www/confine /etc/banner /etc/confine.version"

check_part() {
    local dev=$1
    local part=${dev}1
    local dir=$2
    mount $part $dir || mount -t ext2 -o rw,noatime $part $dir

    if [ -f ${dir}/fstab ]; then
        mv -f ${dir}/fstab /etc/config/fstab
        mkdir /overlay /home
        mount ${dev}3 /overlay
        for d in $TO_REMOVE; do
            [ -e /overlay/$d ] && find /overlay/$d -exec rm -rf {} \;
        done
        umount /overlay
        /etc/init.d/fstab enable
        sleep 2
        reboot
    elif [ -f ${dir}/conf.tgz ]; then
        tar -C / -xzf ${dir}/conf.tgz
        rm ${dir}/conf.tgz
        reboot
    fi

    mount -o remount,ro ${dir}
    umount -l ${dir}
}

DIR=/tmp/boot
mkdir -p $DIR

for dev in /dev/sda /dev/sdb /dev/sdc; do
    [ -b $part ] && check_part $dev $DIR
done

rmdir ${DIR}

exit 0
