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
    # sleep 1
    kill $MAIN_PID
    echo "this should never be printed !!!!!!!!!!!!!!!"
}



dbg() {
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
	dbg $FUNCNAME "missing <cmd> and/or <var-name> parameters"  ${CMD_SOFT:-}; return 1
    fi

#    eval VAR_VALUE=\$$VAR_NAME
    
    set +u # temporary disable set -o nounset
    VAR_VALUE=$( eval echo \$$VAR_NAME  )
    set -u

    if [ -z "$VAR_VALUE" ]; then
	dbg $FUNCNAME "variable $VAR_NAME undefined"  ${CMD_SOFT:-}; return 1
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
	
	dbg $FUNCNAME "sudo execution cancelled"
	return 1
    fi

    sudo $@
    return $?
}

ip4_net_to_mask() {
    local NETWORK="$1"

    [ -z ${NETWORK:-} ] &&\
        dbg $FUNCNAME "Missing network (eg 1.2.3.4/30)  argument"

    ipcalc "$NETWORK" | grep -e "^Netmask:" | awk '{print $2}' ||\
        dbg $FUNCNAME "Invalidnetwork (eg 1.2.3.4/30)  argument"
    
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
    variable_check VCT_TEMPLATE_NAME   quiet
    variable_check VCT_TEMPLATE_TYPE   quiet
    variable_check VCT_DEB_PACKAGES    quiet
    variable_check VCT_USER            quiet
    variable_check VCT_VIRT_GROUP      quiet
    variable_check VCT_BRIDGE_PREFIXES quiet
    variable_check VCT_TOOL_TESTS      quiet
    variable_check VCT_INTERFACE_MODEL quiet
    variable_check VCT_INTERFACE_MAC24 quiet

}


system_install_check() {

    local OPT_CMD=${1:-}
    local CMD_SOFT=$( echo "$OPT_CMD" | grep -e "soft" > /dev/null && echo "soft," || echo "" )
    local CMD_QUICK=$( echo "$OPT_CMD" | grep -e "quick" > /dev/null && echo "quick," || echo "" )
    local CMD_INSTALL=$( echo "$OPT_CMD" | grep -e "install" > /dev/null && echo "install," || echo "" )
    local CMD_UPDATE=$( echo "$OPT_CMD" | grep -e "update" > /dev/null && echo "update," || echo "" )

    # check if correct user:
    if [ $(whoami) != $VCT_USER ] || [ $(whoami) = root ] ;then
	dbg $FUNCNAME "command must be executed as user=$VCT_USER" $CMD_SOFT || return 1
    fi

    # check debian system, packages, tools, and kernel modules
    ! aptitude --version > /dev/null && dpkg --version > /dev/null &&\
	{ dbg $FUNCNAME "missing debian system tool dpkg or aptitude" $CMD_SOFT || return 1 ;}
    
    if ! [ $CMD_QUICK ]; then

	local PACKAGE=
	for PACKAGE in $VCT_DEB_PACKAGES; do
	    dpkg -s $PACKAGE 2>&1 |grep "Status:" |grep "install" |grep "ok" |grep "installed" > /dev/null ||\
		{ dbg $FUNCNAME "missing debian package: $PACKAGE" $CMD_SOFT || return 1 ;}
	done

	local TOOL_POS=
	local TOOL_CMD=
	for TOOL_POS in $(seq 0 $(( ${#VCT_TOOL_TESTS[@]} - 1)) ); do
	    TOOL_CMD=${VCT_TOOL_TESTS[$TOOL_POS]}
	    $TOOL_CMD  > /dev/null 2>&1 ||\
		{ dbg $FUNCNAME "tool test: $TOOL_CMD failed" $CMD_SOFT || return 1 ;}
	done

	local MODULE=
	for MODULE in $VCT_KERNEL_MODULES; do
	    lsmod | grep -e "^$MODULE" > /dev/null ||\
		{ dbg $FUNCNAME "missing kernel module: $MODULE" $CMD_SOFT || return 1 ;}
	done

    fi

    # check if user in required groups:
    groups | grep "$VCT_VIRT_GROUP" > /dev/null ||\
	{ dbg $FUNCNAME "user=$VCT_USER MUST be in groups: $VCT_VIRT_GROUP \n do: sudo adduser $VCT_USER $VCT_VIRT_GROUP and ReLogin!" $CMD_SOFT || return 1 ;}



    if ! [ -d $VCT_VIRT_DIR ]; then
	( [ $CMD_INSTALL ] && vct_sudo mkdir -p $VCT_VIRT_DIR ) && vct_sudo chown $VCT_USER $VCT_VIRT_DIR ||\
	 { dbg $FUNCNAME "$VCT_SYS_DIR not existing" $CMD_SOFT || return 1 ;}
    fi

    # check libvirt systems directory:
    if ! [ -d $VCT_SYS_DIR ]; then
	( [ $CMD_INSTALL ] && mkdir -p $VCT_SYS_DIR ) ||\
	 { dbg $FUNCNAME "$VCT_SYS_DIR not existing" $CMD_SOFT || return 1 ;}
    fi

    # check downloads directory:
    if ! [ -d $VCT_DL_DIR ]; then
	( [ $CMD_INSTALL ] && mkdir -p $VCT_DL_DIR ) ||\
	 { dbg $FUNCNAME "$VCT_DL_DIR  not existing" $CMD_SOFT || return 1 ;}
    fi

    # check rpc-file directory:
    if ! [ -d $VCT_RPC_DIR ]; then
	( [ $CMD_INSTALL ] && mkdir -p $VCT_RPC_DIR ) ||\
	 { dbg $FUNCNAME "$VCT_RPC_DIR  not existing" $CMD_SOFT || return 1 ;}
    fi

    if ! [ -f $VCT_KNOWN_HOSTS_FILE ]; then
	( [ $CMD_INSTALL ] && touch $VCT_KNOWN_HOSTS_FILE ) ||\
	 { dbg $FUNCNAME "$VCT_KNOWN_HOSTS_FILE not existing" $CMD_SOFT || return 1 ;}
    fi


    # check for existing or downloadable file-system-template file:
    if [ $VCT_TEMPLATE_NAME ] && [ $VCT_TEMPLATE_TYPE ] ; then 

	( [ $VCT_TEMPLATE_TYPE = "vmdk" ] || [ $VCT_TEMPLATE_TYPE = "raw" ] || [ $VCT_TEMPLATE_TYPE = "img" ] ) ||\
	     { dbg $FUNCNAME "Non-supported fs template type $VCT_TEMPLATE_TYPE" $CMD_SOFT || return 1 ;}

	[ $VCT_TEMPLATE_COMP ] && ( ( [ $VCT_TEMPLATE_COMP = "tgz" ] ||  [ $VCT_TEMPLATE_COMP = "gz" ]  ) ||\
	     { dbg $FUNCNAME "Non-supported fs template compression $VCT_TEMPLATE_COMP" $CMD_SOFT || return 1 ;} )

	
	local NAME_TYPE="${VCT_TEMPLATE_NAME}${VCT_TEMPLATE_VERS}.${VCT_TEMPLATE_TYPE}"
	local NAME_TYPE_COMP="${NAME_TYPE}.${VCT_TEMPLATE_COMP}"

	echo $NAME_TYPE_COMP | grep -e "/" -e "*" -e " " &&\
	     { dbg $FUNCNAME "Illegal fs-template name $NAME_TYPE_COMP" $CMD_SOFT || return 1 ;}

	if [ $CMD_UPDATE ]; then
	    rm -f "$VCT_DL_DIR/$NAME_TYPE"
	    rm -f "$VCT_DL_DIR/$NAME_TYPE_COMP"
	fi

	
	if ! [ -f $VCT_DL_DIR/$NAME_TYPE ] && ! [ -f $VCT_DL_DIR/$NAME_TYPE_COMP ]; then

	    if [ $CMD_INSTALL ]; then

		[ "${VCT_TEMPLATE_URL:-}" ] ||\
        	     { dbg $FUNCNAME "Undefined VCT_TEMPLATE_URL to retrieve template image:" $CMD_SOFT || return 1 ;}

		if echo "$VCT_TEMPLATE_URL" | grep -e "^ftp://"  -e "^http://"  -e "^https://" ; then
		    wget -O  $VCT_DL_DIR/$NAME_TYPE_COMP $VCT_TEMPLATE_URL/$NAME_TYPE_COMP  ||\
                       { dbg $FUNCNAME "No template $NAME_TYPE_COMP downloadable from $VCT_TEMPLATE_URL" $CMD_SOFT || return 1 ;}

		elif echo "$VCT_TEMPLATE_URL" | grep -e "file://" ; then
		    cp "$( echo $VCT_TEMPLATE_URL | awk -F'file://' '{print $2}' )/$NAME_TYPE_COMP" "$VCT_DL_DIR/$NAME_TYPE_COMP"  ||\
                       { dbg $FUNCNAME "No template $NAME_TYPE_COMP accessible from $VCT_TEMPLATE_URL" $CMD_SOFT || return 1 ;}

		elif echo "$VCT_TEMPLATE_URL" | grep -e "^ssh:" ; then
		    local SCP_PORT=$( echo "$VCT_TEMPLATE_URL" | awk -F':' '{print $2}' )
		    local SCP_PORT_USAGE=$( [ $SCP_PORT ] && echo "-P $SCP_PORT" )
		    local SCP_USER_DOMAIN=$( echo "$VCT_TEMPLATE_URL" | awk -F':' '{print $3}' )
		    local SCP_PATH=$( echo "$VCT_TEMPLATE_URL" | awk -F':' '{print $4}' )

		    ( [ "$SCP_USER_DOMAIN" ] && [ "$SCP_PATH" ] &&\
		       scp "${SCP_PORT_USAGE}" "${SCP_USER_DOMAIN}:${SCP_PATH}/$NAME_TYPE_COMP" "$VCT_DL_DIR/$NAME_TYPE_COMP" ) ||\
                       { dbg $FUNCNAME "No template $NAME_TYPE_COMP accessible from $VCT_TEMPLATE_URL" $CMD_SOFT || return 1 ;}

		else
                    dbg $FUNCNAME "Non-supported VCT_TEMPLATE_URL=$VCT_TEMPLATE_URL" $CMD_SOFT || return 1
		fi
	    fi


	fi

	if ! [ -f $VCT_DL_DIR/$NAME_TYPE ]; then

	    if [ $CMD_INSTALL ] && [ "$VCT_TEMPLATE_COMP" = "tgz" ] &&\
                  tar -xzvOf  "$VCT_DL_DIR/$NAME_TYPE_COMP" > "$VCT_DL_DIR/$NAME_TYPE" ; then

		echo "nop" > /dev/null

	    elif [ $CMD_INSTALL ] && [ "$VCT_TEMPLATE_COMP" = "gz" ] &&\
                  gunzip --stdout "$VCT_DL_DIR/$NAME_TYPE_COMP" > "$VCT_DL_DIR/$NAME_TYPE"   ; then

		echo "nop" > /dev/null

	    else

		[ $CMD_INSTALL ] && rm $VCT_DL_DIR/$NAME_TYPE
		
		dbg $FUNCNAME "Non-existing template system image: $NAME_TYPE " $CMD_SOFT || return 1

	    fi
	fi
	
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

    # check if libvirtd is running:
    ! virsh --connect qemu:///system list --all > /dev/null &&\
	{ dbg $FUNCNAME "libvirt-bin service not running! " $CMD_SOFT || return 1 ;}


    # check if bridges are initialized:
    local BRIDGE
    local BR_NAME
    for BRIDGE in $VCT_BRIDGE_PREFIXES; do
	if BR_NAME=$( variable_check ${BRIDGE}_NAME soft ); then

            # check if bridge exist:
	    if ! brctl show | grep $BR_NAME >/dev/null; then
		( [ $CMD_INIT ]                &&\
		  vct_sudo "brctl addbr $BR_NAME && brctl setfd $BR_NAME 0 && brctl sethello $BR_NAME 1 && brctl stp $BR_NAME off" ) ||\
                	{ dbg $FUNCNAME "unconfigured bridge $BR_NAME" $CMD_SOFT || return 1 ;}
	    fi

            # check if local bridge has IPv4 for resuce network : 
	    local BR_V4_IP=$( variable_check ${BRIDGE}_V4_IP soft 2>/dev/null ) 
	    local BR_V4_PL=$( variable_check ${BRIDGE}_V4_PL soft 2>/dev/null )
	    if [ $BR_V4_IP ] && [ $BR_V4_PL ]; then
		if ! ip addr show dev $BR_NAME | grep -e "inet " |grep -e " $BR_V4_IP/$BR_V4_PL " |grep -e " $BR_NAME" >/dev/null; then
		    ( [ $CMD_INIT ] && vct_sudo ip addr add $BR_V4_IP/$BR_V4_PL dev $BR_NAME ) ||\
                	{ dbg $FUNCNAME "unconfigured ipv4 rescue net: $BR_NAME  $BR_V4_IP/$BR_V4_PL " $CMD_SOFT || return 1 ;}
		fi
	    fi

            # check if local bridge has IPv6 for rescue network:
	    local BR_V6_IP=$( variable_check ${BRIDGE}_V6_IP soft 2>/dev/null ) 
	    local BR_V6_PL=$( variable_check ${BRIDGE}_V6_PL soft 2>/dev/null )
	    if [ $BR_V6_IP ] && [ $BR_V6_PL ]; then
		if ! ip addr show dev $BR_NAME | grep -e "inet6 " |grep -ie " $BR_V6_IP/$BR_V6_PL " >/dev/null; then
		    ( [ $CMD_INIT ] && vct_sudo ip addr add $BR_V6_IP/$BR_V6_PL dev $BR_NAME ) ||\
                	{ dbg $FUNCNAME "unconfigured ipv6 rescue net: $BR_NAME  $BR_V6_IP/$BR_V6_PL " $CMD_SOFT || return 1 ;}
		fi
	    fi

            # check if bridge is UP:
	    if ! ip link show dev $BR_NAME | grep ",UP" >/dev/null; then
		    ( [ $CMD_INIT ] && vct_sudo ip link set dev  $BR_NAME up ) ||\
                	{ dbg $FUNCNAME "disabled link $BR_NAME" $CMD_SOFT || return 1 ;}
	    fi

            # check if bridge needs routed NAT:
	    local BR_V4_NAT_OUT=$( variable_check ${BRIDGE}_V4_NAT_OUT_DEV soft 2>/dev/null )
	    local BR_V4_NAT_SRC=$( variable_check ${BRIDGE}_V4_NAT_OUT_SRC soft 2>/dev/null )
	    
	    if [ $BR_V4_NAT_SRC ] && [ $BR_V4_NAT_OUT ]; then
                if ! vct_sudo iptables -t nat -L POSTROUTING -nv |grep -e "MASQUERADE" |grep -e "$BR_V4_NAT_OUT" |grep -e "$BR_V4_NAT_SRC" >/dev/null; then
		    ( [ $CMD_INIT ] && vct_sudo iptables -t nat -I POSTROUTING -o $BR_V4_NAT_OUT -s $BR_V4_NAT_SRC -j MASQUERADE ) ||\
                  	{ dbg $FUNCNAME "invalid NAT from $BR_NAME" $CMD_SOFT || return 1 ;}
		fi 
	    fi
	    

	fi
    done

    # check if bridge has disabled features:
    local PROC_FILE=
    for PROC_FILE in $(ls /proc/sys/net/bridge); do
	if ! [ $(cat /proc/sys/net/bridge/$PROC_FILE) = "0" ]; then
	    [ $CMD_INIT ] && vct_sudo sysctl -w net.bridge.$PROC_FILE=0 > /dev/null
	    [ $(cat /proc/sys/net/bridge/$PROC_FILE) = "0" ] ||\
	    { dbg $FUNCNAME "/proc/sys/net/bridge/$PROC_FILE != 0" $CMD_SOFT || return 1 ;}
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
	dbg $FUNCNAME "Invalid RD_ID=$VCRD_ID usage: $FUNCNAME <4-digit-hex RD ID>" ${CMD_SOFT:-} ; return 1
    fi
    
    if [  "$(( 16#${VCRD_ID:2:3} ))" == 0 ] ||  [ "$(( 16#${VCRD_ID:2:3} ))" -gt 253 ]; then
	dbg $FUNCNAME "sorry, two least significant digits 00, FE, FF are reserved"  ${CMD_SOFT:-} ; return 1
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
	    dbg $FUNCNAME "Failed stopping domain $VCRD_NAME"
    fi
}

remove() {

    local VCRD_ID=$(check_rd_id ${1:-} )
    local VCRD_NAME="${VCT_RD_NAME_PREFIX}${VCRD_ID}"
    local VCRD_PATH="${VCT_SYS_DIR}/${VCT_TEMPLATE_NAME}${VCT_TEMPLATE_VERS}-rd${VCRD_ID}.${VCT_TEMPLATE_TYPE}"

    stop $VCRD_ID
    
    echo $FUNCNAME

    if virsh -c qemu:///system dominfo $VCRD_NAME  2>/dev/null | grep -e "^State:" | grep "off" >/dev/null ; then
	virsh -c qemu:///system undefine $VCRD_NAME ||\
	    dbg $FUNCNAME "Failed undefining domain $VCRD_NAME"
    fi

    [ -f $VCRD_PATH ] && rm -f $VCRD_PATH

}


create() {

    system_init_check quick

    local VCRD_ID=$(check_rd_id ${1:-} )
    local VCRD_NAME="${VCT_RD_NAME_PREFIX}${VCRD_ID}"
    local VCRD_PATH="${VCT_SYS_DIR}/${VCT_TEMPLATE_NAME}${VCT_TEMPLATE_VERS}-rd${VCRD_ID}.${VCT_TEMPLATE_TYPE}"


    ( [ -f $VCRD_PATH ] || virsh -c qemu:///system dominfo $VCRD_NAME 2>/dev/null ) &&\
	    dbg $FUNCNAME "Domain name=$VCRD_NAME and/or path=$VCRD_PATH already exists"

    cp "${VCT_DL_DIR}/${VCT_TEMPLATE_NAME}${VCT_TEMPLATE_VERS}.${VCT_TEMPLATE_TYPE}" $VCRD_PATH ||\
	    dbg $FUNCNAME "Failed creating path=$VCRD_PATH of domain name=$VCRD_NAME"



    local VCRD_NETW=""
    local BRIDGE=
    for BRIDGE in $VCT_BRIDGE_PREFIXES; do

	local BR_NAME=

	echo $BRIDGE | grep -e "^VCT_BR[0-f][0-f]$" || \
	    dbg $FUNCNAME "Invalid VCT_BRIDGE_PREFIXES naming convention: $BRIDGE"

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
	#     dbg $FUNCNAME "Failed attaching-interface $VCRD_IFACE to $VCRD_NAME"
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
	dbg $FUNCNAME "Failed creating domain name=$VCRD_NAME"
    fi


}


start() {

    local VCRD_ID=$(check_rd_id ${1:-} )
    local VCRD_NAME="${VCT_RD_NAME_PREFIX}${VCRD_ID}"
    local VCRD_PATH="${VCT_SYS_DIR}/${VCT_TEMPLATE_NAME}${VCT_TEMPLATE_VERS}-rd${VCRD_ID}.${VCT_TEMPLATE_TYPE}"

    ( [ -f $VCRD_PATH ] &&\
	virsh -c qemu:///system dominfo $VCRD_NAME | grep -e "^State:" | grep "off" >/dev/null &&\
	virsh -c qemu:///system start $VCRD_NAME ) ||\
	    dbg $FUNCNAME "Failed starting domain $VCRD_NAME"

}


console() {

    local VCRD_ID=$(check_rd_id ${1:-} )
    local VCRD_NAME="${VCT_RD_NAME_PREFIX}${VCRD_ID}"

    if virsh -c qemu:///system dominfo $VCRD_NAME | grep -e "^State:" | grep "running" >/dev/null ; then
	virsh -c qemu:///system console $VCRD_NAME && return 0


	local CONSOLE_PTS=$( virsh -c qemu:///system dumpxml $VCRD_NAME | \
	    xmlstarlet sel -T -t -m "/domain/devices/console/source" -v attribute::path -n |
	    grep -e "^/dev/pts/" || \
		dbg $FUNCNAME "Failed resolving pts path for $VCRD_NAME" )

	if ! ls -l $CONSOLE_PTS | grep -e "rw....rw." ; then 
	    vct_sudo chmod o+rw $CONSOLE_PTS 
	    virsh -c qemu:///system console $VCRD_NAME && return 0
	fi

	dbg $FUNCNAME "Failed connecting console to domain $VCRD_NAME"
    fi
}


ssh4prepare() {

    local VCRD_ID=$(check_rd_id ${1:-} )
    local VCRD_NAME="${VCT_RD_NAME_PREFIX}${VCRD_ID}"


    variable_check VCT_RD_RESCUE_BRIDGE quiet
    variable_check VCT_RD_RESCUE_V4_IP quiet
    variable_check VCT_KNOWN_HOSTS_FILE quiet


    local RESCUE_MAC=$( virsh -c qemu:///system dumpxml $VCRD_NAME | \
	xmlstarlet sel -T -t -m "/domain/devices/interface" \
	-v child::source/attribute::* -o " " -v child::mac/attribute::address -n | \
	grep -e "^$VCT_RD_RESCUE_BRIDGE " | awk '{print $2 }' || \
	dbg $FUNCNAME "Failed resolving MAC address for $VCRD_NAME $VCT_RD_RESCUE_BRIDGE" )

    # echo "connecting to $VCT_RD_RESCUE_V4_IP via $RESCUE_MAC"

    if ! arp -n | grep -e "^$VCT_RD_RESCUE_V4_IP" | grep -e "$RESCUE_MAC" > /dev/null; then
	vct_sudo arp -s $VCT_RD_RESCUE_V4_IP  $RESCUE_MAC
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

#    arp -d $VCT_RESCUE_V4_IP 
}

ssh6() {

    local VCRD_ID=$(check_rd_id ${1:-} )

    local COMMAND=

    if ! [ -z "${2:-}" ]; then
	COMMAND=". /etc/profile > /dev/null; $2"
    fi

    echo > $VCT_KNOWN_HOSTS_FILE

    ssh -o StrictHostKeyChecking=no -o HashKnownHosts=no -o UserKnownHostsFile=$VCT_KNOWN_HOSTS_FILE -o ConnectTimeout=1 \
	root@${VCT_RD_RESCUE_V6_PREFIX48}:${VCRD_ID}::${VCT_RD_RESCUE_V6_SUFFIX64} "$COMMAND" # 2>&1 | grep -v "Warning: Permanently added"

}

scp4() {

    local VCRD_ID=$(check_rd_id ${1:-} )
    local SRC=${2:-}
    local DST=${3:-}

    if [ -z ${SRC} ] || [ -z ${DST} ]; then
	dbg $FUNCNAME "requires 3 arguments <RD_ID> <local-src-path> <remote-dst-path> "
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
	dbg $FUNCNAME "requires 3 arguments <RD_ID> <local-src-path> <remote-dst-path> "
    fi

    
#    ssh4prepare $VCRD_ID
    echo > $VCT_KNOWN_HOSTS_FILE

    scp -o StrictHostKeyChecking=no -o HashKnownHosts=no -o UserKnownHostsFile=$VCT_KNOWN_HOSTS_FILE -o ConnectTimeout=1 \
	"$SRC" root@\[${VCT_RD_RESCUE_V6_PREFIX48}:${VCRD_ID}::${VCT_RD_RESCUE_V6_SUFFIX64}\]:$DST 2>&1 | grep -v "Warning: Permanently added"
}


create_rpc_custom0() {

    local VCRD_ID=$(check_rd_id ${1:-} )
    local RPC_TYPE="basics"
    local RPC_FILE="${VCRD_ID}-$( date +%Y%m%d_%H%M%S )-${RPC_TYPE}.sh"
    local RPC_PATH="${VCT_RPC_DIR}/${RPC_FILE}"

    
    cat <<EOF > $RPC_PATH
#!/bin/sh

echo "Configuring CONFINE $RPC_TYPE "

uci revert network

uci set network.local_ipv6_rescue_net=alias
uci set network.local_ipv6_rescue_net.interface=local
uci set network.local_ipv6_rescue_net.proto=static
uci set network.local_ipv6_rescue_net.ipaddr=${VCT_RD_RESCUE_V6_PREFIX48}:${VCRD_ID}::${VCT_RD_RESCUE_V6_SUFFIX64}
uci set network.local_ipv6_rescue_net.netmask=$VCT_RD_RESCUE_V6_PL

uci set network.internal=interface
uci set network.internal.type=bridge
uci set network.internal.iface='sl01_I sl02_I sl03_I sl04_I '
uci set network.internal.proto=static
uci set network.internal.ipaddr=$VCT_RD_INTERNAL_V4_IP
uci set network.internal.netmask=$( ip4_net_to_mask $VCT_RD_INTERNAL_V4_IP/$VCT_RD_INTERNAL_V4_PL )

uci set network.internal_ipv6_net=alias
uci set network.internal_ipv6_net.interface=internal
uci set network.internal_ipv6_net.proto=static
uci set network.internal_ipv6_net.ipaddr=$VCT_RD_INTERNAL_V6_IP/$VCT_RD_INTERNAL_V6_PL

uci commit network

/etc/init.d/network restart



uci revert system
uci set system.@system[0].hostname="rd${VCRD_ID}"
uci commit system
echo "rd${VCRD_ID}" > /proc/sys/kernel/hostname


# remove useless busybox links:
[ -h /bin/rm ] && [ -x /usr/bin/rm ] && rm /bin/rm
[ -h /bin/ping ] && [ -x /usr/bin/ping ] && rm /bin/ping


EOF

    chmod u+x $RPC_PATH

    echo $RPC_FILE
}


customize0() {

    local VCRD_ID=$(check_rd_id ${1:-} )


    scp4 $VCRD_ID "$VCT_RD_AUTHORIZED_KEY" /etc/dropbear/authorized_keys 

    local RPC_BASICS=$( create_rpc_custom0 $VCRD_ID )
    ssh4 $VCRD_ID "mkdir -p /tmp/rpc-files"
    scp4 $VCRD_ID $VCT_RPC_DIR/$RPC_BASICS /tmp/rpc-files
    ssh4 $VCRD_ID "/tmp/rpc-files/$RPC_BASICS"
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

    customize0  <rd-id>            : configure id-specific IPv6 address in domain

    ssh4|ssh6 <rd-id> ["commands"] : connect (& execute commands) via ssh (IPv4 or IPv6)
    scp4|scp6 <rd-id> <local src-path> <remote dst-path> : copy data via scp (IPv4 or IPv6)

EOF

}

test() {

    vct_sudo $@ || dbg $FUNCNAME "failed"

}


system_config_check

# check if correct user:
if [ $(whoami) != $VCT_USER ] || [ $(whoami) = root ] ;then
    dbg $0 "command must be executed as non-root user=$VCT_USER"  || return 1
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