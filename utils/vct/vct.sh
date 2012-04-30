#!/bin/bash

set -u # set -o nounset
#set -o errexit

if [ -f ./vct.conf ]; then
    . ./vct.conf
elif [ -f ./vct.conf.default ]; then
	. ./vct.conf.default
fi


MAIN_PID=$BASHPID




##########################################################################
#######  some general tools for convinience
##########################################################################

exit_all() {
    # echo "terminating due to previous error, killing PID=$MAIN_PID from $BASHPID" >&2
    kill $MAIN_PID
    sleep 10
    echo "this should never be printed !!!!!!!!!!!!!!!"
}



err() {
    local FUNC=$1
    local MSG=$2
    local OPT_CMD=${3:-}
    local CMD_SOFT=$( echo "$OPT_CMD" | grep -e "soft" > /dev/null && echo "soft," )

    echo -e "ERROR ${FUNC}(): ${MSG}" >&2

    [ ${CMD_SOFT:-} ] && return 1 || exit_all
}

variable_check() {

    local VAR_NAME=$1
    local OPT_CMD=${2:-}
    local CMD_QUIET=$( echo "$OPT_CMD" | grep -e "quiet" > /dev/null && echo "quiet," )
    local CMD_SOFT=$( echo "$OPT_CMD" | grep -e "soft" > /dev/null && echo "soft," )
    local VAR_VALUE=

    if [ -z $VAR_NAME ]; then
	err $FUNCNAME "missing <cmd> and/or <var-name> parameters"  ${CMD_SOFT:-}; return 1
    fi

#    eval VAR_VALUE=\$$VAR_NAME
    
    set +u # temporary disable set -o nounset
    VAR_VALUE=$( eval echo \$$VAR_NAME  )
    set -u

    if [ -z "$VAR_VALUE" ]; then
	err $FUNCNAME "variable $VAR_NAME undefined"  ${CMD_SOFT:-}; return 1
    fi

    [ -z  ${CMD_QUIET:-} ] && echo "$VAR_VALUE"
    return 0
}


vct_sudo() {

    local QUERY=

    if [ "$VCT_SUDO_ASK" != "NO" ]; then

	echo "$0 wants to execute the following command and VCT_SUDO_ASK has been set to explicitly ask:" >&2
	echo "sudo $@" >&2
	read -p "please type y to continue or anything else to abort: " QUERY >&2

	if [ "$QUERY" == "y" ] ; then
	    sudo $@
	    return $?
	fi
	
	err $FUNCNAME "sudo execution cancelled"
	return 1
    fi

    sudo $@
    return $?
}

ip4_net_to_mask() {
    local NETWORK="$1"

    [ -z ${NETWORK:-} ] &&\
        err $FUNCNAME "Missing network (eg 1.2.3.4/30)  argument"

    ipcalc "$NETWORK" | grep -e "^Netmask:" | awk '{print $2}' ||\
        err $FUNCNAME "Invalidnetwork (eg 1.2.3.4/30)  argument"
    
}



install_url() {

    local URL=$1
    local URL_SITE=$2
    local URL_NAME=$3
    local URL_COMP=$4
    local CACHE_DIR=$5
    local INSTALL_PATH=$6  # /path/to/dir or "-"

    local OPT_CMD=${7:-}
    local CMD_SOFT=$( echo "$OPT_CMD" | grep -e "soft" > /dev/null && echo "soft," || echo "" )
    local CMD_INSTALL=$( echo "$OPT_CMD" | grep -e "install" > /dev/null && echo "install," || echo "" )
    local CMD_UPDATE=$( echo "$OPT_CMD" | grep -e "update" > /dev/null && echo "update," || echo "" )

    [ "$URL" = "${URL_SITE}${URL_NAME}.${URL_COMP}" ] ||\
           { err $FUNCNAME "Invalid $URL != ${URL_SITE}${URL_NAME}.${URL_COMP}" $CMD_SOFT || return 1 ;}


    
    echo $CACHE_DIR | grep  -e "^/" >/dev/null ||
             { err $FUNCNAME "Invalid CACHE_DIR=$CACHE_DIR" $CMD_SOFT || return 1 ;}

    echo $URL_NAME | grep -e "/" -e "*" -e " " >/dev/null &&\
	     { err $FUNCNAME "Illegal fs-template name $URL_NAME" $CMD_SOFT || return 1 ;}

    ( [ $URL_COMP = "tgz" ] ||  [ $URL_COMP = "tar.gz" ] || [ $URL_COMP = "gz" ]  ) ||\
	     { err $FUNCNAME "Non-supported fs template compression $URL_COMP" $CMD_SOFT || return 1 ;}

    if [ $CMD_UPDATE ]; then
	rm -f "$CACHE_DIR/${URL_NAME}.${URL_COMP}"
    fi

    if ! [ -f "$CACHE_DIR/${URL_NAME}.${URL_COMP}" ] ; then 
	
	if [ $CMD_INSTALL ]; then

	    if echo $URL_SITE | grep -e "^ftp://"  -e "^http://"  -e "^https://" >/dev/null; then
		wget -O  $CACHE_DIR/${URL_NAME}.${URL_COMP} $URL  ||\
                       { err $FUNCNAME "No template downloadable from $URL" $CMD_SOFT || return 1 ;}
		
	    elif echo $URL_SITE | grep -e "file://" >/dev/null; then

		cp $( echo $URL_SITE | awk -F'file://' '{print $2}' )/${URL_NAME}.${URL_COMP} $CACHE_DIR/  ||\
                       { err $FUNCNAME "No template accessible from $URL" $CMD_SOFT || return 1 ;}

	    elif echo $URL_SITE | grep -e "^ssh:" >/dev/null ; then
		local SCP_PORT=$( echo $URL_SITE | awk -F':' '{print $2}' )
		local SCP_PORT_USAGE=$( [ $SCP_PORT ] && echo "-P $SCP_PORT" )
		local SCP_USER_DOMAIN=$( echo $URL_SITE | awk -F':' '{print $3}' )
		local SCP_PATH=$( echo $URL_SITE | awk -F'://' '{print $2}' )

		[ $SCP_USER_DOMAIN ] && [ $SCP_PATH ] ||\
                       { err $FUNCNAME "Invalid SCP_USER_DOMAIN=$SCP_USER_DOMAIN or SCP_PATH=$SCP_PATH" $CMD_SOFT || return 1 ;}

 		scp ${SCP_PORT_USAGE} ${SCP_USER_DOMAIN}:${SCP_PATH}/${URL_NAME}.${URL_COMP} $CACHE_DIR/ ||\
                       { err $FUNCNAME "No template accessible from $URL" $CMD_SOFT || return 1 ;}
		
	    else
                err $FUNCNAME "Non-supported URL=$URL" $CMD_SOFT || return 1
	    fi
	else
	    err $FUNCNAME "Non-existing image $CACHE_DIR/${URL_NAME}.${URL_COMP} " $CMD_SOFT || return 1
	fi
    fi

    if echo $INSTALL_PATH | grep -e "^/" >/dev/null &&  ! [ -f $INSTALL_PATH ]; then

	if [ $CMD_INSTALL ] && ( [ "$URL_COMP" = "tgz" ] || [ "$URL_COMP" = "tar.gz" ] ) &&\
                  tar -xzvOf $CACHE_DIR/${URL_NAME}.${URL_COMP} > "$INSTALL_PATH" ; then
	    
	    echo "nop" > /dev/null
	    
	elif [ $CMD_INSTALL ] && [ "$URL_COMP" = "gz" ] &&\
                  gunzip --stdout $CACHE_DIR/${URL_NAME}.${URL_COMP} > "$INSTALL_PATH"   ; then
	    
	    echo "nop" > /dev/null
	    
	else
	    
	    [ $CMD_INSTALL ] && rm -f $CACHE_DIR/${URL_NAME}.${URL_COMP}
	    [ $CMD_INSTALL ] && rm -f $INSTALL_PATH
	    
	    err $FUNCNAME "Non-existing image: $INSTALL_PATH" $CMD_SOFT || return 1
	    
	fi
    fi
}


##########################################################################
#######  
##########################################################################

system_config_check() {

    variable_check VCT_SUDO_ASK        quiet
    variable_check VCT_VIRT_DIR        quiet
    variable_check VCT_SYS_DIR         quiet
    variable_check VCT_DL_DIR          quiet
    variable_check VCT_RPC_DIR         quiet
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


system_install_check() {

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

    if ! [ -f $VCT_KNOWN_HOSTS_FILE ]; then
	( [ $CMD_INSTALL ] && touch $VCT_KNOWN_HOSTS_FILE ) ||\
	 { err $FUNCNAME "$VCT_KNOWN_HOSTS_FILE not existing" $CMD_SOFT || return 1 ;}
    fi

    # check for existing or downloadable file-system-template file:
    if ! install_url $VCT_TEMPLATE_URL $VCT_TEMPLATE_SITE $VCT_TEMPLATE_NAME.$VCT_TEMPLATE_TYPE $VCT_TEMPLATE_COMP $VCT_DL_DIR 0 $OPT_CMD ; then
	err $FUNCNAME "Installing ULR=$VCT_TEMPLATE_URL failed" $CMD_SOFT || return 1
    fi
	
}

system_install() {
    system_install_check "install,$@"
}


system_init_check() {

    local OPT_CMD=${1:-}
    local CMD_SOFT=$( echo "$OPT_CMD" | grep -e "soft" > /dev/null && echo "soft," || echo "" )
    local CMD_QUICK=$( echo "$OPT_CMD" | grep -e "quick" > /dev/null && echo "quick," || echo "" )
    local CMD_INIT=$( echo "$OPT_CMD" | grep -e "init" > /dev/null && echo "init," || echo "" )

    system_install_check $( [ $CMD_SOFT ] && echo "soft," )$( [ $CMD_QUICK ] && echo "quick," )

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
    local BRIDGE
    local BR_NAME
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
	    local BR_V4_IP=$( variable_check ${BRIDGE}_V4_IP soft 2>/dev/null ) 
	    local BR_V4_PL=$( variable_check ${BRIDGE}_V4_PL soft 2>/dev/null )
	    if [ $BR_V4_IP ] && [ $BR_V4_PL ]; then
		if ! ip addr show dev $BR_NAME | grep -e "inet " |grep -e " $BR_V4_IP/$BR_V4_PL " |grep -e " $BR_NAME" >/dev/null; then
		    ( [ $CMD_INIT ] && vct_sudo ip addr add $BR_V4_IP/$BR_V4_PL dev $BR_NAME ) ||\
                	{ err $FUNCNAME "unconfigured ipv4 rescue net: $BR_NAME  $BR_V4_IP/$BR_V4_PL " $CMD_SOFT || return 1 ;}
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
option router   $BR_V4_IP
option dns      $DHCPD_DNS
option serverid $BR_V4_IP
EOF

			vct_sudo udhcpd $UDHCPD_CONF_FILE
		    fi
		    
		    [ "$(ps aux | grep "$UDHCPD_COMMAND" | grep -v grep )" ] || \
			err $FUNCNAME "NO udhcpd server running for $BR_NAME "

		fi


	    fi

            # check if local bridge has rescue IPv6 for local network:
	    local BR_V6_IP=$( variable_check ${BRIDGE}_V6_IP soft 2>/dev/null ) 
	    local BR_V6_PL=$( variable_check ${BRIDGE}_V6_PL soft 2>/dev/null )
	    if [ $BR_V6_IP ] && [ $BR_V6_PL ]; then
		if ! ip addr show dev $BR_NAME | grep -e "inet6 " | \
		    grep -ie " $( ipv6calc -I ipv6 $BR_V6_IP/$BR_V6_PL -O ipv6 ) " >/dev/null; then
		    ( [ $CMD_INIT ] && vct_sudo ip addr add $BR_V6_IP/$BR_V6_PL dev $BR_NAME ) ||\
                	{ err $FUNCNAME "unconfigured ipv6 rescue net: $BR_NAME  $BR_V6_IP/$BR_V6_PL " $CMD_SOFT || return 1 ;}
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


system_init() {
    system_init_check init
}


##########################################################################
#######  
##########################################################################


check_rd_id() {

    local VCRD_ID=${1:-}
    local OPT_CMD=${2:-}
    local CMD_SOFT=$( echo "$OPT_CMD" | grep -e "soft" > /dev/null && echo "soft," )

    if [ -z "$VCRD_ID" ] || ! echo "$VCRD_ID" | grep -e "^[0-9,a-f][0-9,a-f][0-9,a-f][0-9,a-f]$" >/dev/null ; then
	err $FUNCNAME "Invalid RD_ID=$VCRD_ID usage: $FUNCNAME <4-digit-hex RD ID>" ${CMD_SOFT:-} ; return 1
    fi
    
    if [  "$(( 16#${VCRD_ID:2:2} ))" == 0 ] ||  [ "$(( 16#${VCRD_ID:2:2} ))" -gt 253 ]; then
	err $FUNCNAME "sorry, two least significant digits 00, FE, FF are reserved"  ${CMD_SOFT:-} ; return 1
    fi

    echo $VCRD_ID
}



info() {

    local VCRD_ID=${1:-}

    if [ -z "$VCRD_ID" ]; then

	virsh -c qemu:///system list --all

    else


	VCRD_ID=$(check_rd_id $VCRD_ID)

	local VCRD_NAME="${VCT_RD_NAME_PREFIX}${VCRD_ID}"

	virsh -c qemu:///system dominfo $VCRD_NAME
    fi
}

stop() {

    local VCRD_ID=$(check_rd_id ${1:-} )
    local VCRD_NAME="${VCT_RD_NAME_PREFIX}${VCRD_ID}"

    if virsh -c qemu:///system dominfo $VCRD_NAME  2>/dev/null | grep -e "^State:" | grep "running" >/dev/null ; then
	virsh -c qemu:///system destroy $VCRD_NAME ||\
	    err $FUNCNAME "Failed stopping domain $VCRD_NAME"
    fi
}

remove() {

    local VCRD_ID=$(check_rd_id ${1:-} )
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
}


create() {

    system_init_check quick

    local VCRD_ID=$(check_rd_id ${1:-} )
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

	echo $BRIDGE | grep -e "^VCT_BR[0-f][0-f]$" || \
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
	#     remove $VCRD_ID
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
	remove $VCRD_ID
	err $FUNCNAME "Failed creating domain name=$VCRD_NAME"
    fi


}


start() {

    local VCRD_ID=$(check_rd_id ${1:-} )
    local VCRD_NAME="${VCT_RD_NAME_PREFIX}${VCRD_ID}"
    local VCRD_PATH="${VCT_SYS_DIR}/${VCT_TEMPLATE_NAME}-rd${VCRD_ID}.${VCT_TEMPLATE_TYPE}"

    ( [ -f $VCRD_PATH ] &&\
	virsh -c qemu:///system dominfo $VCRD_NAME | grep -e "^State:" | grep "off" >/dev/null &&\
	virsh -c qemu:///system start $VCRD_NAME ) ||\
	    err $FUNCNAME "Failed starting domain $VCRD_NAME"

}


console() {

    local VCRD_ID=$(check_rd_id ${1:-} )
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


ssh4prepare() {

    local VCRD_ID=$(check_rd_id ${1:-} )
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

    if ! arp -n | grep -e "^$VCT_RD_RESCUE_V4_IP" | grep -e "$LOCAL_MAC" > /dev/null; then
	vct_sudo arp -s $VCT_RD_RESCUE_V4_IP  $LOCAL_MAC
    fi

    if ! ping -c 1 -w 2 -W 2 $VCT_RD_RESCUE_V4_IP > /dev/null; then
	echo "Waiting for $VCRD_ID to listen on $VCT_RD_RESCUE_V4_IP... (after boot this may take upto 40 secs)"
	time ping -c 1 -w 60 -W 1 $VCT_RD_RESCUE_V4_IP > /dev/null | grep -e "^user"
    fi
}

ssh4() {

    local VCRD_ID=$(check_rd_id ${1:-} )

    local COMMAND=

    if ! [ -z "${2:-}" ]; then
	COMMAND=". /etc/profile > /dev/null; $2"
    fi

    ssh4prepare $VCRD_ID
    echo > $VCT_KNOWN_HOSTS_FILE

    ssh -o StrictHostKeyChecking=no -o HashKnownHosts=no -o UserKnownHostsFile=$VCT_KNOWN_HOSTS_FILE -o ConnectTimeout=1 \
	root@$VCT_RD_RESCUE_V4_IP "$COMMAND" # 2>&1 | grep -v "Warning: Permanently added"

#    arp -d $VCT_LOCAL_V4_RESCUE_IP 
}

ssh6() {

    local VCRD_ID=$(check_rd_id ${1:-} )

    local COMMAND=

    if ! [ -z "${2:-}" ]; then
	COMMAND=". /etc/profile > /dev/null; $2"
    fi

    echo > $VCT_KNOWN_HOSTS_FILE

    ssh -o StrictHostKeyChecking=no -o HashKnownHosts=no -o UserKnownHostsFile=$VCT_KNOWN_HOSTS_FILE -o ConnectTimeout=1 \
	root@${VCT_RD_LOCAL_V6_PREFIX48}:${VCRD_ID}::${VCT_RD_LOCAL_V6_SUFFIX64} "$COMMAND" # 2>&1 | grep -v "Warning: Permanently added"

}

scp4() {

    local VCRD_ID=$(check_rd_id ${1:-} )
    local SRC=${2:-}
    local DST=${3:-}

    if [ -z ${SRC} ] || [ -z ${DST} ]; then
	err $FUNCNAME "requires 3 arguments <RD_ID> <local-src-path> <remote-dst-path> "
    fi

    
    ssh4prepare $VCRD_ID
    echo > $VCT_KNOWN_HOSTS_FILE

    scp -o StrictHostKeyChecking=no -o HashKnownHosts=no -o UserKnownHostsFile=$VCT_KNOWN_HOSTS_FILE -o ConnectTimeout=1 \
	"$SRC" root@$VCT_RD_RESCUE_V4_IP:$DST 2>&1 | grep -v "Warning: Permanently added"
}

scp6() {

    local VCRD_ID=$(check_rd_id ${1:-} )
    local SRC=${2:-}
    local DST=${3:-}

    if [ -z ${SRC} ] || [ -z ${DST} ]; then
	err $FUNCNAME "requires 3 arguments <RD_ID> <local-src-path> <remote-dst-path> "
    fi

    
#    ssh4prepare $VCRD_ID
    echo > $VCT_KNOWN_HOSTS_FILE

    scp -o StrictHostKeyChecking=no -o HashKnownHosts=no -o UserKnownHostsFile=$VCT_KNOWN_HOSTS_FILE -o ConnectTimeout=1 \
	"$SRC" root@\[${VCT_RD_LOCAL_V6_PREFIX48}:${VCRD_ID}::${VCT_RD_LOCAL_V6_SUFFIX64}\]:$DST 2>&1 | grep -v "Warning: Permanently added"
}


create_rpc_custom0() {

    local VCRD_ID=$(check_rd_id ${1:-} )
    local VCRD_ID_LSB8BIT_DEC=$(( 16#${VCRD_ID:2:2} ))
    local VCRD_NAME="${VCT_RD_NAME_PREFIX}${VCRD_ID}"    
    local VCRD_MAC=$( virsh -c qemu:///system dumpxml $VCRD_NAME | \
	xmlstarlet sel -T -t -m "/domain/devices/interface" \
	-v child::source/attribute::* -o " " -v child::mac/attribute::address -n | \
	grep -e "^$VCT_RD_LOCAL_BRIDGE " | awk '{print $2 }' || \
	err $FUNCNAME "Failed resolving MAC address for $VCRD_NAME $VCT_RD_LOCAL_BRIDGE" )

    local RPC_TYPE="basics"
    local RPC_FILE="${VCRD_ID}-$( date +%Y%m%d_%H%M%S )-${RPC_TYPE}.sh"
    local RPC_PATH="${VCT_RPC_DIR}/${RPC_FILE}"

    
    cat <<EOF > $RPC_PATH
#!/bin/bash

echo "Configuring CONFINE $RPC_TYPE "

# customizing network:
echo "Configuring network... "

uci revert network

uci set network.internal=interface
uci set network.internal.type=bridge
uci set network.internal.proto=static
uci set network.internal.ipaddr=$VCT_RD_INTERNAL_V4_IP
uci set network.internal.netmask=$( ip4_net_to_mask $VCT_RD_INTERNAL_V4_IP/$VCT_RD_INTERNAL_V4_PL )
uci set network.internal.ip6addr=$VCT_RD_INTERNAL_V6_IP/$VCT_RD_INTERNAL_V6_PL

uci set network.internal_ipv6_net=alias
uci set network.internal_ipv6_net.interface=internal
uci set network.internal_ipv6_net.proto=static
uci set network.internal_ipv6_net.ip6addr=$VCT_RD_INTERNAL_V6_IP/$VCT_RD_INTERNAL_V6_PL

uci set network.local=interface
uci set network.local.type=bridge
uci set network.local.ifname=eth0
uci set network.local.macaddr=$VCRD_MAC
uci set network.local.proto=none
uci set network.local.ip6addr=$VCT_RD_LOCAL_V6_PREFIX48:$VCRD_ID::$VCT_RD_LOCAL_V6_SUFFIX64/$VCT_RD_LOCAL_V6_PL

uci set network.rescue_ipv4_net=alias
uci set network.rescue_ipv4_net.interface=local
uci set network.rescue_ipv4_net.proto=static
uci set network.rescue_ipv4_net.ipaddr=$VCT_RD_RESCUE_V4_IP
uci set network.rescue_ipv4_net.netmask=$( ip4_net_to_mask $VCT_RD_RESCUE_V4_IP/$VCT_RD_RESCUE_V4_PL )

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
uci set network.dflt_route.gateway=$VCT_BR00_V4_IP

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
EOF


    cat <<EOF >> $RPC_PATH
lxc.lib lxc_stop       fd_dummy
lxc.lib lxc_purge      fd_dummy
lxc.lib lxc_create_uci fd_dummy default
lxc.lib uci_set lxc.fd_dummy.auto_boot=1
lxc.lib uci_set lxc.fd_dummy.auto_create=1
lxc.lib lxc_start      fd_dummy
EOF

    cat <<EOF >> $RPC_PATH
echo restarting network...
/etc/init.d/network restart

uci revert system
uci set system.@system[0].hostname="rd${VCRD_ID}"
uci commit system
echo "rd${VCRD_ID}" > /proc/sys/kernel/hostname

uci revert lxc
uci set lxc.general.lxc_host_id=${VCRD_ID}
uci commit lxc

# remove useless busybox links:
[ -h /bin/rm ] && [ -x /usr/bin/rm ] && rm /bin/rm
[ -h /bin/ping ] && [ -x /usr/bin/ping ] && rm /bin/ping

EOF





    cat <<EOF >> $RPC_PATH

#echo "" > /etc/config/confine-defaults
#uci reset confine-defaults
#uci commit confine-defaults

echo "" > /etc/config/confine-testbed
uci reset confine-testbed
uci set confine-testbed.testbed=testbed
uci set confine-testbed.testbed.mgmt_ipv6_prefix48=$VCT_TESTBED_MGMT_IPV6_PREFIX48
uci set confine-testbed.testbed.priv_dflt_ipv6_prefix48=$VCT_TESTBED_PRIV_IPV6_PREFIX48
uci set confine-testbed.testbed.priv_dflt_ipv4_prefix24=$VCT_TESTBED_PRIV_IPV4_PREFIX24
uci set confine-testbed.testbed.mac_dflt_prefix16=$VCT_TESTBED_MAC_PREFIX16
uci commit confine-testbed

echo "" > /etc/config/confine-server
uci reset confine-server
uci set confine-server.server=server
uci set confine-server.server.cn_url=""
uci set confine-server.server.mgmt_pubkey="$( cat $VCT_SERVER_MGMT_PUBKEY )"
uci set confine-server.server.tinc_ip=$VCT_SERVER_TINC_IP
uci set confine-server.server.tinc_port=$VCT_SERVER_TINC_PORT
uci commit confine-server

echo "" > /etc/config/confine-node
uci reset confine-node
uci set confine-node.node=node
uci set confine-node.node.id=$VCRD_ID
uci set confine-node.node.rd_pubkey="\$( dropbearkey -y -f /etc/dropbear/dropbear_rsa_host_key  | grep ssh-rsa )"
uci set confine-node.node.cn_url=""
uci set confine-node.node.mac_prefix16=$VCT_TESTBED_MAC_PREFIX16
uci set confine-node.node.rd_public_ipv4_proto=$VCT_NODE_PUBLIC_IPV4_PROTO

[ "$VCT_NODE_PUBLIC_IPV4_PROTO" = "static" ] && \
uci set confine-node.node.rd_public_ipv4_addrs="$( echo $( for i in $( seq 1 $VCT_NODE_PUBLIC_IPV4_AVAIL ); do echo $VCT_NODE_PUBLIC_IPV4_PREFIX16.$(( 16#${VCRD_ID:2:2} )).$i; done )  )"

uci set confine-node.node.rd_public_ipv4_avail=$VCT_NODE_PUBLIC_IPV4_AVAIL
uci set confine-node.node.state=install
uci commit confine-node

EOF

    chmod u+x $RPC_PATH

    echo $RPC_FILE
}


customize0() {

    local VCRD_ID=$(check_rd_id $1 )
    local VCRD_NAME="${VCT_RD_NAME_PREFIX}${VCRD_ID}"


    virsh -c qemu:///system dominfo $VCRD_NAME | grep -e "^State:" | grep "running" >/dev/null || \
	err $FUNCNAME "$VCRD_NAME not running"

    scp4 $VCRD_ID "$VCT_RD_AUTHORIZED_KEY" /etc/dropbear/authorized_keys 

    local RPC_BASICS=$( create_rpc_custom0 $VCRD_ID )
    ssh4 $VCRD_ID "mkdir -p /tmp/rpc-files"
    scp4 $VCRD_ID $VCT_RPC_DIR/$RPC_BASICS /tmp/rpc-files/
    ssh4 $VCRD_ID "/tmp/rpc-files/$RPC_BASICS"
}



create_rpc_allocate() {

    local VCRD_ID=$(check_rd_id ${1} )
    local SLICE_ID=$2
    local VCRD_ID_LSB8BIT_DEC=$(( 16#${VCRD_ID:2:2} ))
    local VCRD_NAME="${VCT_RD_NAME_PREFIX}${VCRD_ID}"    

    local RPC_TYPE="allocate"
    local RPC_FILE="${VCRD_ID}-$( date +%Y%m%d_%H%M%S )-${RPC_TYPE}-${SLICE_ID}.sh"
    local RPC_PATH="${VCT_RPC_DIR}/${RPC_FILE}"

    
    cat <<EOFRPC > $RPC_PATH

confine.lib confine_sliver_allocate <<EOF
config slice $SLICE_ID
    option user_pubkey     
    option fs_template_url 
    option exp_data_url    
    option if01_type       public
    option if02_type       isolated
    option if01_parent     eth1
EOF

EOFRPC
}


rpc() {

    local RPC_CMD=$1
    local VCRD_ID=$(check_rd_id $2 )
    local SLICE_ID=$3

    local VCRD_NAME="${VCT_RD_NAME_PREFIX}${VCRD_ID}"

    virsh -c qemu:///system dominfo $VCRD_NAME | grep -e "^State:" | grep "running" >/dev/null || \
	err $FUNCNAME "$VCRD_NAME not running"

    local RPC_FILE=
    RPC_FILE=$( create_rpc_$RPC_CMD $VCRD_ID $SLICE_ID ) || \
	err $FUNCNAME "Failed calling create_rpc_$RPC_CMD"
    
    ssh6 $VCRD_ID "mkdir -p /tmp/rpc-files"
    scp6 $VCRD_ID $VCT_RPC_DIR/$RPC_FILE /tmp/rpc-files/
    ssh6 $VCRD_ID "/tmp/rpc-files/$RPC_FILE"
}



help() {

    echo "usage..."
    cat <<EOF

    help

    info  [<rd-id>]                : summary of existing domain(s)

    system_install [update]        : install vct system requirements
    system_init                    : initialize vct system on host

    create <rd-id>                 : create domain with given rd-id
    start  <rd-id>                 : start domain with given rd-id
    stop   <rd-id>                 : stop domain with given rd-id
    remove <rd-id>                 : remove domain with given rd-id

    console <rd-id>                : open console to running domain

    customize0  <rd-id>            : configure id-specific IPv6 address in domain & more...

    ssh4|ssh6 <rd-id> ["commands"] : connect (& execute commands) via ssh (IPv4 or IPv6)
    scp4|scp6 <rd-id> <local src-path> <remote dst-path> : copy data via scp (IPv4 or IPv6)



    Future requests (commands not yet implemnted):

    link-get [rd-id]               : show configured links
    link-add <rd-id-A:direct-if-A> <rd-id-B:direct-if-B> <[packet-loss]> 
                                     virtually link rd-id a via direct if a with rd b
                                     example $ ./vct.sh link-add 0003:1 0005:1 10
                                     to setup a link between given RDs with 10% packet loss
    link-del [<rd-id-A[:direct-if-A]>] [<rd-id-B[:direct-if-B>]] : del configured link(s)


EOF

}

test() {

    vct_sudo $@ || err $FUNCNAME "failed"

}


system_config_check

# check if correct user:
if [ $(whoami) != $VCT_USER ] || [ $(whoami) = root ] ;then
    err $0 "command must be executed as non-root user=$VCT_USER"  || return 1
fi


if [ -z ${1:-} ]; then
    help
    exit 1
fi

case "$1" in
    
        h|help)  help;;

	system_install_check)  $*;;
	system_install)  $*;;
	system_init_check)  $*;;
	system_init)  $*;;

	i|info)     $*;;
	create)     $1 $2;;
	start)      $1 $2;;
	stop)       $1 $2;;
	remove)     $1 $2;;
	console)    $1 $2;;
	ssh4)       $1 $2 "${3:-}";;
	ssh6)       $1 $2 "${3:-}";;
	scp4)       $1 $2 "$3" "$4";;
	scp6)       $1 $2 "$3" "$4";;
        customize0) $1 $2;;
	test)    $*;;
	
        *) echo "unknown command!" ; exit 1 ;;
esac

#echo "successfully finished $0 $*" >&2
echo