



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


    local IPV6_ADDR="$(uci_get confine-slivers.$MY_SLICE.if01_ipv6)"
    local IPV6_GW="$( uci_get confine.testbed.mgmt_ipv6_prefix48 ):$MY_NODE::2"

    cat <<EOF >> $LXC_IMAGES_PATH/$SL_NAME/rootfs/etc/network/interfaces


auto  pub0
iface pub0 inet dhcp
  up /sbin/ip -6 addr add $IPV6_ADDR dev pub0
  up /sbin/ip -6 route add ::/0 via $IPV6_GW
EOF


    cat <<EOF > $LXC_IMAGES_PATH/$SL_NAME/rootfs/etc/hostname
$SL_NAME
EOF



}







