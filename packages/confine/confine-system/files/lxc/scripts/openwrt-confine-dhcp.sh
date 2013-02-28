customize_rootfs() {
    SL_NAME=$1

    rm -rf $LXC_IMAGES_PATH/$SL_NAME/rootfs/etc/init.d/firewall

    local MY_NODE="$( uci_get confine.node.id )"
    local TMP_SLICES="$( uci_get_sections confine-slivers sliver soft )"
    local TMP_SLICE=
    local MY_SLICE=
    for TMP_SLICE in $TMP_SLICES ; do
		
	if [ "$(uci_get confine-slivers.$TMP_SLICE.sliver_nr soft,quiet )" = "$SL_NAME" ] ; then
	    MY_SLICE=$TMP_SLICE
	    break;
	fi
    done

    [ "$MY_SLICE" ] || err $FUNCNAME "Can not find SLICE! TMP_SLICES=$TMP_SLICES" 

#    uci_set network.loopback.bla=blub path=$LXC_IMAGES_PATH/$SL_NAME/rootfs/etc/config

    cat <<EOF > $LXC_IMAGES_PATH/$SL_NAME/rootfs/etc/config/system
config system
        option hostname ${MY_SLICE}_${MY_NODE}
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


    local IF01_NAME="$(uci_get confine-slivers.$MY_SLICE.if01_name)"

    cat <<EOF > $LXC_IMAGES_PATH/$SL_NAME/rootfs/etc/config/network
config 'interface' 'loopback'
        option 'ifname' 'lo'
        option 'proto' 'static'
        option 'ipaddr' '127.0.0.1'
        option 'netmask' '255.0.0.0'

config 'interface' 'public0'
        option 'ifname'  "$IF01_NAME"
        option 'proto'   'dhcp'

EOF


    local IPV6_ADDR="$(uci_get confine-slivers.$MY_SLICE.if01_ipv6)"
    local IPV6_GW="$( uci_get confine.testbed.mgmt_ipv6_prefix48 ):$MY_NODE::2"
    cat <<EOF >> $LXC_IMAGES_PATH/$SL_NAME/rootfs/etc/config/network

config 'alias' 'public0_ipv6'
        option 'interface' 'public0'
        option 'proto'     'static'
        option 'ip6addr'   "$IPV6_ADDR"
        option 'ip6gw'     "$IPV6_GW"

EOF


cp $LXC_IMAGES_PATH/$SL_NAME/rootfs/etc/config/uhttpd $LXC_IMAGES_PATH/$SL_NAME/rootfs/etc/config/uhttpd.orig
uci_set uhttpd.main.listen_http='0.0.0.0:80 [::]:80'    path=$LXC_IMAGES_PATH/$SL_NAME/rootfs/etc/config
uci_set uhttpd.main.listen_https='0.0.0.0:443 [::]:443' path=$LXC_IMAGES_PATH/$SL_NAME/rootfs/etc/config


}
