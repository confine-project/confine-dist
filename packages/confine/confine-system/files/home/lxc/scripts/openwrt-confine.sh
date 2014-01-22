customize_rootfs() {
	CT_NR=$1
	
	rm -rf $LXC_IMAGES_PATH/$CT_NR/rootfs/etc/init.d/firewall
	
	local TELNET="$( ls $LXC_IMAGES_PATH/$CT_NR/rootfs/etc/rc.d | grep telnet )"
	if [ "$TELNET" ]; then
		rm -f $LXC_IMAGES_PATH/$CT_NR/rootfs/etc/rc.d/$TELNET
	fi

	local MY_NODE="$( uci_get confine.node.id )"
	local TMP_SLICES="$( uci_get_sections confine-slivers sliver soft )"
	local TMP_SLICE=
	local SL_ID=
	for TMP_SLICE in $TMP_SLICES ; do
		if [ "$(uci_get confine-slivers.$TMP_SLICE.sliver_nr soft,quiet )" = "$CT_NR" ] ; then
			SL_ID=$TMP_SLICE
			break
		fi
	done
	
	[ "$SL_ID" ] || err $FUNCNAME "Can not find SLICE! TMP_SLICES=$TMP_SLICES"
	
	
	local BASE_PATH="$( readlink -f $LXC_IMAGES_PATH/$CT_NR )"
	
	readlink -f -m $LXC_IMAGES_PATH/$CT_NR/rootfs/etc/config/system                           | grep -e "^$BASE_PATH" >/dev/null &&\
	readlink -f -m $LXC_IMAGES_PATH/$CT_NR/rootfs/etc/inittab                                 | grep -e "^$BASE_PATH" >/dev/null &&\
	readlink -f -m $LXC_IMAGES_PATH/$CT_NR/rootfs/etc/config/network                          | grep -e "^$BASE_PATH" >/dev/null &&\
	readlink -f -m $LXC_IMAGES_PATH/$CT_NR/rootfs/etc/config/uhttpd.orig                      | grep -e "^$BASE_PATH" >/dev/null &&\
	readlink -f -m $LXC_IMAGES_PATH/$CT_NR/rootfs/etc/config/uhttpd                           | grep -e "^$BASE_PATH" >/dev/null &&\
	readlink -f -m $LXC_IMAGES_PATH/$CT_NR/rootfs/etc/dropbear/authorized_keys                | grep -e "^$BASE_PATH" >/dev/null &&\
	readlink -f -m $LXC_IMAGES_PATH/$CT_NR/rootfs/etc/uci-defaults/000-backup-uci-defaults.sh | grep -e "^$BASE_PATH" >/dev/null || {
		err $FUNCNAME "openwrt sliver=$SL_ID rootfs contains illegal links!"
	}
    

	#uci_set network.loopback.bla=blub path=$LXC_IMAGES_PATH/$CT_NR/rootfs/etc/config

	cat <<EOF > $LXC_IMAGES_PATH/$CT_NR/rootfs/etc/config/system
config system
        option hostname ${SL_ID}_${MY_NODE}
        option timezone UTC

config timeserver ntp
        list server     0.openwrt.pool.ntp.org
        list server     1.openwrt.pool.ntp.org
        list server     2.openwrt.pool.ntp.org
        list server     3.openwrt.pool.ntp.org

EOF



	cat <<EOF > $LXC_IMAGES_PATH/$CT_NR/rootfs/etc/inittab
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

	cat <<EOF > $LXC_IMAGES_PATH/$CT_NR/rootfs/etc/config/network
EOF

	uci_set network.loopback="interface"  		path=$LXC_IMAGES_PATH/$CT_NR/rootfs/etc/config
	uci_set network.loopback.ifname="lo"  		path=$LXC_IMAGES_PATH/$CT_NR/rootfs/etc/config
	uci_set network.loopback.proto="static"  	path=$LXC_IMAGES_PATH/$CT_NR/rootfs/etc/config
	uci_set network.loopback.ipaddr="127.0.0.1"  	path=$LXC_IMAGES_PATH/$CT_NR/rootfs/etc/config
	uci_set network.loopback.netmask="255.0.0.0"  	path=$LXC_IMAGES_PATH/$CT_NR/rootfs/etc/config

	if [ "$PRIVATE_KEY" ]; then
		
		local PRIVATE_NAME="$(uci_get confine-slivers.$SL_ID.if${PRIVATE_KEY}_name)"
		local PRIVATE_IPV4="$(uci_get confine-slivers.$SL_ID.if${PRIVATE_KEY}_ipv4 | cut -d'/' -f1)"
		local PRIVATE_GWV4="$(echo $PRIVATE_IPV4 | awk -F'.' '{print $1"."$2"."$3".126"}')"
		local PRIVATE_IPV6="$(uci_get confine-slivers.$SL_ID.if${PRIVATE_KEY}_ipv6)"
		
		uci_set network.private="interface"  			path=$LXC_IMAGES_PATH/$CT_NR/rootfs/etc/config
		uci_set network.private.ifname="$PRIVATE_NAME"		path=$LXC_IMAGES_PATH/$CT_NR/rootfs/etc/config
		uci_set network.private.proto="static"			path=$LXC_IMAGES_PATH/$CT_NR/rootfs/etc/config
		uci_set network.private.ip6addr="$PRIVATE_IPV6"		path=$LXC_IMAGES_PATH/$CT_NR/rootfs/etc/config
		uci_set network.private.ipaddr="$PRIVATE_IPV4"		path=$LXC_IMAGES_PATH/$CT_NR/rootfs/etc/config
		uci_set network.private.netmask='255.255.255.128'	path=$LXC_IMAGES_PATH/$CT_NR/rootfs/etc/config
		
		if ! [ "$PUBLIC4_KEY" ]; then
			uci_set network.private.gateway="$PRIVATE_GWV4"	path=$LXC_IMAGES_PATH/$CT_NR/rootfs/etc/config
			
			#uci_set dhcp.@dnsmasq[0].server="$PRIVATE_GWV4"	path=$LXC_IMAGES_PATH/$CT_NR/rootfs/etc/config
			if [ "$(uci changes dhcp)" == "" ]; then
				uci -c $LXC_IMAGES_PATH/$CT_NR/rootfs/etc/config add_list dhcp.@dnsmasq[0].server="$PRIVATE_GWV4" && uci -c $LXC_IMAGES_PATH/$CT_NR/rootfs/etc/config commit dhcp || true
			fi
		fi
	fi

	if [ "$PUBLIC4_KEY" ] && [ "$PUBLIC4_PROTO" = "dhcp" ]; then
		
		local PUBLIC4_NAME="$(uci_get confine-slivers.$SL_ID.if${PUBLIC4_KEY}_name)"
		
		uci_set network.public4="interface"  			path=$LXC_IMAGES_PATH/$CT_NR/rootfs/etc/config
		uci_set network.public4.ifname="$PUBLIC4_NAME"		path=$LXC_IMAGES_PATH/$CT_NR/rootfs/etc/config
		uci_set network.public4.proto="dhcp"			path=$LXC_IMAGES_PATH/$CT_NR/rootfs/etc/config
	fi

	if [ "$MGMT_KEY" ]; then
		
		local MGMT_NAME="$(uci_get confine-slivers.$SL_ID.if${MGMT_KEY}_name)"
		local MGMT_ADDR="$(uci_get confine-slivers.$SL_ID.if${MGMT_KEY}_ipv6)"
		local MGMT_GW="$( uci_get confine.testbed.mgmt_ipv6_prefix48 ):$MY_NODE::2"
		
		uci_set network.management="interface"  		path=$LXC_IMAGES_PATH/$CT_NR/rootfs/etc/config
		uci_set network.management.ifname="$MGMT_NAME"		path=$LXC_IMAGES_PATH/$CT_NR/rootfs/etc/config
		uci_set network.management.proto="static"		path=$LXC_IMAGES_PATH/$CT_NR/rootfs/etc/config
		uci_set network.management.ip6addr="$MGMT_ADDR"		path=$LXC_IMAGES_PATH/$CT_NR/rootfs/etc/config
		uci_set network.management.ip6gw="$MGMT_GW"		path=$LXC_IMAGES_PATH/$CT_NR/rootfs/etc/config
	fi




	cp $LXC_IMAGES_PATH/$CT_NR/rootfs/etc/config/uhttpd $LXC_IMAGES_PATH/$CT_NR/rootfs/etc/config/uhttpd.orig
	uci_set uhttpd.main.listen_http='0.0.0.0:80 [::]:80'    path=$LXC_IMAGES_PATH/$CT_NR/rootfs/etc/config
	uci_set uhttpd.main.listen_https='0.0.0.0:443 [::]:443' path=$LXC_IMAGES_PATH/$CT_NR/rootfs/etc/config


	local USER_PUBKEY="$( uci_get confine-slivers.$SL_ID.user_pubkey soft,quiet )"

	#mkdir -p $LXC_IMAGES_PATH/$CT_NR/rootfs/root/.ssh/
	#[ "$USER_PUBKEY" ] && echo "$USER_PUBKEY" >> $LXC_IMAGES_PATH/$CT_NR/rootfs/root/.ssh/authorized_keys	    
	mkdir -p $LXC_IMAGES_PATH/$CT_NR/rootfs/etc/dropbear/
	[ "$USER_PUBKEY" ] && echo "$USER_PUBKEY" >> $LXC_IMAGES_PATH/$CT_NR/rootfs/etc/dropbear/authorized_keys
	    
	cat <<EOF > $LXC_IMAGES_PATH/$CT_NR/rootfs/etc/uci-defaults/000-backup-uci-defaults.sh
#!/bin/sh

echo "Backung up uci-default scripts"

mkdir -p /etc/uci-applied-defaults
cp /etc/uci-defaults/* /etc/uci-applied-defaults/
EOF



# set random passwd (FIXME: not working!):
	local PASSWD="$( dd if=/dev/urandom  bs=1 count=8 2>/dev/null | hexdump -e '/4 "%08X" /4 "%08X" "\n"' )"
	cat <<EOF1 > /dev/null # $LXC_IMAGES_PATH/$CT_NR/rootfs/etc/uci-defaults/random-passwd.sh
#!/bin/sh
echo "Setting random passwd=$PASSWD (disabling telnet, enabling ssh authorized key login)"
passwd <<EOF2
$PASSWD
$PASSWD
EOF2
EOF1

}
