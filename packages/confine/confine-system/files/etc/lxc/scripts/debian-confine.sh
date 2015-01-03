
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
	
	local BASE_PATH="$( readlink -f $LXC_IMAGES_PATH/$CT_NR )"
	
	readlink -f -m $LXC_IMAGES_PATH/$CT_NR/rootfs/etc/hostname           | grep -e "^$BASE_PATH" >/dev/null &&\
	readlink -f -m $LXC_IMAGES_PATH/$CT_NR/rootfs/etc/network/interfaces | grep -e "^$BASE_PATH" >/dev/null &&\
	readlink -f -m $LXC_IMAGES_PATH/$CT_NR/rootfs/etc/resolv.conf        | grep -e "^$BASE_PATH" >/dev/null &&\
	readlink -f -m $LXC_IMAGES_PATH/$CT_NR/rootfs/root/.ssh              | grep -e "^$BASE_PATH" >/dev/null || {
		err $FUNCNAME "debian sliver=$SL_ID rootfs contains illegal links!"
	}
	
    
	echo "${SL_ID}_${MY_NODE}" > $LXC_IMAGES_PATH/$CT_NR/rootfs/etc/hostname
	
	local IF_KEYS="$( uci_get lxc.general.lxc_if_keys )"
	local TMP_KEY=
	local PRIVATE_KEY=
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
			if [ "$TMP_TYPE" = "private" ]; then
				PRIVATE_KEY=$TMP_KEY
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


	if [ "$PRIVATE_KEY" ]; then
		
		local PRIVATE_NAME="$(uci_get confine-slivers.$SL_ID.if${PRIVATE_KEY}_name)"
		local PRIVATE_IPV4="$(uci_get confine-slivers.$SL_ID.if${PRIVATE_KEY}_ipv4 | cut -d'/' -f1)"
		local PRIVATE_GWV4="$(echo $PRIVATE_IPV4 | awk -F'.' '{print $1"."$2"."$3".126"}')"
		local PRIVATE_IPV6="$(uci_get confine-slivers.$SL_ID.if${PRIVATE_KEY}_ipv6)"
		
		cat <<EOF >> $LXC_IMAGES_PATH/$CT_NR/rootfs/etc/network/interfaces
auto $PRIVATE_NAME
iface $PRIVATE_NAME inet6 static
pre-up ip link set $PRIVATE_NAME down
address $( echo $PRIVATE_IPV6 | awk -F'/' '{print $1}' )
netmask $( echo $PRIVATE_IPV6 | awk -F'/' '{print $2}' )

iface $PRIVATE_NAME inet static
address $PRIVATE_IPV4
netmask 255.255.255.128
EOF
		if ! [ "$PUBLIC4_KEY" ]; then
			cat <<EOF >> $LXC_IMAGES_PATH/$CT_NR/rootfs/etc/network/interfaces
gateway $PRIVATE_GWV4

EOF
		else
			cat <<EOF >> $LXC_IMAGES_PATH/$CT_NR/rootfs/etc/network/interfaces

EOF
		fi
		

		rm -rf $LXC_IMAGES_PATH/$CT_NR/rootfs/etc/resolv.conf
		cat <<EOF > $LXC_IMAGES_PATH/$CT_NR/rootfs/etc/resolv.conf
nameserver $PRIVATE_GWV4
EOF
	fi

	
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
		local MGMT_GW="$(  uci_get confine.testbed.mgmt_ipv6_prefix48 ):$MY_NODE::2"
		local MGMT_NET="$( uci_get confine.testbed.mgmt_ipv6_prefix48 )::/48"

		cat <<EOF >> $LXC_IMAGES_PATH/$CT_NR/rootfs/etc/network/interfaces
auto $MGMT_NAME
iface $MGMT_NAME inet6 static
pre-up ip link set $MGMT_NAME down
address $( echo $MGMT_ADDR | awk -F'/' '{print $1}' )
netmask $( echo $MGMT_ADDR | awk -F'/' '{print $2}' )
#gateway $MGMT_GW
up   ip -6 route add $MGMT_NET via $MGMT_GW dev $MGMT_NAME
down ip -6 route del $MGMT_NET via $MGMT_GW dev $MGMT_NAME

EOF
	fi

	local USER_PUBKEY="$( uci_get confine-slivers.$SL_ID.user_pubkey soft,quiet )"

	mkdir -p $LXC_IMAGES_PATH/$CT_NR/rootfs/root/.ssh/
	[ "$USER_PUBKEY" ] && echo "$USER_PUBKEY" >> $LXC_IMAGES_PATH/$CT_NR/rootfs/root/.ssh/authorized_keys	    

	[ -f $LXC_IMAGES_PATH/$CT_NR/rootfs/etc/ssh/ssh_host_rsa_key ] || ssh-keygen -q -f $LXC_IMAGES_PATH/$CT_NR/rootfs/etc/ssh/ssh_host_rsa_key -N '' -t rsa
	[ -f $LXC_IMAGES_PATH/$CT_NR/rootfs/etc/ssh/ssh_host_dsa_key ] || ssh-keygen -q -f $LXC_IMAGES_PATH/$CT_NR/rootfs/etc/ssh/ssh_host_dsa_key -N '' -t dsa	
}







