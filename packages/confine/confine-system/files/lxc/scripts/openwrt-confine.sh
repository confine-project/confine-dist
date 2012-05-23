

customize_rootfs() {
    SL_NAME=$1

    rm -rf $LXC_IMAGES_PATH/$SL_NAME/rootfs/etc/init.d/firewall

    cat <<EOF > $LXC_IMAGES_PATH/$SL_NAME/rootfs/etc/config/network

config 'interface' 'loopback'
        option 'ifname' 'lo'
        option 'proto' 'static'
        option 'ipaddr' '127.0.0.1'
        option 'netmask' '255.0.0.0'
EOF

#    uci_set network.loopback.bla=blub path=$LXC_IMAGES_PATH/$SL_NAME/rootfs/etc/config


    cat <<EOF > $LXC_IMAGES_PATH/$SL_NAME/rootfs/etc/config/system

config system
        option hostname $SL_NAME
        option timezone UTC

config timeserver ntp
        list server     0.openwrt.pool.ntp.org
        list server     1.openwrt.pool.ntp.org
        list server     2.openwrt.pool.ntp.org
        list server     3.openwrt.pool.ntp.org

EOF

    cat <<EOF > $LXC_IMAGES_PATH/$SL_NAME/rootfs/etc/inittab
::sysinit:/etc/init.d/rcS S boot
::shutdown:/etc/init.d/rcS K stop
console::askfirst:/bin/ash --login
#tts/0::askfirst:/bin/ash --login
#ttyS0::askfirst:/bin/ash --login
tty1::askfirst:/bin/ash --login
tty2::askfirst:/bin/ash --login
tty3::askfirst:/bin/ash --login
tty4::askfirst:/bin/ash --login

EOF



}




