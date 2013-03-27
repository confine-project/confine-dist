
customize_rootfs() {
    CT_NR=$1

	local MY_NODE="$( uci_get confine.node.id )"
	local TMP_SLICES="$( uci_get_sections confine-slivers sliver soft )"
	local TMP_SLICE=
	local SL_ID=
	for TMP_SLICE in $TMP_SLICES ; do
		
		if [ "$(uci_get confine-slivers.$TMP_SLICE.sliver_nr soft,quiet )" = "$CT_NR" ] ; then
			SL_ID=$TMP_SLICE
			break;
		fi
	done
    
	[ "$SL_ID" ] || err $FUNCNAME "Can not find SLICE! TMP_SLICES=$TMP_SLICES" 
    
	echo "${SL_ID}_${MY_NODE}" > $LXC_IMAGES_PATH/$CT_NR/rootfs/etc/hostname



	local IF_KEYS="$( uci_get lxc.general.lxc_if_keys )"
	local TMP_KEY=
	local PUBLIC4_KEY=
	local MGMT_KEY=
	local PUBLIC4_PROTO="$(uci_get confine.node.sl_public_ipv4_proto)"
	
	for TMP_KEY in $IF_KEYS; do
		local TMP_TYPE="$(uci_get confine-slivers.$SL_ID.if${TMP_KEY}_type soft,quiet)"
		if [ "$TMP_TYPE" ]; then
			if [ "$TMP_TYPE" = "public" ]; then
				PUBLIC4_KEY=$TMP_KEY
				MGMT_KEY=$TMP_KEY
			fi
			if [ "$TMP_TYPE" = "public4" ]; then
				PUBLIC4_KEY=$TMP_KEY
			fi
			if [ "$TMP_TYPE" = "management" ]; then
				MGMT_KEY=$TMP_KEY
			fi
		else
			break
		fi
	done


    cat <<EOF > $LXC_IMAGES_PATH/$CT_NR/rootfs/etc/network/interfaces

auto lo
iface lo inet loopback

EOF

	if [ "$PUBLIC4_KEY" ] && [ "$PUBLIC4_PROTO" = "dhcp" ]; then
		
		local PUBLIC4_NAME="$(uci_get confine-slivers.$SL_ID.if${PUBLIC4_KEY}_name)"
		
		cat <<EOF >> $LXC_IMAGES_PATH/$CT_NR/rootfs/etc/network/interfaces
auto  $PUBLIC4_NAME
iface $PUBLIC4_NAME inet dhcp

EOF
	fi


	if [ "$MGMT_KEY" ]; then
		
		local MGMT_NAME="$(uci_get confine-slivers.$SL_ID.if${MGMT_KEY}_name)"
		local MGMT_ADDR="$(uci_get confine-slivers.$SL_ID.if${MGMT_KEY}_ipv6)"
		local MGMT_GW="$( uci_get confine.testbed.mgmt_ipv6_prefix48 ):$MY_NODE::2"

		cat <<EOF >> $LXC_IMAGES_PATH/$CT_NR/rootfs/etc/network/interfaces
auto $MGMT_NAME
iface $MGMT_NAME inet6 static
pre-up ip link set $MGMT_NAME down
address $( echo $MGMT_ADDR | awk -F'/' '{print $1}' )
netmask $( echo $MGMT_ADDR | awk -F'/' '{print $2}' )
gateway $MGMT_GW

EOF
	fi



	mkdir -p $LXC_IMAGES_PATH/$CT_NR/rootfs/root/confine/uci
	mkdir -p $LXC_IMAGES_PATH/$CT_NR/rootfs/root/confine/data

	uci_show confine-slice-attributes | \
	    grep -e "^confine-slice-attributes.${SL_ID}_" | \
	    uci_dot_to_file confine-slice-attributes > $LXC_IMAGES_PATH/$CT_NR/rootfs/root/confine/uci/confine-slice-attributes

	local USER_PUBKEY="$( uci_get confine-slivers.$SL_ID.user_pubkey soft,quiet )"

	mkdir -p $LXC_IMAGES_PATH/$CT_NR/rootfs/root/.ssh/
	[ "$USER_PUBKEY" ] && echo "$USER_PUBKEY" >> $LXC_IMAGES_PATH/$CT_NR/rootfs/root/.ssh/authorized_keys	    

}







