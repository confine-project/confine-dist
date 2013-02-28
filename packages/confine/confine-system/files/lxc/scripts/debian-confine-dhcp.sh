
customize_rootfs() {
    SL_NAME=$1

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

    echo "${MY_SLICE}_${MY_NODE}" > $LXC_IMAGES_PATH/$SL_NAME/rootfs/etc/hostname


    local IF01_NAME="$(uci_get confine-slivers.$MY_SLICE.if01_name)"
    local IPV6_ADDR="$(uci_get confine-slivers.$MY_SLICE.if01_ipv6)"
    local IPV6_GW="$( uci_get confine.testbed.mgmt_ipv6_prefix48 ):$MY_NODE::2"

    cat <<EOF > $LXC_IMAGES_PATH/$SL_NAME/rootfs/etc/network/interfaces

auto lo
iface lo inet loopback

#auto eth0
#iface eth0 inet dhcp

auto  $IF01_NAME
iface $IF01_NAME inet dhcp

iface $IF01_NAME inet6 static
address $( echo $IPV6_ADDR | awk -F'/' '{print $1}' )
netmask $( echo $IPV6_ADDR | awk -F'/' '{print $2}' )
gateway $IPV6_GW

EOF


}







