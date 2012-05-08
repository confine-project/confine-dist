#!/bin/bash

set -u # set -o nounset
#set -o errexit

if [ -f ./vct.conf ]; then
    . ./vct.conf
elif [ -f ./vct.conf.default ]; then
	. ./vct.conf.default
fi


# MAIN_PID=$BASHPID

UCI_DEFAULT_PATH=$VCT_UCI_DIR
ERR_LOG_TAG='VCT'
. ./lxc.functions
. ./confine.functions




##########################################################################
#######  some general tools for convinience
##########################################################################



vct_sudo() {

    local QUERY=

    if [ "$VCT_SUDO_ASK" != "NO" ]; then

	echo "$0 wants to execute (VCT_SUDO_ASK=$VCT_SUDO_ASK set to ask):" >&2
	echo ">>>>   sudo $@   <<<<" >&2
	read -p "please type y to continue or anything else to abort: " QUERY >&2

	if [ "$QUERY" == "y" ] ; then
	    sudo $@
	    return $?
	fi
	
	err $FUNCNAME "sudo execution cancelled: $QUERY"
	return 1
    fi

    sudo $@
    return $?
}




##########################################################################
#######  
##########################################################################

vct_system_config_check() {

    variable_check VCT_SUDO_ASK        quiet
    variable_check VCT_VIRT_DIR        quiet
    variable_check VCT_SYS_DIR         quiet
    variable_check VCT_DL_DIR          quiet
    variable_check VCT_RPC_DIR         quiet
    variable_check VCT_MNT_DIR         quiet
    variable_check VCT_UCI_DIR         quiet
    variable_check VCT_DEB_PACKAGES    quiet
    variable_check VCT_USER            quiet
    variable_check VCT_VIRT_GROUP      quiet
    variable_check VCT_BRIDGE_PREFIXES quiet
    variable_check VCT_TOOL_TESTS      quiet
    variable_check VCT_INTERFACE_MODEL quiet
    variable_check VCT_INTERFACE_MAC24 quiet



# Typical cases:
# VCT_TEMPLATE_URL="http://distro.confine-project.eu/rd-images/openwrt-x86-generic-combined-ext4.img.tgz"
# VCT_TEMPLATE_URL="ssh:22:user@example.org:///confine/confine-dist/openwrt/bin/x86/openwrt-x86-generic-combined-ext4.img.gz"
# VCT_TEMPLATE_URL="file:///../../openwrt/bin/x86/openwrt-x86-generic-combined-ext4.img.gz"

    variable_check VCT_TEMPLATE_URL  quiet

    VCT_TEMPLATE_COMP=$( ( echo $VCT_TEMPLATE_URL | grep -e "\.tgz$" >/dev/null && echo "tgz" ) ||\
                         ( echo $VCT_TEMPLATE_URL | grep -e "\.tar\.gz$" >/dev/null && echo "tar.gz" ) ||\
                         ( echo $VCT_TEMPLATE_URL | grep -e "\.gz$" >/dev/null && echo "gz" ) )
    variable_check VCT_TEMPLATE_COMP quiet
    VCT_TEMPLATE_TYPE=$(echo $VCT_TEMPLATE_URL | awk -F $VCT_TEMPLATE_COMP '{print $1}' | awk -F'.' '{print $(NF-1)}')
    variable_check VCT_TEMPLATE_TYPE quiet
    VCT_TEMPLATE_NAME=$(echo $VCT_TEMPLATE_URL | awk -F'/' '{print $(NF)}' | awk -F'.' '{print $1}')
    variable_check VCT_TEMPLATE_NAME quiet
    VCT_TEMPLATE_SITE=$(echo $VCT_TEMPLATE_URL | awk -F ${VCT_TEMPLATE_NAME}.${VCT_TEMPLATE_TYPE}.${VCT_TEMPLATE_COMP} '{print $1}')
    variable_check VCT_TEMPLATE_SITE quiet

    ( [ $VCT_TEMPLATE_TYPE = "vmdk" ] || [ $VCT_TEMPLATE_TYPE = "raw" ] || [ $VCT_TEMPLATE_TYPE = "img" ] ) ||\
           err $FUNCNAME "Non-supported fs template type $URL_TYPE"

    [ "$VCT_TEMPLATE_URL" = "${VCT_TEMPLATE_SITE}${VCT_TEMPLATE_NAME}.${VCT_TEMPLATE_TYPE}.${VCT_TEMPLATE_COMP}" ] ||\
           err $FUNCNAME "Invalid $VCT_TEMPLATE_URL != ${VCT_TEMPLATE_SITE}${VCT_TEMPLATE_NAME}.${VCT_TEMPLATE_TYPE}.${VCT_TEMPLATE_COMP}"

}


vct_system_install_check() {

    local OPT_CMD=${1:-}
    local CMD_SOFT=$( echo "$OPT_CMD" | grep -e "soft" > /dev/null && echo "soft," || echo "" )
    local CMD_QUICK=$( echo "$OPT_CMD" | grep -e "quick" > /dev/null && echo "quick," || echo "" )
    local CMD_INSTALL=$( echo "$OPT_CMD" | grep -e "install" > /dev/null && echo "install," || echo "" )
    local CMD_UPDATE=$( echo "$OPT_CMD" | grep -e "update" > /dev/null && echo "update," || echo "" )

    # check if correct user:
    if [ $(whoami) != $VCT_USER ] || [ $(whoami) = root ] ;then
	err $FUNCNAME "command must be executed as user=$VCT_USER" $CMD_SOFT || return 1
    fi

    # check debian system, packages, tools, and kernel modules
    ! aptitude --version > /dev/null && dpkg --version > /dev/null &&\
	{ err $FUNCNAME "missing debian system tool dpkg or aptitude" $CMD_SOFT || return 1 ;}
    
    if ! [ $CMD_QUICK ]; then

	local PACKAGE=
	local UPDATED=
	for PACKAGE in $VCT_DEB_PACKAGES; do
	    if ! dpkg -s $PACKAGE 2>&1 |grep "Status:" |grep "install" |grep "ok" |grep "installed" > /dev/null ; then
		echo "Missing debian package: $PACKAGE! Trying to install all required packets..."
		( [ $CMD_INSTALL ] && ( [ $UPDATED ] || UPDATED=$( vct_sudo "aptitude update") ) && vct_sudo "aptitude install $PACKAGE" && \
		    dpkg -s $PACKAGE 2>&1 |grep "Status:" |grep "install" |grep "ok" |grep "installed" > /dev/null ) ||\
                   { err $FUNCNAME "Missing debian packages $PACKAGE !!!" $CMD_SOFT || return 1 ;}
	    fi
	done

	local TOOL_POS=
	local TOOL_CMD=
	for TOOL_POS in $(seq 0 $(( ${#VCT_TOOL_TESTS[@]} - 1)) ); do
	    TOOL_CMD=${VCT_TOOL_TESTS[$TOOL_POS]}
	    $TOOL_CMD  > /dev/null 2>&1 ||\
		{ err $FUNCNAME "Please install linux tool: $TOOL_CMD  !! " $CMD_SOFT || return 1 ;}
	done

    fi

    # check if user is in required groups:
    groups | grep "$VCT_VIRT_GROUP" > /dev/null ||\
	{ err $FUNCNAME "user=$VCT_USER MUST be in groups: $VCT_VIRT_GROUP \n do: sudo adduser $VCT_USER $VCT_VIRT_GROUP and ReLogin!" $CMD_SOFT || return 1 ;}



    if ! [ -d $VCT_VIRT_DIR ]; then
	( [ $CMD_INSTALL ] && vct_sudo mkdir -p $VCT_VIRT_DIR ) && vct_sudo chown $VCT_USER $VCT_VIRT_DIR ||\
	 { err $FUNCNAME "$VCT_VIRT_DIR not existing" $CMD_SOFT || return 1 ;}
    fi

    # check libvirt systems directory:
    if ! [ -d $VCT_SYS_DIR ]; then
	( [ $CMD_INSTALL ] && mkdir -p $VCT_SYS_DIR ) ||\
	 { err $FUNCNAME "$VCT_SYS_DIR not existing" $CMD_SOFT || return 1 ;}
    fi

    # check downloads directory:
    if ! [ -d $VCT_DL_DIR ]; then
	( [ $CMD_INSTALL ] && mkdir -p $VCT_DL_DIR ) ||\
	 { err $FUNCNAME "$VCT_DL_DIR  not existing" $CMD_SOFT || return 1 ;}
    fi

    # check rpc-file directory:
    if ! [ -d $VCT_RPC_DIR ]; then
	( [ $CMD_INSTALL ] && mkdir -p $VCT_RPC_DIR ) ||\
	 { err $FUNCNAME "$VCT_RPC_DIR  not existing" $CMD_SOFT || return 1 ;}
    fi

    # check node mount directory:
    if ! [ -d $VCT_MNT_DIR ]; then
	( [ $CMD_INSTALL ] && mkdir -p $VCT_MNT_DIR ) ||\
	 { err $FUNCNAME "$VCT_MNT_DIR  not existing" $CMD_SOFT || return 1 ;}
    fi

    # check vct uci directory:
    if ! [ -d $VCT_UCI_DIR ]; then
	( [ $CMD_INSTALL ] && mkdir -p $VCT_UCI_DIR ) ||\
	 { err $FUNCNAME "$VCT_UCI_DIR  not existing" $CMD_SOFT || return 1 ;}
    fi


    if ! [ -f $VCT_KNOWN_HOSTS_FILE ]; then
	( [ $CMD_INSTALL ] && touch $VCT_KNOWN_HOSTS_FILE ) ||\
	 { err $FUNCNAME "$VCT_KNOWN_HOSTS_FILE not existing" $CMD_SOFT || return 1 ;}
    fi

    # check for existing or downloadable file-system-template file:
    if ! install_url $VCT_TEMPLATE_URL $VCT_TEMPLATE_SITE $VCT_TEMPLATE_NAME.$VCT_TEMPLATE_TYPE $VCT_TEMPLATE_COMP $VCT_DL_DIR 0 $OPT_CMD ; then
	err $FUNCNAME "Installing ULR=$VCT_TEMPLATE_URL failed" $CMD_SOFT || return 1
    fi
	
}

vct_system_install() {
    vct_system_install_check "install,$@"
}


vct_system_init_check(){

    local OPT_CMD=${1:-}
    local CMD_SOFT=$( echo "$OPT_CMD" | grep -e "soft" > /dev/null && echo "soft," || echo "" )
    local CMD_QUICK=$( echo "$OPT_CMD" | grep -e "quick" > /dev/null && echo "quick," || echo "" )
    local CMD_INIT=$( echo "$OPT_CMD" | grep -e "init" > /dev/null && echo "init," || echo "" )

    vct_system_install_check $( [ $CMD_SOFT ] && echo "soft," )$( [ $CMD_QUICK ] && echo "quick," )

    # check if  kernel modules are loaded:
    local KMOD=
    for KMOD in $VCT_KERNEL_MODULES; do
	if ! lsmod | grep "$( echo $KMOD | sed s/-/_/ )" > /dev/null ; then
	    ( [ $CMD_INIT ]  &&\
		  vct_sudo "modprobe $KMOD " ) ||\
                	{ err $FUNCNAME "Failed loading module $KMOD" $CMD_SOFT || return 1 ;}
	fi
    done


    # check if libvirtd is running:
    ! virsh --connect qemu:///system list --all > /dev/null &&\
	{ err $FUNCNAME "libvirt-bin service not running! " $CMD_SOFT || return 1 ;}


    # check if bridges are initialized:
    local BRIDGE=
    local BR_NAME=
    for BRIDGE in $VCT_BRIDGE_PREFIXES; do
	if BR_NAME=$( variable_check ${BRIDGE}_NAME soft ); then

            # check if bridge exist:
	    if ! brctl show | grep $BR_NAME >/dev/null; then
		( [ $CMD_INIT ]                &&\
		  vct_sudo "brctl addbr $BR_NAME && brctl setfd $BR_NAME 0 && brctl sethello $BR_NAME 1 && brctl stp $BR_NAME off" ) ||\
                	{ err $FUNCNAME "unconfigured bridge $BR_NAME" $CMD_SOFT || return 1 ;}
	    fi

            # check if local bridge has rescue IPv4 address (A) for local network: 
	    local BR_V4_RESCUE_IP=$( variable_check ${BRIDGE}_V4_RESCUE_IP soft 2>/dev/null ) 
	    local BR_V4_RESCUE_PL=$( variable_check ${BRIDGE}_V4_RESCUE_PL soft 2>/dev/null )
	    if [ $BR_V4_RESCUE_IP ] && [ $BR_V4_RESCUE_PL ]; then
		if ! ip addr show dev $BR_NAME | grep -e "inet " |grep -e " $BR_V4_RESCUE_IP/$BR_V4_RESCUE_PL " |grep -e " $BR_NAME" >/dev/null; then
		    ( [ $CMD_INIT ] && vct_sudo ip addr add $BR_V4_RESCUE_IP/$BR_V4_RESCUE_PL dev $BR_NAME label $BR_NAME:resc) ||\
                	{ err $FUNCNAME "unconfigured ipv4 rescue net: $BR_NAME  $BR_V4_RESCUE_IP/$BR_V4_RESCUE_PL " $CMD_SOFT || return 1 ;}
		fi
	    fi

            # check if local bridge has IPv4 address for local network: 
	    local BR_V4_LOCAL_IP=$( variable_check ${BRIDGE}_V4_LOCAL_IP soft 2>/dev/null ) 
	    local BR_V4_LOCAL_PL=$( variable_check ${BRIDGE}_V4_LOCAL_PL soft 2>/dev/null )
	    if [ $BR_V4_LOCAL_IP ] && [ $BR_V4_LOCAL_PL ]; then
		if ! ip addr show dev $BR_NAME | grep -e "inet " |grep -e " $BR_V4_LOCAL_IP/$BR_V4_LOCAL_PL " |grep -e " $BR_NAME" >/dev/null; then
		    ( [ $CMD_INIT ] && vct_sudo ip addr add $BR_V4_LOCAL_IP/$BR_V4_LOCAL_PL dev $BR_NAME ) ||\
                	{ err $FUNCNAME "unconfigured ipv4 rescue net: $BR_NAME  $BR_V4_LOCAL_IP/$BR_V4_LOCAL_PL " $CMD_SOFT || return 1 ;}
		fi

            # check if bridge needs routed NAT:
		local BR_V4_NAT_OUT=$( variable_check ${BRIDGE}_V4_NAT_OUT_DEV soft 2>/dev/null )
		local BR_V4_NAT_SRC=$( variable_check ${BRIDGE}_V4_NAT_OUT_SRC soft 2>/dev/null )
		
		if [ $BR_V4_NAT_SRC ] && [ $BR_V4_NAT_OUT ] && [ -z $CMD_QUICK ]; then
		    
                    if ! vct_sudo iptables -t nat -L POSTROUTING -nv | \
			grep -e "MASQUERADE" |grep -e "$BR_V4_NAT_OUT" |grep -e "$BR_V4_NAT_SRC" >/dev/null; then

			( [ $CMD_INIT ] && vct_sudo iptables -t nat -I POSTROUTING -o $BR_V4_NAT_OUT -s $BR_V4_NAT_SRC -j MASQUERADE ) ||\
                  	{ err $FUNCNAME "invalid NAT from $BR_NAME" $CMD_SOFT || return 1 ;}
		    fi 
		    
		    if ! [ $(cat /proc/sys/net/ipv4/ip_forward) = "1" ]; then
		    [ $CMD_INIT ] && vct_sudo sysctl -w net.ipv4.ip_forward=1 > /dev/null
		    fi
		fi

	    # check if bridge needs udhcpd:
		local DHCPD_IP_MIN=$( variable_check ${BRIDGE}_V4_DHCPD_IP_MIN soft 2>/dev/null )
		local DHCPD_IP_MAX=$( variable_check ${BRIDGE}_V4_DHCPD_IP_MAX soft 2>/dev/null )
		local DHCPD_DNS=$( variable_check ${BRIDGE}_V4_DHCPD_DNS soft 2>/dev/null )

		local UDHCPD_CONF_FILE=$VCT_VIRT_DIR/udhcpd-$BR_NAME.conf
		local UDHCPD_LEASE_FILE=$VCT_VIRT_DIR/udhcpd-$BR_NAME.leases
		local UDHCPD_COMMAND="udhcpd $UDHCPD_CONF_FILE"
		local UDHCPD_PID=$( ps aux | grep "$UDHCPD_COMMAND" | grep -v grep | awk '{print $2}' )
	    
		[ $CMD_INIT ] && [ ${UDHCPD_PID:-} ] && vct_sudo kill $UDHCPD_PID && sleep 1
		

		if [ $DHCPD_IP_MIN ] && [ $DHCPD_IP_MAX ] && [ $DHCPD_DNS ]; then

		    if [ $CMD_INIT ] ; then
			cat <<EOF > $UDHCPD_CONF_FILE
start           $DHCPD_IP_MIN
end             $DHCPD_IP_MAX
interface       $BR_NAME 
lease_file      $UDHCPD_LEASE_FILE
option router   $BR_V4_LOCAL_IP
option dns      $DHCPD_DNS
option serverid $BR_V4_LOCAL_IP
EOF

			vct_sudo udhcpd $UDHCPD_CONF_FILE
		    fi
		    
		    [ "$(ps aux | grep "$UDHCPD_COMMAND" | grep -v grep )" ] || \
			err $FUNCNAME "NO udhcpd server running for $BR_NAME "
		fi
	    fi

            # check if local bridge has IPv6 for recovery network:
	    local BR_V6_RESCUE_IP=$( variable_check ${BRIDGE}_V6_RESCUE_IP soft 2>/dev/null ) 
	    local BR_V6_RESCUE_PL=$( variable_check ${BRIDGE}_V6_RESCUE_PL soft 2>/dev/null )
	    if [ $BR_V6_RESCUE_IP ] && [ $BR_V6_RESCUE_PL ]; then
		if ! ip addr show dev $BR_NAME | grep -e "inet6 " | \
		    grep -ie " $( ipv6calc -I ipv6 $BR_V6_RESCUE_IP/$BR_V6_RESCUE_PL -O ipv6 ) " >/dev/null; then
		    ( [ $CMD_INIT ] && vct_sudo ip addr add $BR_V6_RESCUE_IP/$BR_V6_RESCUE_PL dev $BR_NAME ) ||\
                	{ err $FUNCNAME "unconfigured ipv6 rescue net: $BR_NAME  $BR_V6_RESCUE_IP/$BR_V6_RESCUE_PL " $CMD_SOFT || return 1 ;}
		fi
	    fi

            # check if local bridge has IPv6 for debug network:
	    local BR_V6_DEBUG_IP=$( variable_check ${BRIDGE}_V6_DEBUG_IP soft 2>/dev/null ) 
	    local BR_V6_DEBUG_PL=$( variable_check ${BRIDGE}_V6_DEBUG_PL soft 2>/dev/null )
	    if [ $BR_V6_DEBUG_IP ] && [ $BR_V6_DEBUG_PL ]; then
		if ! ip addr show dev $BR_NAME | grep -e "inet6 " | \
		    grep -ie " $( ipv6calc -I ipv6 $BR_V6_DEBUG_IP/$BR_V6_DEBUG_PL -O ipv6 ) " >/dev/null; then
		    ( [ $CMD_INIT ] && vct_sudo ip addr add $BR_V6_DEBUG_IP/$BR_V6_DEBUG_PL dev $BR_NAME ) ||\
                	{ err $FUNCNAME "unconfigured ipv6 rescue net: $BR_NAME  $BR_V6_DEBUG_IP/$BR_V6_DEBUG_PL " $CMD_SOFT || return 1 ;}
		fi
	    fi



            # check if bridge is UP:
	    if ! ip link show dev $BR_NAME | grep ",UP" >/dev/null; then
		    ( [ $CMD_INIT ] && vct_sudo ip link set dev  $BR_NAME up ) ||\
                	{ err $FUNCNAME "disabled link $BR_NAME" $CMD_SOFT || return 1 ;}
	    fi

  

	fi
    done

    # check if bridge has disabled features:
    local PROC_FILE=
    for PROC_FILE in $(ls /proc/sys/net/bridge); do
	if ! [ $(cat /proc/sys/net/bridge/$PROC_FILE) = "0" ]; then
	    [ $CMD_INIT ] && vct_sudo sysctl -w net.bridge.$PROC_FILE=0 > /dev/null
	    [ $(cat /proc/sys/net/bridge/$PROC_FILE) = "0" ] ||\
	    { err $FUNCNAME "/proc/sys/net/bridge/$PROC_FILE != 0" $CMD_SOFT || return 1 ;}
	fi
    done
}


vct_system_init() {
    vct_system_init_check init
}


vct_system_cleanup() {

    local VCRD_ID=
    for VCRD_ID in $( vct_node_info | grep -e "$VCT_RD_NAME_PREFIX" | awk '{print $2}' | awk -F"$VCT_RD_NAME_PREFIX" '{print $2}' ); do
	vct_node_remove $VCRD_ID
    done



    local BRIDGE=
    local BR_NAME=
    for BRIDGE in $VCT_BRIDGE_PREFIXES; do
	if BR_NAME=$( variable_check ${BRIDGE}_NAME soft ); then

            # check if local bridge has IPv4 address for local network: 
	    local BR_V4_LOCAL_IP=$( variable_check ${BRIDGE}_V4_LOCAL_IP soft 2>/dev/null ) 
	    local BR_V4_LOCAL_PL=$( variable_check ${BRIDGE}_V4_LOCAL_PL soft 2>/dev/null )
	    if [ $BR_V4_LOCAL_IP ] && [ $BR_V4_LOCAL_PL ]; then

            # check if bridge had routed NAT:
		local BR_V4_NAT_OUT=$( variable_check ${BRIDGE}_V4_NAT_OUT_DEV soft 2>/dev/null )
		local BR_V4_NAT_SRC=$( variable_check ${BRIDGE}_V4_NAT_OUT_SRC soft 2>/dev/null )
		
		if [ $BR_V4_NAT_SRC ] && [ $BR_V4_NAT_OUT ]; then
		    
                    if vct_sudo iptables -t nat -L POSTROUTING -nv | \
			grep -e "MASQUERADE" |grep -e "$BR_V4_NAT_OUT" |grep -e "$BR_V4_NAT_SRC" >/dev/null; then

			vct_sudo iptables -t nat -D POSTROUTING -o $BR_V4_NAT_OUT -s $BR_V4_NAT_SRC -j MASQUERADE
		    fi 
		    
		fi

	    # check if bridge had udhcpd:
		local UDHCPD_CONF_FILE=$VCT_VIRT_DIR/udhcpd-$BR_NAME.conf
		local UDHCPD_LEASE_FILE=$VCT_VIRT_DIR/udhcpd-$BR_NAME.leases
		local UDHCPD_COMMAND="udhcpd $UDHCPD_CONF_FILE"
		local UDHCPD_PID=$( ps aux | grep "$UDHCPD_COMMAND" | grep -v grep | awk '{print $2}' )
	    
		[ ${UDHCPD_PID:-} ] && vct_sudo kill $UDHCPD_PID
		
	    fi

            # check if bridge is UP:
	    if ip link show dev $BR_NAME | grep ",UP" >/dev/null; then
		vct_sudo ip link set dev $BR_NAME down
	    fi

            # check if bridge exist:
	    if brctl show | grep $BR_NAME >/dev/null; then
		  vct_sudo brctl delbr $BR_NAME
	    fi
	fi
    done


}

##########################################################################
#######  
##########################################################################



vcrd_ids_get() {

    local VCRD_ID_RANGE=$1
    local VCRD_ID_STATE=${2:-}
    local VCRD_ID=

    if [ "$VCRD_ID_RANGE" = "all" ] ; then
	
	vct_node_info | grep -e "$VCT_RD_NAME_PREFIX" | grep -e "$VCRD_ID_STATE$" | \
	    awk -F" $VCT_RD_NAME_PREFIX" '{print $2}' | awk '{print $1}'

    elif echo $VCRD_ID_RANGE | grep -e "-" >/dev/null; then
	local VCRD_ID_MIN=$( echo $VCRD_ID_RANGE | awk -F'-' '{print $1}' )
	local VCRD_ID_MAX=$( echo $VCRD_ID_RANGE | awk -F'-' '{print $2}' )
	check_rd_id $VCRD_ID_MIN >/dev/null || err $FUNCNAME ""
	check_rd_id $VCRD_ID_MAX >/dev/null || err $FUNCNAME ""

	local DEC
	for DEC in $( seq $(( 16#${VCRD_ID_MIN} ))  $(( 16#${VCRD_ID_MAX} )) ); do 
	    check_rd_id $( printf "%.4x " $DEC )
	done
    else
	check_rd_id $VCRD_ID_RANGE
    fi
}


vct_node_info() {

    local VCRD_ID_RANGE=${1:-}

    if [ -z "$VCRD_ID_RANGE" ]; then

	virsh -c qemu:///system list --all

    else

	local VCRD_ID=
	for VCRD_ID in $( vcrd_ids_get $VCRD_ID_RANGE ); do
	    local VCRD_NAME="${VCT_RD_NAME_PREFIX}${VCRD_ID}"
	    virsh -c qemu:///system dominfo $VCRD_NAME
	done
    fi
}

vct_node_stop() {

    local VCRD_ID_RANGE=$1
    local VCRD_ID=

    for VCRD_ID in $( vcrd_ids_get $VCRD_ID_RANGE ); do

	local VCRD_NAME="${VCT_RD_NAME_PREFIX}${VCRD_ID}"

	if virsh -c qemu:///system dominfo $VCRD_NAME  2>/dev/null | grep -e "^State:" | grep "running" >/dev/null ; then
	    virsh -c qemu:///system destroy $VCRD_NAME ||\
	    err $FUNCNAME "Failed stopping domain $VCRD_NAME"
	fi
	
    done
}




vct_node_remove() {

    local VCRD_ID_RANGE=$1
    local VCRD_ID=

    for VCRD_ID in $( vcrd_ids_get $VCRD_ID_RANGE ); do

	local VCRD_NAME=$( virsh -c qemu:///system list --all 2>/dev/null  | grep ${VCRD_ID} | awk '{print $2}' )

	if [ $VCRD_NAME ]; then

	    local VCRD_PATH=$( virsh -c qemu:///system dumpxml $VCRD_NAME | \
		xmlstarlet sel -T -t -m "/domain/devices/disk/source" -v attribute::file -n |
		grep -e "^${VCT_SYS_DIR}" || \
		    err $FUNCNAME "Failed resolving disk path for $VCRD_NAME" )

	    if virsh -c qemu:///system dominfo $VCRD_NAME  2>/dev/null | grep -e "^State:" | grep "running" >/dev/null ; then
		virsh -c qemu:///system destroy $VCRD_NAME ||\
	    err $FUNCNAME "Failed stopping domain $VCRD_NAME"
	    fi

	    if virsh -c qemu:///system dominfo $VCRD_NAME  2>/dev/null | grep -e "^State:" | grep "off" >/dev/null ; then
		virsh -c qemu:///system undefine $VCRD_NAME ||\
	    err $FUNCNAME "Failed undefining domain $VCRD_NAME"
	    fi
	    
	    [ -f $VCRD_PATH ] && rm -f $VCRD_PATH

	else
	    err $FUNCNAME "No system with rd-id=$VCRD_ID $VCRD_NAME found"

	fi
    done
}


vct_node_create() {

    vct_system_init_check quick

    local VCRD_ID_RANGE=$1
    local VCRD_ID=

    for VCRD_ID in $( vcrd_ids_get $VCRD_ID_RANGE ); do

	local VCRD_NAME="${VCT_RD_NAME_PREFIX}${VCRD_ID}"
	local VCRD_PATH="${VCT_SYS_DIR}/${VCT_TEMPLATE_NAME}-rd${VCRD_ID}.${VCT_TEMPLATE_TYPE}"

	virsh -c qemu:///system dominfo $VCRD_NAME 2>/dev/null && \
	    err $FUNCNAME "Domain name=$VCRD_NAME already exists"

	[ -f $VCRD_PATH ] && \
	    echo "Removing existing rootfs=$VCRD_PATH" >&2 && rm -f $VCRD_PATH


	if ! install_url  $VCT_TEMPLATE_URL $VCT_TEMPLATE_SITE $VCT_TEMPLATE_NAME.$VCT_TEMPLATE_TYPE $VCT_TEMPLATE_COMP $VCT_DL_DIR $VCRD_PATH install ; then
	    err $FUNCNAME "Installing $VCT_TEMPLATE_URL to $VCRD_PATH failed"
	fi    




	local VCRD_NETW=""
	local BRIDGE=
	for BRIDGE in $VCT_BRIDGE_PREFIXES; do

	    local BR_NAME=

	    echo $BRIDGE | grep -e "^VCT_BR[0-f][0-f]$" >/dev/null || \
		err $FUNCNAME "Invalid VCT_BRIDGE_PREFIXES naming convention: $BRIDGE"

	    if BR_NAME=$( variable_check ${BRIDGE}_NAME soft ); then

		local BR_MODEL=$( variable_check ${BRIDGE}_MODEL soft 2>/dev/null ) 
		local BR_MAC48=$( variable_check ${BRIDGE}_MAC48 soft 2>/dev/null || \
		    echo "${VCT_INTERFACE_MAC24}:$( echo ${BRIDGE:6:7} ):${VCRD_ID:0:2}:${VCRD_ID:2:3}" ) 
		local BR_VNET="vct-rd${VCRD_ID}-br$( echo ${BRIDGE:6:7} )"
	    fi

	    VCRD_NETW="${VCRD_NETW}  --network bridge=${BR_NAME}"
	    [ "$BR_MODEL" ] && VCRD_NETW="${VCRD_NETW},model=${BR_MODEL}"
	    [ "$BR_MAC48" != "RANDOM" ] && VCRD_NETW="${VCRD_NETW},mac=${BR_MAC48}"
        # ,target=${BR_VNET}"
	    
	# this requires virsh --version 0.9.9
	# local VCRD_IFACE="bridge ${BR_NAME} --persistent --target ${BR_VNET}"
	# [ "$BR_MODEL" ] && VCRD_IFACE="$VCRD_IFACE --model ${BR_MODEL} "
	# [ "$BR_MAC48" != "RANDOM" ] && VCRD_IFACE="$VCRD_IFACE --mac ${BR_MAC48} "

	# echo "attach-interface $VCRD_IFACE"

	# if ! virsh -c qemu:///system attach-interface $VCRD_NAME $VCRD_IFACE ; then
	#     vct_node_remove $VCRD_ID
	#     err $FUNCNAME "Failed attaching-interface $VCRD_IFACE to $VCRD_NAME"
	# fi
	done


	local TEMPLATE_TYPE=$( [ "$VCT_TEMPLATE_TYPE" = "img" ] && echo "raw" || echo "$VCT_TEMPLATE_TYPE" )
	local VIRT_CMD="\
    virt-install --connect qemu:///system -n $VCRD_NAME -r $VCT_RD_MEM --os-type linux \
	--import --disk path=$VCRD_PATH,format=$TEMPLATE_TYPE \
	--vcpus=1 --noautoconsole --virt-type kvm --hvm --accelerate --noacpi --noapic  --noreboot \
        $VCRD_NETW"

#        --nonetworks"

# --graphics none  --cpu 486

	echo $VIRT_CMD

	if ! $VIRT_CMD; then
	    vct_node_remove $VCRD_ID
	    err $FUNCNAME "Failed creating domain name=$VCRD_NAME"
	fi
    done
}


vct_node_start() {

    local VCRD_ID_RANGE=$1
    local VCRD_ID=

    for VCRD_ID in $( vcrd_ids_get $VCRD_ID_RANGE ); do

	local VCRD_NAME="${VCT_RD_NAME_PREFIX}${VCRD_ID}"
	local VCRD_PATH="${VCT_SYS_DIR}/${VCT_TEMPLATE_NAME}-rd${VCRD_ID}.${VCT_TEMPLATE_TYPE}"
	local VCRD_MNTP=$VCT_MNT_DIR/$VCRD_NAME

	    mount | grep "$VCRD_MNTP" >/dev/null && \
		err $FUNCNAME "node-id=$VCRD_ID already mounted offline, use vct_node_unmount"


	( [ -f $VCRD_PATH ] &&\
	virsh -c qemu:///system dominfo $VCRD_NAME | grep -e "^State:" | grep "off" >/dev/null &&\
	virsh -c qemu:///system start $VCRD_NAME ) ||\
	    err $FUNCNAME "Failed starting domain $VCRD_NAME"
    done
}


vct_node_console() {

    local VCRD_ID=$1; check_rd_id $VCRD_ID quiet
    local VCRD_NAME="${VCT_RD_NAME_PREFIX}${VCRD_ID}"

    if virsh -c qemu:///system dominfo $VCRD_NAME | grep -e "^State:" | grep "running" >/dev/null ; then
	virsh -c qemu:///system console $VCRD_NAME && return 0


	local CONSOLE_PTS=$( virsh -c qemu:///system dumpxml $VCRD_NAME | \
	    xmlstarlet sel -T -t -m "/domain/devices/console/source" -v attribute::path -n |
	    grep -e "^/dev/pts/" || \
		err $FUNCNAME "Failed resolving pts path for $VCRD_NAME" )

	if ! ls -l $CONSOLE_PTS | grep -e "rw....rw." ; then 
	    vct_sudo chmod o+rw $CONSOLE_PTS 
	    virsh -c qemu:///system console $VCRD_NAME && return 0
	fi

	err $FUNCNAME "Failed connecting console to domain $VCRD_NAME"
    fi
}


vct_node_ssh4_prepare() {

    local VCRD_ID=$1; check_rd_id $VCRD_ID quiet
    local VCRD_NAME="${VCT_RD_NAME_PREFIX}${VCRD_ID}"


    variable_check VCT_RD_LOCAL_BRIDGE quiet
    variable_check VCT_RD_RESCUE_V4_IP quiet
    variable_check VCT_KNOWN_HOSTS_FILE quiet


    local LOCAL_MAC=$( virsh -c qemu:///system dumpxml $VCRD_NAME | \
	xmlstarlet sel -T -t -m "/domain/devices/interface" \
	-v child::source/attribute::* -o " " -v child::mac/attribute::address -n | \
	grep -e "^$VCT_RD_LOCAL_BRIDGE " | awk '{print $2 }' || \
	err $FUNCNAME "Failed resolving MAC address for $VCRD_NAME $VCT_RD_LOCAL_BRIDGE" )

    # echo "connecting to $VCT_RD_RESCUE_V4_IP via $LOCAL_MAC"

    if ! ip neigh | grep -e "^$VCT_RD_RESCUE_V4_IP" | grep -e "lladdr $LOCAL_MAC" > /dev/null; then
	vct_sudo ip neigh replace $VCT_RD_RESCUE_V4_IP lladdr $LOCAL_MAC nud permanent dev $VCT_BR00_NAME
    fi

#    if ! arp -n | grep -e "^$VCT_RD_RESCUE_V4_IP" | grep -e "$LOCAL_MAC" > /dev/null; then
#	vct_sudo arp -s $VCT_RD_RESCUE_V4_IP  $LOCAL_MAC
#    fi

    if ! ping -c 1 -w 2 -W 2 $VCT_RD_RESCUE_V4_IP > /dev/null; then
	echo "Waiting for $VCRD_ID to listen on $VCT_RD_RESCUE_V4_IP... (after boot this may take upto 40 secs)"
	time ping -c 1 -w 60 -W 1 $VCT_RD_RESCUE_V4_IP > /dev/null | grep -e "^user"
    fi
}

vct_node_ssh4_prepared() {

    local VCRD_ID=$1; check_rd_id $VCRD_ID quiet
    local COMMAND=

    echo > $VCT_KNOWN_HOSTS_FILE

    if ! [ -z "${2:-}" ]; then
	COMMAND=". /etc/profile > /dev/null; $2"
    fi
    
    ssh -o StrictHostKeyChecking=no -o HashKnownHosts=no -o UserKnownHostsFile=$VCT_KNOWN_HOSTS_FILE -o ConnectTimeout=1 \
	root@$VCT_RD_RESCUE_V4_IP "$COMMAND"
}

vct_node_ssh4() {

    local VCRD_ID=$1; check_rd_id $VCRD_ID quiet
    local COMMAND=

    vct_node_ssh4_prepare $VCRD_ID
    echo > $VCT_KNOWN_HOSTS_FILE

    if ! [ -z "${2:-}" ]; then
	COMMAND=". /etc/profile > /dev/null; $2"
    fi
    
    ssh -o StrictHostKeyChecking=no -o HashKnownHosts=no -o UserKnownHostsFile=$VCT_KNOWN_HOSTS_FILE -o ConnectTimeout=1 \
	root@$VCT_RD_RESCUE_V4_IP "$COMMAND"
}

vct_node_ssh6() {

    local VCRD_ID=$1; check_rd_id $VCRD_ID quiet
    local COMMAND=

    echo > $VCT_KNOWN_HOSTS_FILE

    if [ "${2:-}" ]; then
	COMMAND=". /etc/profile > /dev/null; $2"
    fi
    
    ssh -o StrictHostKeyChecking=no -o HashKnownHosts=no -o UserKnownHostsFile=$VCT_KNOWN_HOSTS_FILE -o ConnectTimeout=1 \
	root@${VCT_RD_DEBUG_V6_PREFIX48}:${VCRD_ID}::${VCT_RD_DEBUG_V6_SUFFIX64} "$COMMAND" # 2> >(grep -v "Permanently added") | cat

}

vct_node_scp4() {

    local VCRD_ID=$1; check_rd_id $VCRD_ID quiet
    local SRC="$2"
    local DST=${3:-}

    if [ -z ${SRC} ] || [ -z ${DST} ]; then
	err $FUNCNAME "requires 3 arguments <RD_ID> <local-src-path> <remote-dst-path> "
    fi

    
    vct_node_ssh4_prepare $VCRD_ID
    echo > $VCT_KNOWN_HOSTS_FILE

    scp -o StrictHostKeyChecking=no -o HashKnownHosts=no -o UserKnownHostsFile=$VCT_KNOWN_HOSTS_FILE -o ConnectTimeout=1 \
	$SRC root@$VCT_RD_RESCUE_V4_IP:$DST 2>&1 | grep -v "Warning: Permanently added"
}

vct_node_scp6() {

    local VCRD_ID=$1; check_rd_id $VCRD_ID quiet
    local SRC="$2"
    local DST=${3:-}

    if [ -z ${SRC} ] || [ -z ${DST} ]; then
	err $FUNCNAME "requires 3 arguments <RD_ID> <local-src-path> <remote-dst-path> "
    fi

    echo > $VCT_KNOWN_HOSTS_FILE

    scp -o StrictHostKeyChecking=no -o HashKnownHosts=no -o UserKnownHostsFile=$VCT_KNOWN_HOSTS_FILE -o ConnectTimeout=1 \
	$SRC root@\[${VCT_RD_DEBUG_V6_PREFIX48}:${VCRD_ID}::${VCT_RD_DEBUG_V6_SUFFIX64}\]:$DST 2>&1 | grep -v "Warning: Permanently added"
}



vct_node_mount() {

    local VCRD_ID_RANGE=$1
    local VCRD_ID=

    for VCRD_ID in $( vcrd_ids_get $VCRD_ID_RANGE ); do

	local VCRD_NAME="${VCT_RD_NAME_PREFIX}${VCRD_ID}"    
	local VCRD_PATH="${VCT_SYS_DIR}/${VCT_TEMPLATE_NAME}-rd${VCRD_ID}.${VCT_TEMPLATE_TYPE}"
	local VCRD_MNTP=$VCT_MNT_DIR/$VCRD_NAME

	if [ -f $VCRD_PATH ] && \
	    ! mount | grep "$VCRD_MNTP" >/dev/null && \
	    vct_node_info | grep $VCRD_NAME  | grep "shut off" >/dev/null; then

	    local IMG_UNIT_SIZE=$( fdisk -lu $VCRD_PATH 2>/dev/null | \
		grep "^Units = " | awk -F'=' '{print $(NF) }' | awk '{print $1 }' )

	    local IMG_ROOTFS_START=$( fdisk -lu $VCRD_PATH 2>/dev/null | \
		grep "${VCRD_PATH}2" | awk '{print $(NF-4) }' )

	    [ $IMG_UNIT_SIZE ] && [ $IMG_ROOTFS_START ] || \
		err $FUNCNAME "Failed resolving rootfs usize=$IMG_UNIT_SIZE start=$IMG_ROOTFS_START"

	    mkdir -p $VCRD_MNTP
	    
	    vct_sudo mount -o loop,offset=$(( $IMG_UNIT_SIZE * $IMG_ROOTFS_START )) $VCRD_PATH $VCRD_MNTP || \
		err $FUNCNAME "Failed mounting $VCRD_PATH"

	else
	    err $FUNCNAME "Failed offline mounting node-id=$VCRD_ID"
	fi
    done
}


vct_node_unmount() {

    local VCRD_ID_RANGE=$1
    local VCRD_ID=

    for VCRD_ID in $( vcrd_ids_get $VCRD_ID_RANGE ); do

	local VCRD_NAME="${VCT_RD_NAME_PREFIX}${VCRD_ID}"    
	local VCRD_PATH="${VCT_SYS_DIR}/${VCT_TEMPLATE_NAME}-rd${VCRD_ID}.${VCT_TEMPLATE_TYPE}"
	local VCRD_MNTP=$VCT_MNT_DIR/$VCRD_NAME

	if  mount | grep "$VCRD_MNTP" >/dev/null ; then

	    vct_sudo umount $VCRD_MNTP || \
		err $FUNCNAME "Failed unmounting $VCRD_PATH"

	    rmdir $VCRD_MNTP
	fi
    done
}


vct_node_customize() {

    local VCRD_ID_RANGE=$1
    local VCRD_ID=

    for VCRD_ID in $( vcrd_ids_get $VCRD_ID_RANGE ); do

	local VCRD_ID_LSB8BIT_DEC=$(( 16#${VCRD_ID:2:2} ))
	local VCRD_NAME="${VCT_RD_NAME_PREFIX}${VCRD_ID}"    
	local VCRD_MAC=$( virsh -c qemu:///system dumpxml $VCRD_NAME | \
	    xmlstarlet sel -T -t -m "/domain/devices/interface" \
	    -v child::source/attribute::* -o " " -v child::mac/attribute::address -n | \
	    grep -e "^$VCT_RD_LOCAL_BRIDGE " | awk '{print $2 }' || \
	    err $FUNCNAME "Failed resolving MAC address for $VCRD_NAME $VCT_RD_LOCAL_BRIDGE" )

	local RPC_TYPE="basics"
	local RPC_FILE="${VCRD_ID}-$( date +%Y%m%d-%H%M%S )-${RPC_TYPE}.sh"
	local RPC_PATH="${VCT_RPC_DIR}/${RPC_FILE}"

	virsh -c qemu:///system dominfo $VCRD_NAME | grep -e "^State:" | grep "running" >/dev/null || \
	    err $FUNCNAME "$VCRD_NAME not running"

	cat <<EOF > $RPC_PATH
#!/bin/bash

echo "Configuring CONFINE $RPC_TYPE "

echo "$( cat $VCT_RD_AUTHORIZED_KEY )" >> /etc/dropbear/authorized_keys 

# customizing network:
echo "Configuring network... "

uci revert network

uci set network.internal=interface
uci set network.internal.type=bridge
uci set network.internal.proto=static
uci set network.internal.ipaddr=$VCT_RD_INTERNAL_V4_IP
uci set network.internal.netmask=$( ip4_net_to_mask $VCT_RD_INTERNAL_V4_IP/$VCT_RD_INTERNAL_V4_PL )
uci set network.internal.ip6addr=$VCT_RD_INTERNAL_V6_IP/$VCT_RD_INTERNAL_V6_PL

uci set network.local=interface
uci set network.local.type=bridge
uci set network.local.ifname=eth0
uci set network.local.macaddr=$VCRD_MAC
uci set network.local.proto=none
uci set network.local.ip6addr=$VCT_RD_LOCAL_V6_PREFIX48:$VCRD_ID::$VCT_RD_LOCAL_V6_SUFFIX64/$VCT_RD_LOCAL_V6_PL

uci set network.recovery=alias
uci set network.recovery.interface=local
uci set network.recovery.proto=static
uci set network.recovery.ipaddr=$VCT_RD_RESCUE_V4_IP
uci set network.recovery.netmask=$( ip4_net_to_mask $VCT_RD_RESCUE_V4_IP/$VCT_RD_RESCUE_V4_PL )
uci set network.recovery.ip6addr=$VCT_RD_RESCUE_V6_IP/$VCT_RD_RESCUE_V6_PL

uci set network.debug=alias
uci set network.debug.interface=local
uci set network.debug.proto=static
uci set network.debug.ip6addr=$VCT_RD_DEBUG_V6_PREFIX48:$VCRD_ID::$VCT_RD_DEBUG_V6_SUFFIX64/$VCT_RD_DEBUG_V6_PL

EOF

	
	if [ "${VCT_RD_LOCAL_V4_PROTO}" = "static" ] && [ ${VCT_RD_LOCAL_V4_PREFIX16:-} ]; then

	    cat <<EOF >> $RPC_PATH

uci set network.local.proto=static
uci set network.local.ipaddr=$VCT_RD_LOCAL_V4_PREFIX16.0.$VCRD_ID_LSB8BIT_DEC
uci set network.local.netmask=$( ip4_net_to_mask $VCT_RD_LOCAL_V4_PREFIX16.0.0/$VCT_RD_LOCAL_V4_PL )
uci set network.local.dns=$VCT_RD_LOCAL_V4_DNS

uci set network.dflt_route=route
uci set network.dflt_route.interface=local
uci set network.dflt_route.target=0.0.0.0
uci set network.dflt_route.netmask=0.0.0.0
uci set network.dflt_route.gateway=$VCT_BR00_V4_LOCAL_IP

EOF

	elif [ "${VCT_RD_LOCAL_V4_PROTO}" = "dhcp" ] ; then

	    cat <<EOF >> $RPC_PATH
uci set network.local.proto=dhcp
uci -q delete network.local.ipaddr
uci -q delete network.local.netmask
uci -q delete network.local.dns
uci -q delete network.dflt_route
EOF
	fi


	cat <<EOF >> $RPC_PATH
uci commit network
echo Restarting network...
/etc/init.d/network restart

EOF


	cat <<EOF >> $RPC_PATH

uci revert system
uci set system.@system[0].hostname="rd${VCRD_ID}"
uci commit system
echo "rd${VCRD_ID}" > /proc/sys/kernel/hostname

uci revert lxc
uci set lxc.general.lxc_host_id=${VCRD_ID}
uci commit lxc

# remove useless busybox links:
[ -h /bin/ping ] && [ -x /usr/bin/ping ] && rm /bin/ping
[ -h /bin/rm ] && [ -x /usr/bin/rm ] && rm /bin/rm

EOF





	cat <<EOF >> $RPC_PATH

echo "" > /etc/config/confine-testbed
uci revert confine-testbed
uci set confine-testbed.testbed=testbed
uci set confine-testbed.testbed.mgmt_ipv6_prefix48=$VCT_TESTBED_MGMT_IPV6_PREFIX48
uci set confine-testbed.testbed.priv_dflt_ipv4_prefix24=$VCT_TESTBED_PRIV_IPV4_PREFIX24
uci set confine-testbed.testbed.mac_dflt_prefix16=$VCT_TESTBED_MAC_PREFIX16
uci commit confine-testbed

echo "" > /etc/config/confine-server
uci revert confine-server
uci set confine-server.server=server
uci set confine-server.server.cn_url=""
uci set confine-server.server.mgmt_pubkey="$( cat $VCT_SERVER_MGMT_PUBKEY )"
uci set confine-server.server.tinc_ip=$VCT_SERVER_TINC_IP
uci set confine-server.server.tinc_port=$VCT_SERVER_TINC_PORT
uci commit confine-server

echo "" > /etc/config/confine-node
uci revert confine-node
uci set confine-node.node=node
uci set confine-node.node.id=$VCRD_ID
uci set confine-node.node.rd_pubkey="\$( dropbearkey -y -f /etc/dropbear/dropbear_rsa_host_key  | grep ssh-rsa )"
uci set confine-node.node.cn_url=""
uci set confine-node.node.mac_prefix16=$VCT_TESTBED_MAC_PREFIX16

uci set confine-node.node.priv_ipv4_prefix24=$VCT_TESTBED_PRIV_IPV4_PREFIX24
uci set confine-node.node.rd_public_ipv4_proto=$VCT_NODE_PUBLIC_IPV4_PROTO

[ "$VCT_NODE_PUBLIC_IPV4_PROTO" = "static" ] && \
uci set confine-node.node.rd_public_ipv4_addrs="$( echo $( \
  for i in $( seq 1 $VCT_NODE_PUBLIC_IPV4_AVAIL ); do \
     echo $VCT_NODE_PUBLIC_IPV4_PREFIX16.$(( 16#${VCRD_ID:2:2} )).$i/$VCT_RD_LOCAL_V4_PL; \
  done ) )"

uci set confine-node.node.rd_if_iso_parents="$VCT_NODE_ISOLATED_PARENTS"

uci set confine-node.node.rd_public_ipv4_avail=$VCT_NODE_PUBLIC_IPV4_AVAIL
uci set confine-node.node.state=installing
uci commit confine-node

$( for dev in $VCT_NODE_ISOLATED_PARENTS; do echo "
uci set network.$dev=interface       ;\
uci set network.$dev.ifname=$dev     ;\
uci set network.$dev.proto=static    ;\
uci set network.$dev.ipaddr=0.0.0.0  ;\
" ; done )
uci commit network


lxc.lib lxc_stop       fd_dummy
lxc.lib lxc_purge      fd_dummy
lxc.lib lxc_create_uci fd_dummy confine-defaults.openwrt
lxc.lib uci_set lxc.fd_dummy.auto_boot=1
lxc.lib uci_set lxc.fd_dummy.auto_create=1

echo "Waiting 5 secs for network default route configuration to start and complete..."
sleep 5
while ! /usr/bin/ping -c 1 -w 100 -W 1 confine-project.eu ; do
    sleep 1
done

lxc.lib lxc_start      fd_dummy
/etc/init.d/network reload

EOF

	vct_node_ssh4_prepare $VCRD_ID
	cat $RPC_PATH | vct_node_ssh4_prepared $VCRD_ID "confine.lib confine_node_customize"

    done
}


vct_slice_attributes() {

    local CMD=$1
    local SLICE_ARG=$2
    local NODE_ARG="${3:-}"
    local SLICES=
    local SLICE_ID=

    uci -c $VCT_UCI_DIR changes | grep -e "^$VCT_SLICE_DB" && \
	err $FUNCTION "dirty uci $VCT_SLICE_DB"

    [ "$NODE_ARG" ] && check_rd_id "$NODE_ARG" quiet

    if [ "$SLICE_ARG" = "all" ] ; then
	SLICES="$( uci_get_sections $VCT_SLICE_DB slice )"
    else
	SLICES=$( check_slice_id $SLICE_ARG )
    fi

    for SLICE_ID in $SLICES; do

	local SLIVER_ID=
	local SLIVERS="$( [ $NODE_ARG ] && \
	    echo ${SLICE_ID}_${NODE_ARG} || \
	    for SLIVER_ID in $( uci_get_sections $VCT_SLICE_DB sliver ); do echo $SLIVER_ID | grep -e "${SLICE_ID}_"; done )"

	if [ "$CMD" = "show" ] ; then

	    uci_show $VCT_SLICE_DB.$SLICE_ID soft,quiet | uci_dot_to_file $VCT_SLICE_DB
	    echo
	    for SLIVER_ID in $SLIVERS ; do
		uci_show $VCT_SLICE_DB.$SLIVER_ID | uci_dot_to_file $VCT_SLICE_DB
		echo
	    done

	elif [ "$CMD" = "flush" ] ; then

	    for SLIVER_ID in $SLIVERS ; do
		uci_del $VCT_SLICE_DB.$SLIVER_ID
	    done

	    vct_slice_attributes update $SLICE_ID

	elif [ "${CMD:0:6}" = "state=" ] ; then

	    local NEW_STATE=$( echo $CMD | awk -F'state=' '{print $2}' )

	    check_slice_or_sliver_state $NEW_STATE quiet
	    
	    for SLIVER_ID in $SLIVERS ; do
		uci_set $VCT_SLICE_DB.$SLIVER_ID.state=$NEW_STATE
	    done

	    vct_slice_attributes update $SLICE_ID

	elif [ "$CMD" = "update" ] ; then

	    local VALID_STATE=
	    local NEW_STATE=

	    for VALID_STATE in $CONFINE_SLICE_AND_SLIVER_STATES ; do

		for SLIVER_ID in $SLIVERS ; do
		    if [ $VALID_STATE = $( uci_get $VCT_SLICE_DB.$SLIVER_ID.state ) ] ; then
			NEW_STATE=$VALID_STATE
			break
		    fi
		done
		[ $NEW_STATE ] && break
	    done

	    if [ $NEW_STATE ] ; then

		uci_set $VCT_SLICE_DB.$SLICE_ID.state=$( check_slice_or_sliver_state $NEW_STATE )
		
	    else

		uci_show $VCT_SLICE_DB soft,quiet | grep -e "^${VCT_SLICE_DB}.${SLICE_ID}_" && \
		    err $FUNCNAME "Unrecoverable $VCT_SLICE_DB"

		uci_del $VCT_SLICE_DB.$SLICE_ID soft,quiet

	    fi
	    
	else
	    err $FUNCNAME "Illegal command"
	fi

    done
}



vct_sliver_allocate() {

    local SLICE_ID=$1; check_slice_id $SLICE_ID quiet
    local VCRD_ID_RANGE=$2
    local OS_TYPE=${3:-openwrt}
    local VCRD_ID=

    [ "$OS_TYPE" = "openwrt" ] || [ "$OS_TYPE" = "debian" ] || \
	err $FUNCNAME "OS_TYPE=$OS_TYPE NOT supported"

    vct_slice_attributes update $SLICE_ID

    if ! uci_test $VCT_SLICE_DB.$SLICE_ID.state soft,quiet ; then

	touch $VCT_UCI_DIR/$VCT_SLICE_DB
	uci_set $VCT_SLICE_DB.$SLICE_ID=slice 
	uci_set $VCT_SLICE_DB.$SLICE_ID.state=allocating

    elif [ "$( uci_get $VCT_SLICE_DB.$SLICE_ID.state )" != "allocating" ] ; then
	
	err $FUNCNAME "SLICE_ID=$SLICE_ID not in allocating state"

    fi

    for VCRD_ID in $( vcrd_ids_get $VCRD_ID_RANGE ); do


	local VCRD_NAME="${VCT_RD_NAME_PREFIX}${VCRD_ID}"    
	local RPC_REQUEST="${VCRD_ID}-$( date +%Y%m%d_%H%M%S )-${SLICE_ID}-allocate-request"
	local RPC_REPLY="${VCRD_ID}-$( date +%Y%m%d_%H%M%S )-${SLICE_ID}-allocate-reply"


	virsh -c qemu:///system dominfo $VCRD_NAME | grep -e "^State:" | grep "running" >/dev/null || \
	    err $FUNCNAME "$VCRD_NAME not running"

	if [ "$OS_TYPE" = "debian" ]; then
            cat <<EOF > ${VCT_RPC_DIR}/${RPC_REQUEST}
config sliver $SLICE_ID
    option user_pubkey     "$( cat $VCT_SERVER_MGMT_PUBKEY )"
    option fs_template_url "http://distro.confine-project.eu/misc/debian32.tgz"
    option exp_data_url    'http://distro.confine-project.eu/misc/exp-data-hello-world-debian.tgz'
    option vlan_nr         "f${SLICE_ID:10:2}"    # mandatory for if-types isolated
    option if00_type       internal 
    option if01_type       public   # optional
    option if01_ipv4_proto $VCT_SLIVER_PUBLIC_IPV4_PROTO   # mandatory for if-type public
    option if02_type       isolated # optional
    option if02_parent     eth1     # mandatory for if-types isolated
EOF
	else
	    cat <<EOF > ${VCT_RPC_DIR}/${RPC_REQUEST}
config sliver $SLICE_ID
    option user_pubkey     "$( cat $VCT_SERVER_MGMT_PUBKEY )"
    option fs_template_url "http://downloads.openwrt.org/backfire/10.03.1-rc6/x86_generic/openwrt-x86-generic-rootfs.tar.gz"
    option exp_data_url    'http://distro.confine-project.eu/misc/exp-data-hello-world-openwrt.tgz'
    option vlan_nr         "f${SLICE_ID:10:2}"    # mandatory for if-types isolated
    option if00_type       internal 
    option if01_type       public   # optional
    option if01_ipv4_proto $VCT_SLIVER_PUBLIC_IPV4_PROTO   # mandatory for if-type public
    option if02_type       isolated # optional
    option if02_parent     eth1     # mandatory for if-types isolated
EOF
	fi

	echo "# >>>> Input stream begin >>>>" >&1
	cat $VCT_RPC_DIR/$RPC_REQUEST         >&1
	echo "# <<<< Input stream end <<<<<<" >&1

	cat $VCT_RPC_DIR/$RPC_REQUEST | vct_node_ssh6 $VCRD_ID "confine.lib confine_sliver_allocate $SLICE_ID" > $VCT_RPC_DIR/$RPC_REPLY

	cat $VCT_RPC_DIR/$RPC_REPLY           >&1


	if [ "$( uci_get $RPC_REPLY.$SLICE_ID soft,quiet,path=$VCT_RPC_DIR )" = "sliver" ] ; then

	    uci_show $RPC_REPLY.$SLICE_ID path=$VCT_RPC_DIR | \
		sed s/$RPC_REPLY\.${SLICE_ID}/${VCT_SLICE_DB}.${SLICE_ID}_${VCRD_ID}/ | \
		uci_merge $VCT_SLICE_DB 

	# cat $VCT_UCI_DIR/$VCT_SLICE_DB >&2

	fi
    done
}


vct_sliver_deploy() {

    local SLICE_ID=$1; check_slice_id $SLICE_ID quiet
    local VCRD_ID_RANGE=$2
    local VCRD_ID=


    vct_slice_attributes update $SLICE_ID

    local SLICE_STATE=$( uci_get $VCT_SLICE_DB.$SLICE_ID.state soft,quiet )

    if [ "$SLICE_STATE" = "allocated" ] ; then

	uci_set $VCT_SLICE_DB.$SLICE_ID.state=deploying

    elif [ "$SLICE_STATE" != "deploying" ] ; then
	    
	err $FUNCNAME "SLICE_ID=$SLICE_ID not in allocating or deploying state"

    fi


    for VCRD_ID in $( vcrd_ids_get $VCRD_ID_RANGE ); do

	local VCRD_NAME="${VCT_RD_NAME_PREFIX}${VCRD_ID}"    
	local RPC_REQUEST="${VCRD_ID}-$( date +%Y%m%d_%H%M%S )-${SLICE_ID}-deploy-request"
	local RPC_REPLY="${VCRD_ID}-$( date +%Y%m%d_%H%M%S )-${SLICE_ID}-deploy-reply"

	virsh -c qemu:///system dominfo $VCRD_NAME | grep -e "^State:" | grep "running" >/dev/null || \
	    err $FUNCNAME "$VCRD_NAME not running"
	
	uci_show $VCT_SLICE_DB | grep $VCT_SLICE_DB.${SLICE_ID}_ | uci_dot_to_file $VCT_SLICE_DB > ${VCT_RPC_DIR}/${RPC_REQUEST}

	echo "# >>>> Input stream begin >>>>" >&1
	cat $VCT_RPC_DIR/$RPC_REQUEST         >&1
	echo "# <<<< Input stream end <<<<<<" >&1
	cat ${VCT_RPC_DIR}/${RPC_REQUEST} | vct_node_ssh6 $VCRD_ID "confine.lib confine_sliver_deploy $SLICE_ID" > ${VCT_RPC_DIR}/${RPC_REPLY}
	cat ${VCT_RPC_DIR}/${RPC_REPLY}       >&1

    done
}







vct_sliver_start() {

    local SLICE_ID=$1; check_slice_id $SLICE_ID quiet
    local VCRD_ID_RANGE=$2

    vct_slice_attributes $SLICE_ID update

    local SLICE_STATE=$( uci_get $VCT_SLICE_DB.$SLICE_ID.state soft,quiet )

    if [ "$SLICE_STATE" = "deployed" ] ; then
	uci_set $VCT_SLICE_DB.$SLICE_ID.state=starting
    elif [ "$SLICE_STATE" != "starting" ] ; then
	err $FUNCNAME "SLICE_ID=$SLICE_ID not in deployed or starting state"
    fi
    

    local VCRD_ID=

    for VCRD_ID in $( vcrd_ids_get $VCRD_ID_RANGE ); do

	local VCRD_NAME="${VCT_RD_NAME_PREFIX}${VCRD_ID}"    
	local RPC_REPLY="${VCRD_ID}-$( date +%Y%m%d_%H%M%S )-${SLICE_ID}-start-reply"

	virsh -c qemu:///system dominfo $VCRD_NAME | grep -e "^State:" | grep "running" >/dev/null || \
	    err $FUNCNAME "$VCRD_NAME not running"
	
	vct_node_ssh6 $VCRD_ID "confine.lib confine_sliver_start $SLICE_ID" > ${VCT_RPC_DIR}/${RPC_REPLY}
	cat ${VCT_RPC_DIR}/${RPC_REPLY}       >&1

    done
}








vct_help() {

    echo "usage..."
    cat <<EOF

    vct_help

    vct_system_install [update]    : install vct system requirements
    vct_system_init                : initialize vct system on host
    vct_system_cleanup             : revert vct_system_init

    vct_node_info   [<node-id>]    : summary of existing domain(s)
    vct_node_create  <node-id>     : create domain with given node-id
    vct_node_start   <node-id>     : start domain with given node-id
    vct_node_stop    <node-id>     : stop domain with given node-id
    vct_node_remove  <node-id>     : remove domain with given node-id
    vct_node_console <node-id>     : open console to running domain

    vct_node_ssh4    <node-id> ["commands"]  : connect (& execute commands) via IPv4 recovery net
    vct_node_ssh6    <node-id> ["commands"]  : connect (& execute commands) via IPv6 debug net
    vct_node_scp4    <node-id> <local src-path> <remote dst-path>  : copy data via IPv4 recovery net
    vct_node_scp6    <node-id> <local src-path> <remote dst-path>  : copy data via IPv6 debug net

    vct_node_customize   <node-id>  : setup node-id specific attributes (confine configs, addresses...)

    vct_sliver_allocate  <sl-id> <node-id> [os-type:openwrt,debian] 
    vct_sliver_deploy    <sl-id> <node-id> 

    vct_slice_attributes  <show|flush|update|state=<alloc|...>> <sl-id|all> [node-id]

-------------------------------------------------------------------------------------------

    Future requests (commands not yet implemented):
    -----------------------------------------------

    vct_sliver_start     <sl-id> <node-id> 
    vct_sliver_stop      <sl-id> <node-id> 
    vct_sliver_remove    <sl-id> <node-id> 
    


    vct_link_get [node-id]             : show configured links
    vct_link_del [<node-id-A[:direct-if-A]>] [<node-id-B[:direct-if-B>]] : del configured link(s)
    vct_link_add  <node-id-A:direct-if-A>     <node-id-B:direct-if-B> [packet-loss] 
                                     virtually link node-id a via direct if a with rd b
                                     example $ ./vct.sh link-add 0003:1 0005:1 10
                                     to setup a link between given RDs with 10% packet loss


EOF

}


vct_system_config_check

# check if correct user:
if [ $(whoami) != $VCT_USER ] || [ $(whoami) = root ] ;then
    err $0 "command must be executed as non-root user=$VCT_USER"  || return 1
fi



CMD=$( echo $0 | awk -F'/' '{print $(NF)}' )

if [ "$CMD" = "vct.sh" ]; then

    if [ "${1:-}" ]; then
	"$@"
    else
	help
    fi

else

    case "$CMD" in
	vct_help) $CMD;;

	vct_system_install_check) $CMD "$@";;
	vct_system_install)       $CMD "$@";;
	vct_system_init_check)    $CMD "$@";;
	vct_system_init)          $CMD "$@";;
	vct_system_cleanup)       $CMD "$@";;

	vct_node_info)            $CMD "$@";;
	vct_node_create)          $CMD "$@";;
	vct_node_start)           $CMD "$@";;
	vct_node_stop)            $CMD "$@";;
	vct_node_remove)          $CMD "$@";;
	vct_node_console)         $CMD "$@";;
	vct_node_ssh4)            $CMD "$@";;
	vct_node_ssh6)            $CMD "$@";;
	vct_node_scp4)            $CMD "$@";;
	vct_node_scp6)            $CMD "$@";;

        vct_node_customize)       $CMD "$@";;
        vct_node_mount)           $CMD "$@";;
        vct_node_unmount)         $CMD "$@";;

        vct_sliver_allocate)      $CMD "$@";;
        vct_sliver_deploy)        $CMD "$@";;
        vct_sliver_start)         $CMD "$@";;
        vct_sliver_stop)          $CMD "$@";;
        vct_sliver_remove)        $CMD "$@";;

	vct_slice_attributes)     $CMD "$@";;

	*) vct_help;;
    esac

fi

#echo "successfully finished $0 $*" >&2
