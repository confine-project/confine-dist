#!/bin/bash

set -u # set -o nounset
#set -o errexit

LANG=C


if [ -f ./vct.conf.overrides ]; then
    . ./vct.conf.default
    . ./vct.conf.overrides
elif [ -f ./vct.conf ]; then
    . ./vct.conf
elif [ -f ./vct.conf.default ]; then
    . ./vct.conf.default
fi


# MAIN_PID=$BASHPID

VCT_NODE_MAC_DB=./vct.nodes
UCI_DEFAULT_PATH=$VCT_UCI_DIR
ERR_LOG_TAG='VCT'
. ./lxc.functions
. ./confine.functions




##########################################################################
#######  some general tools for convinience
##########################################################################


# The functions below can be used to selectively disable commands in dry run
# mode.  For instance:
#
#     # This would change system state, `vct_do` disables in dry run
#     # and reports the change.
#     vct_do touch /path/to/file
#     # This would then fail in dry run mode, `vct_true` succeeds.
#     if vct_true [ ! -f /path/to/file ]; then
#         echo "Failed to create /path/to/file." >&2
#         exit 1
#     fi
#
# The snippet above works as usual in normal mode.  The idiom `vct_true false
# || COMMAND` avoids running the whole COMMAND in dry run mode (useful for
# very complex commands).

# In dry run mode just exit successfully.
# Otherwise run argument(s) as a command and return result.
vct_true() {
    test "${VCT_DRY_RUN:-}" && return 0
    "$@"
}

# Same as `vct_true()`, run command in shell.
vct_true_sh() {
    vct_true sh -c "$@"
}

# In dry run mode print command to stderr and exit successfully.
# Otherwise run argument(s) as a command and return result.
vct_do() {
    if [ "${VCT_DRY_RUN:-}" ]; then
	echo ">>>>   $@   <<<<" >&2
	return 0
    fi

    "$@"
}

# Same as `vct_do()`, run command in shell.
vct_do_sh() {
    vct_do sh -c "$@"
}

# Same as `vct_do()`, run command with `sudo`.
vct_sudo() {
    if [ "${VCT_DRY_RUN:-}" ]; then
	vct_do sudo $@
	return $?
    fi

    local QUERY=

    if [ "$VCT_SUDO_ASK" != "NO" ]; then

	echo "" >&2
	echo "$0 wants to execute (VCT_SUDO_ASK=$VCT_SUDO_ASK set to ask):" >&2
	echo ">>>>   sudo $@   <<<<" >&2
	read -p "Pleas type: y) to execute and continue, s) to skip and continue, or anything else to abort: " QUERY >&2

	if [ "$QUERY" == "y" ] ; then
	    sudo $@
	    return $?

	elif [ "$QUERY" == "s" ] ; then

	    return 0
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
    variable_check VCT_RPM_PACKAGES    quiet
    variable_check VCT_USER            quiet
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




vct_tinc_setup() {

    vct_do mkdir -p $VCT_TINC_DIR
    vct_do rm -rf $VCT_TINC_DIR/* 
    vct_do mkdir -p $VCT_TINC_DIR/confine/hosts

    vct_do_sh "cat <<EOF > $VCT_TINC_DIR/confine/tinc.conf
BindToAddress = $VCT_SERVER_TINC_IP
Port = $VCT_SERVER_TINC_PORT
Name = server
StrictSubnets = yes
EOF
"

    vct_do_sh "cat <<EOF > $VCT_TINC_DIR/confine/hosts/server
Address = $VCT_SERVER_TINC_IP
Port = $VCT_SERVER_TINC_PORT
Subnet = $VCT_TESTBED_MGMT_IPV6_PREFIX48:0:0:0:0:2/128
EOF
"
    
    #vct_do tincd -c $VCT_TINC_DIR/confine  -K
    vct_do_sh "cat $VCT_KEYS_DIR/tinc/rsa_key.pub >> $VCT_TINC_DIR/confine/hosts/server"
    vct_do ln -s $VCT_KEYS_DIR/tinc/rsa_key.priv $VCT_TINC_DIR/confine/rsa_key.priv

    vct_do_sh "cat <<EOF > $VCT_TINC_DIR/confine/tinc-up
#!/bin/sh
ip -6 link set \\\$INTERFACE up mtu 1400
ip -6 addr add $VCT_TESTBED_MGMT_IPV6_PREFIX48:0:0:0:0:2/48 dev \\\$INTERFACE
EOF
"

    vct_do_sh "cat <<EOF > $VCT_TINC_DIR/confine/tinc-down
#!/bin/sh
ip -6 addr del $VCT_TESTBED_MGMT_IPV6_PREFIX48:0:0:0:0:2/48 dev \\\$INTERFACE
ip -6 link set \\\$INTERFACE down
EOF
"
    vct_do chmod a+rx $VCT_TINC_DIR/confine/tinc-{up,down}
    
}

vct_tinc_start() {
    echo "$FUNCNAME $@" >&2

    vct_sudo $VCT_TINC_CMD
}

vct_tinc_stop() {

    echo "$FUNCNAME $@" >&2

    local TINC_PID=$( ps aux | grep -e "$VCT_TINC_CMD" | grep -v grep | awk '{print $2}' )
    local TINC_CNT=0
    local TINC_MAX=20
    if [ "$TINC_PID" ] ; then 

	vct_sudo kill $TINC_PID

	echo -n "waiting till tinc cleaned up" >&2
	while [ $TINC_CNT -le $TINC_MAX ]; do
	    sleep 1
	    [ -x /proc/$TINC_PID ] || break
	    TINC_CNT=$(( TINC_CNT + 1 ))
	    echo -n "." >&2
	done
	
	echo  >&2
	echo  >&2
	[ -x /proc/$TINC_PID ] && vct_sudo kill -9 $TINC_PID && \
	    echo "Killing confine tincd the hard way" >&2
    fi
}

type_of_system() {
    if [ -f /etc/fedora-release ]; then
        echo "fedora"
    else
        echo "debian"
    fi
}

is_rpm() {
    local tos=$(type_of_system)
    case $tos in
        "fedora" | "redhat") true ;;
        *) false ;;
    esac
}

is_deb() {
    local tos=$(type_of_system)
    case $tos in
        "debian" | "ubuntu") true ;;
        *) false ;;
    esac
}

check_deb() {
    # check debian system, packages, tools, and kernel modules
    ! apt-get --version > /dev/null && dpkg --version > /dev/null &&\
	{ err $FUNCNAME "missing debian system tool dpkg or apt-get" $CMD_SOFT || return 1 ;}
    
    if ! [ $CMD_QUICK ]; then

	local PACKAGE=
	local UPDATED=

	for PACKAGE in $VCT_DEB_PACKAGES; do

	    if ! dpkg -s $PACKAGE 2>&1 |grep "Status:" |grep -v "not-installed" |grep "ok installed" > /dev/null ; then

		if [ $CMD_INSTALL ] ; then
		    echo "Missing debian package: $PACKAGE! Trying to install all required packets..." >&2 
		else
		    err $FUNCNAME "Missing debian packages $PACKAGE !!!" $CMD_SOFT || return 1
		fi

		if [ -z $UPDATED ] ; then
		    vct_sudo "apt-get update" && UPDATED=1
		fi

		vct_sudo "apt-get  --no-install-recommends install $PACKAGE" || \
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
}

check_rpm() {
    touch .rpm-installed.cache
    for PKG in $VCT_RPM_PACKAGES; do
        if [ "x$(grep "$PKG" .rpm-installed.cache)" != "x" ]; then
            echo "$PKG ok (cached)"
        else
            if [ "x$(yum info $PKG 2>&1 | grep 'No matching')" == "x" ]; then
                if [ "x$(yum info $PKG 2>/dev/null | grep installed)" == "x" ]; then
                    vct_sudo "yum install -y $PKG"
                else
                    echo "$PKG ok"
                    echo $PKG >> .rpm-installed.cache
                fi
            else
                echo "$PKG not available"
            fi
        fi
    done
}

vct_system_install_check() {

    #echo $FUNCNAME $@ >&2

    local OPT_CMD=${1:-}
    local CMD_SOFT=$(    echo "$OPT_CMD" | grep -e "soft" > /dev/null && echo "soft," )
    local CMD_QUICK=$(   echo "$OPT_CMD" | grep -e "quick" > /dev/null && echo "quick," )
    local CMD_INSTALL=$( echo "$OPT_CMD" | grep -e "install" > /dev/null && echo "install," )
    local UPD_SERVER=$(  echo "$OPT_CMD" | grep -e "server" > /dev/null && echo "update," )
    local UPD_NODE=$(    echo "$OPT_CMD" | grep -e "node" > /dev/null && echo "update," )
    local UPD_KEYS=$(    echo "$OPT_CMD" | grep -e "keys" > /dev/null && echo "update," )

    # check if correct user:
    if [ $(whoami) != $VCT_USER ] || [ $(whoami) = root ] ;then
	err $FUNCNAME "command must be executed as user=$VCT_USER" $CMD_SOFT || return 1
    fi

    if ! [ -d $VCT_VIRT_DIR ]; then
	( [ $CMD_INSTALL ] && vct_sudo mkdir -p $VCT_VIRT_DIR ) && vct_sudo chown $VCT_USER: $VCT_VIRT_DIR ||\
	 { err $FUNCNAME "$VCT_VIRT_DIR not existing" $CMD_SOFT || return 1 ;}
    fi

    for dir in "$VCT_SYS_DIR" "$VCT_DL_DIR" "$VCT_RPC_DIR" "$VCT_MNT_DIR" "$VCT_UCI_DIR"; do 
        if ! [ -d $dir ]; then
	    ( [ $CMD_INSTALL ] && vct_do mkdir -p $dir) ||\
	     { err $FUNCNAME "$dir not existing" $CMD_SOFT || return 1 ;}
        fi
    done
    
    if [ is_rpm ]; then
        check_rpm
    else
        check_deb
    fi

    # check uci binary
    local UCI_URL="http://distro.confine-project.eu/misc/uci.tgz"

    local UCI_INSTALL_DIR="/usr/local/bin"
    local UCI_INSTALL_PATH="/usr/local/bin/uci"

    if ! uci help 2>/dev/null && [ "$CMD_INSTALL" -a ! -f "$UCI_INSTALL_PATH" ] ; then
	    [ -f $VCT_DL_DIR/uci.tgz ] && vct_sudo "rm -f $VCT_DL_DIR/uci.tgz"
	    [ -f $UCI_INSTALL_PATH ]  && vct_sudo "rm -f $UCI_INSTALL_PATH"
	    if ! vct_do wget -O $VCT_DL_DIR/uci.tgz $UCI_URL || \
	        ! vct_sudo "tar xzf $VCT_DL_DIR/uci.tgz -C $UCI_INSTALL_DIR" || \
	        ! vct_true $UCI_INSTALL_PATH help 2>/dev/null ; then

	        err $FUNCNAME "Failed installing statically linked uci binary to $UCI_INSTALL_PATH "
	    fi
    fi



    if ! vct_true uci help 2>/dev/null; then

	cat <<EOF >&2
uci (unified configuration interface) tool is required for
this command (see: wiki.openwrt.org/doc/uci ).
Unfortunately, there is no debian package available for uci.
Please install uci manually using sources from here:
http://downloads.openwrt.org/sources/uci-0.7.5.tar.gz

Alternatively you can run
$0 install
to download and install a statically linked uci binary.
EOF

	err $FUNCNAME "uci binary not available" $CMD_SOFT

    fi

    if is_deb; then
        # check if user is in libvirt groups:
        local VCT_VIRT_GROUP=$( cat /etc/group | grep libvirt | awk -F':' '{print $1}' )
        if [ "$VCT_VIRT_GROUP" ]; then
	    groups | grep "$VCT_VIRT_GROUP" > /dev/null || { \
	        err $FUNCNAME "user=$VCT_USER MUST be in groups: $VCT_VIRT_GROUP \n do: sudo adduser $VCT_USER $VCT_VIRT_GROUP and ReLogin!" $CMD_SOFT || return 1 ;}
        else
	    err $FUNCNAME "Failed detecting libvirt group" $CMD_SOFT || return 1
        fi
    fi



    # check ssh and tinc keys:

    if ! [ -d $VCT_KEYS_DIR ] && [ $CMD_INSTALL ] ; then 

	echo "Copying vct-default-keys to $VCT_KEYS_DIR. " >&2
	echo "Keys are INSECURE unless vct_system_install is called with override_keys directive !! " >&2

	vct_do cp -rv vct-default-keys  $VCT_KEYS_DIR

	vct_do chmod -R og-rwx $VCT_KEYS_DIR/*
	

	local QUERY=
	echo "Copy default public key: $VCT_KEYS_DIR/id_rsa.pub -> ../../files/etc/dropbear/authorized_keys" >&2
	read -p "(then please recompile your node images afterwards)? [Y|n]: " QUERY >&2
	[ "$QUERY" = "y" ]  || [ "$QUERY" = "Y" ] || [ "$QUERY" = "" ] && vct_do mkdir -p ../../files/etc/dropbear/ && \
	    vct_do cp -v $VCT_KEYS_DIR/id_rsa.pub ../../files/etc/dropbear/authorized_keys
    fi

    if [ -d $VCT_KEYS_DIR ] && [ $CMD_INSTALL ] && [ $UPD_KEYS ] ; then 

	echo "Backing up existing keys to $VCT_KEYS_DIR.old (just in case) " >&2

	[ -d $VCT_KEYS_DIR.old.old ] && vct_do rm -rf $VCT_KEYS_DIR.old.old
	[ -d $VCT_KEYS_DIR.old     ] && vct_do mv $VCT_KEYS_DIR.old $VCT_KEYS_DIR.old.old
	[ -d $VCT_KEYS_DIR         ] && vct_do mv $VCT_KEYS_DIR $VCT_KEYS_DIR.old
    fi

    if ! [ -d $VCT_KEYS_DIR ] &&  [ $CMD_INSTALL ] ; then

	vct_do mkdir -p $VCT_KEYS_DIR
	vct_do rm -rf $VCT_KEYS_DIR/* 
	vct_do mkdir -p $VCT_KEYS_DIR/tinc
	vct_do touch $VCT_KEYS_DIR/tinc/tinc.conf
	
	echo "Creating new tinc keys..." >&2
	vct_do_sh "tincd -c $VCT_KEYS_DIR/tinc -K <<EOF
$VCT_KEYS_DIR/tinc/rsa_key.priv
$VCT_KEYS_DIR/tinc/rsa_key.pub
EOF
"
	echo "Creating new ssh keys..." >&2
	vct_do ssh-keygen -f $VCT_KEYS_DIR/id_rsa
	
	
	local QUERY=
	echo "Copy new public key: $VCT_KEYS_DIR/id_rsa.pub -> ../../files/etc/dropbear/authorized_keys" >&2
	read -p "(then please recompile your node images afterwards)? [Y|n]: " QUERY >&2

	[ "$QUERY" = "y" ] || [ "$QUERY" = "" ] && vct_do mkdir -p ../../files/etc/dropbear/ && \
	    vct_do cp -v $VCT_KEYS_DIR/id_rsa.pub ../../files/etc/dropbear/authorized_keys

    fi

    [ -f $VCT_KEYS_DIR/tinc/rsa_key.priv ] && [ -f $VCT_KEYS_DIR/tinc/rsa_key.pub ] || \
	{ err $FUNCNAME "$VCT_KEYS_DIR/tinc/rsa_key.* not existing" $CMD_SOFT || return 1 ;}

    [ -f $VCT_KEYS_DIR/id_rsa ] &&  [ -f $VCT_KEYS_DIR/id_rsa.pub ] || \
	{ err $FUNCNAME "$VCT_KEYS_DIR/id_rsa not existing" $CMD_SOFT || return 1 ;}




    # check tinc configuration:

    [ $CMD_INSTALL ] && vct_do rm -rf $VCT_TINC_DIR

    if ! [ -d $VCT_TINC_DIR ] &&  [ $CMD_INSTALL ] ; then
	vct_tinc_setup
    fi

    [ -f $VCT_TINC_DIR/confine/hosts/server ] || \
	{ err $FUNCNAME "$VCT_TINC_DIR/confine/hosts/server not existing" $CMD_SOFT || return 1 ;}



    # check for update and downloadable file-system-template file:

    [ "$UPD_NODE" ] && vct_do rm -f $VCT_DL_DIR/${VCT_TEMPLATE_NAME}.${VCT_TEMPLATE_TYPE}.${VCT_TEMPLATE_COMP}

    if ! vct_do install_url $VCT_TEMPLATE_URL $VCT_TEMPLATE_SITE $VCT_TEMPLATE_NAME.$VCT_TEMPLATE_TYPE $VCT_TEMPLATE_COMP $VCT_DL_DIR 0 "${CMD_SOFT}${CMD_INSTALL}" ; then

	err $FUNCNAME "Installing ULR=$VCT_TEMPLATE_URL failed" $CMD_SOFT || return 1
    fi

}

vct_system_install() {
    vct_system_install_check "install,$@"
}




vct_system_init_check(){

    local OPT_CMD=${1:-}
    local CMD_SOFT=$(  echo "$OPT_CMD" | grep -e "soft" > /dev/null && echo "soft," )
    local CMD_QUICK=$( echo "$OPT_CMD" | grep -e "quick" > /dev/null && echo "quick," )
    local CMD_INIT=$(  echo "$OPT_CMD" | grep -e "init" > /dev/null && echo "init," )

    vct_system_install_check $CMD_SOFT$CMD_QUICK

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
	if BR_NAME=$( variable_check ${BRIDGE}_NAME soft 2>/dev/null ); then

            # check if bridge exist:
	    if ! brctl show | grep $BR_NAME >/dev/null; then
		( [ $CMD_INIT ]                &&\
		  vct_sudo "brctl addbr $BR_NAME && brctl setfd $BR_NAME 0 && brctl sethello $BR_NAME 1 && brctl stp $BR_NAME off" ) ||\
                	{ err $FUNCNAME "unconfigured bridge $BR_NAME" $CMD_SOFT || return 1 ;}
	    fi

	    local BR_DUMMY_DEV=$( variable_check ${BRIDGE}_DUMMY_DEV soft 2>/dev/null ) 
	    if [ $BR_DUMMY_DEV ] ; then

		if ! ip link show dev $BR_DUMMY_DEV >/dev/null 2>&1 ; then
		    vct_sudo ip link add $BR_DUMMY_DEV type dummy || \
			{ err $FUNCNAME "Failed adding $BR_DUMMY_DEV" $CMD_SOFT || return 1 ;}
		fi


		if ! brctl show | grep $BR_NAME | grep $BR_DUMMY_DEV >/dev/null; then
		    ( [ $CMD_INIT ] && \
			vct_sudo "brctl addif $BR_NAME $BR_DUMMY_DEV" ) || \
                	{ err $FUNCNAME "bridge $BR_NAME: $BR_DUMMY_DEV NOT first dev " $CMD_SOFT || return 1 ;}
		fi
	    fi

            # check if local bridge has rescue IPv4 address for local network: 
	    local BR_V4_RESCUE_IP=$( variable_check ${BRIDGE}_V4_RESCUE_IP soft 2>/dev/null ) 
	    if [ $BR_V4_RESCUE_IP ] ; then
		if ! ip addr show dev $BR_NAME | grep -e "inet " |grep -e " $BR_V4_RESCUE_IP " |grep -e " $BR_NAME" >/dev/null; then
		    ( [ $CMD_INIT ] && vct_sudo ip addr add $BR_V4_RESCUE_IP dev $BR_NAME label $BR_NAME:resc) ||\
                	{ err $FUNCNAME "unconfigured ipv4 rescue net: $BR_NAME  $BR_V4_RESCUE_IP " $CMD_SOFT || return 1 ;}
		fi
	    fi

            # check if local bridge has IPv4 address for local network: 
	    local BR_V4_LOCAL_IP=$( variable_check ${BRIDGE}_V4_LOCAL_IP soft 2>/dev/null ) 
	    if [ $BR_V4_LOCAL_IP ] ; then
		if ! ip addr show dev $BR_NAME | grep -e "inet " |grep -e " $BR_V4_LOCAL_IP " |grep -e " $BR_NAME" >/dev/null; then
		    ( [ $CMD_INIT ] && vct_sudo ip addr add $BR_V4_LOCAL_IP dev $BR_NAME ) ||\
                	{ err $FUNCNAME "unconfigured ipv4 rescue net: $BR_NAME  $BR_V4_LOCAL_IP " $CMD_SOFT || return 1 ;}
		fi

            # check if bridge needs routed NAT:
		local BR_V4_NAT_OUT=$( variable_check ${BRIDGE}_V4_NAT_OUT_DEV soft 2>/dev/null )
		local BR_V4_NAT_SRC=$( variable_check ${BRIDGE}_V4_NAT_OUT_SRC soft 2>/dev/null )
		
		if [ "$BR_V4_NAT_OUT" = "auto" ] ; then
		    BR_V4_NAT_OUT=$( ip -4 r |grep -e "^default" |awk -F'dev ' '{print $2}' |awk '{print $1}' ) && \
			ip link show dev $BR_V4_NAT_OUT >/dev/null || \
			err $FUNCNAME "default route dev can not be resolved"
		fi


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
		local UDHCPD_COMMAND
		if is_rpm; then
    		UDHCPD_COMMAND="busybox udhcpd $UDHCPD_CONF_FILE"
    	else
    	    UDHCPD_COMMAND="udhcpd $UDHCPD_CONF_FILE"
    	fi
    	echo $UDHCPD_COMMAND;
		local UDHCPD_PID=$( ps aux | grep "$UDHCPD_COMMAND" | grep -v grep | awk '{print $2}' )
	    
		[ $CMD_INIT ] && [ ${UDHCPD_PID:-} ] && vct_sudo kill $UDHCPD_PID && sleep 1
		

		if [ $DHCPD_IP_MIN ] && [ $DHCPD_IP_MAX ] && [ $DHCPD_DNS ]; then
		    if [ $CMD_INIT ] ; then
			vct_do_sh "cat <<EOF > $UDHCPD_CONF_FILE
start           $DHCPD_IP_MIN
end             $DHCPD_IP_MAX
interface       $BR_NAME 
lease_file      $UDHCPD_LEASE_FILE
option router   $( echo $BR_V4_LOCAL_IP | awk -F'/' '{print $1}' )
option dns      $DHCPD_DNS
EOF
"

            vct_sudo $UDHCPD_COMMAND
		    fi
		    
		    vct_true [ "$(ps aux | grep "$UDHCPD_COMMAND" | grep -v grep )" ] || \
			err $FUNCNAME "NO udhcpd server running for $BR_NAME "
		fi
	    fi

            # check if local bridge has IPv6 for recovery network:
	    local BR_V6_RESCUE2_PREFIX64=$( variable_check ${BRIDGE}_V6_RESCUE2_PREFIX64 soft 2>/dev/null ) 
	    if [ $BR_V6_RESCUE2_PREFIX64 ] ; then
		local BR_V6_RESCUE2_IP=$BR_V6_RESCUE2_PREFIX64:$( vct_true eui64_from_link $BR_NAME )/64
		if vct_true false || ! ip addr show dev $BR_NAME | grep -e "inet6 " | \
		    grep -ie " $( ipv6calc -I ipv6 $BR_V6_RESCUE2_IP -O ipv6 ) " >/dev/null; then
		    ( [ $CMD_INIT ] && vct_sudo ip addr add $BR_V6_RESCUE2_IP dev $BR_NAME ) ||\
                	{ err $FUNCNAME "unconfigured ipv6 rescue net: $BR_NAME $BR_V6_RESCUE2_IP" $CMD_SOFT || return 1 ;}
		fi
	    fi

            # check if local bridge has IPv6 for debug network:
	    local BR_V6_DEBUG_IP=$( variable_check ${BRIDGE}_V6_DEBUG_IP soft 2>/dev/null ) 
	    if [ $BR_V6_DEBUG_IP ] ; then
		if ! ip addr show dev $BR_NAME | grep -e "inet6 " | \
		    grep -ie " $( ipv6calc -I ipv6 $BR_V6_DEBUG_IP -O ipv6 ) " >/dev/null; then
		    ( [ $CMD_INIT ] && vct_sudo ip addr add $BR_V6_DEBUG_IP dev $BR_NAME ) ||\
                	{ err $FUNCNAME "unconfigured ipv6 rescue net: $BR_NAME $BR_V6_DEBUG_IP" $CMD_SOFT || return 1 ;}
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

    # check if tinc management network is running:
    [ $CMD_INIT ] && vct_tinc_stop
    [ $CMD_INIT ] && vct_tinc_start
}


vct_system_init() {
    vct_system_init_check init
}


vct_system_cleanup() {

    local VCRD_ID=
    for VCRD_ID in $( vct_node_info | grep -e "$VCT_RD_NAME_PREFIX" | awk '{print $2}' | awk -F"$VCT_RD_NAME_PREFIX" '{print $2}' ); do
	vct_do vct_node_remove $VCRD_ID
    done

    vct_do vct_slice_attributes flush all

    local BRIDGE=
    local BR_NAME=
    for BRIDGE in $VCT_BRIDGE_PREFIXES; do

	if BR_NAME=$( variable_check ${BRIDGE}_NAME soft 2>/dev/null ); then

            # check if local bridge has IPv4 address for local network: 
	    local BR_V4_LOCAL_IP=$( variable_check ${BRIDGE}_V4_LOCAL_IP soft 2>/dev/null ) 
	    if [ "$BR_V4_LOCAL_IP" ] ; then

            # check if bridge had routed NAT:
		local BR_V4_NAT_OUT=$( variable_check ${BRIDGE}_V4_NAT_OUT_DEV soft 2>/dev/null )
		local BR_V4_NAT_SRC=$( variable_check ${BRIDGE}_V4_NAT_OUT_SRC soft 2>/dev/null )
		
		if [ "$BR_V4_NAT_OUT" = "auto" ] ; then
		    BR_V4_NAT_OUT=$( ip -4 r |grep -e "^default" |awk -F'dev ' '{print $2}' |awk '{print $1}' ) && \
			ip link show dev $BR_V4_NAT_OUT >/dev/null || \
			err $FUNCNAME "default route dev can not be resolved"
		fi
		
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
		local UDHCPD_PID=$( ps aux | grep -e "$UDHCPD_COMMAND" | grep -v "grep" | awk '{print $2}' )
	    
		[ ${UDHCPD_PID:-} ] && vct_sudo kill $UDHCPD_PID
		
	    fi

            # check if bridge is UP:
	    if ip link show dev $BR_NAME | grep -e ',UP' >/dev/null; then
		vct_sudo ip link set dev $BR_NAME down
	    fi

            # check if bridge exist:
	    if brctl show | grep -e "$BR_NAME" >/dev/null; then
		  vct_sudo brctl delbr $BR_NAME
	    fi

            # check if bridge had a dummy device:
	    local BR_DUMMY_DEV=$( variable_check ${BRIDGE}_DUMMY_DEV soft 2>/dev/null )
	    if [ $BR_DUMMY_DEV ] ; then
		if ip link show dev $BR_DUMMY_DEV >/dev/null 2>&1 ; then
		    vct_sudo ip link del $BR_DUMMY_DEV || \
			{ err $FUNCNAME "Failed deleting $BR_DUMMY_DEV" $CMD_SOFT || return 1 ;}
		fi
	    fi

	fi
    done

    vct_tinc_stop
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


	local VCRD_NAME=

	for VCRD_NAME in $( virsh -c qemu:///system list --all 2>/dev/null  | grep ${VCRD_ID} | awk '{print $2}' ) ; do

	    echo removing id=$VCRD_ID name=$VCRD_NAME

	    if [ "$VCRD_NAME" ]; then

		vct_node_unmount $VCRD_ID

		local VCRD_PATH=$( virsh -c qemu:///system dumpxml $VCRD_NAME | \
		    xmlstarlet sel -T -t -m "/domain/devices/disk/source" -v attribute::file -n |
		    grep -e "^${VCT_SYS_DIR}" || \
			err $FUNCNAME "Failed resolving disk path for $VCRD_NAME" soft ) 

		if virsh -c qemu:///system dominfo $VCRD_NAME  2>/dev/null | grep -e "^State:" | grep "running" >/dev/null ; then
		    virsh -c qemu:///system destroy $VCRD_NAME ||\
	    err $FUNCNAME "Failed stopping domain $VCRD_NAME"
		fi

		if virsh -c qemu:///system dominfo $VCRD_NAME  2>/dev/null | grep -e "^State:" | grep "off" >/dev/null ; then
		    virsh -c qemu:///system undefine $VCRD_NAME ||\
	    err $FUNCNAME "Failed undefining domain $VCRD_NAME"
		fi
		
		[ $VCRD_PATH ] && [ -f $VCRD_PATH ] && rm -f $VCRD_PATH

	    else
		err $FUNCNAME "No system with rd-id=$VCRD_ID $VCRD_NAME found"

	    fi
	done
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

	    if BR_NAME=$( variable_check ${BRIDGE}_NAME soft 2>/dev/null ); then

		local BR_MODEL=$( variable_check ${BRIDGE}_MODEL soft 2>/dev/null ) 
		local BR_MAC48=$( variable_check ${BRIDGE}_MAC48 soft 2>/dev/null || \
		    echo "${VCT_INTERFACE_MAC24}:$( echo ${BRIDGE:6:7} ):${VCRD_ID:0:2}:${VCRD_ID:2:3}" ) 
		local BR_VNET="vct-rd${VCRD_ID}-br$( echo ${BRIDGE:6:7} )"

		VCRD_NETW="${VCRD_NETW}  --network bridge=${BR_NAME}"
		[ "$BR_MODEL" ] && VCRD_NETW="${VCRD_NETW},model=${BR_MODEL}"
		[ "$BR_MAC48" != "RANDOM" ] && VCRD_NETW="${VCRD_NETW},mac=${BR_MAC48}"

	    fi

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
	local VCRD_PATH=$( virsh -c qemu:///system dumpxml $VCRD_NAME | \
	    xmlstarlet sel -T -t -m "/domain/devices/disk/source" -v attribute::file -n |
	    grep -e "^${VCT_SYS_DIR}" || \
		err $FUNCNAME "Failed resolving disk path for $VCRD_NAME" )

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


vct_node_ssh() {


    local VCRD_ID_RANGE=$1
    local COMMAND=${2:-}
    local VCRD_ID=

    shift

    for VCRD_ID in $( vcrd_ids_get $VCRD_ID_RANGE ); do

	local MAC=

	[ -f $VCT_NODE_MAC_DB  ] && \
	    MAC=$( grep -e "^$VCRD_ID " $VCT_NODE_MAC_DB | awk '{print $2}' )

	if  [ $MAC ]  ; then

	    echo $FUNCNAME "connecting to real node=$VCRD_ID mac=$MAC" >&2

	else

	    echo $FUNCNAME "connecting to virtual node=$VCRD_ID mac=$MAC" >&2

	    local VCRD_NAME="${VCT_RD_NAME_PREFIX}${VCRD_ID}"

	    if ! virsh -c qemu:///system dominfo $VCRD_NAME | grep -e "^State:" | grep "running" >/dev/null; then
		err $FUNCNAME "$VCRD_NAME not running"
	    fi

	    MAC=$( virsh -c qemu:///system dumpxml $VCRD_NAME | \
		xmlstarlet sel -T -t -m "/domain/devices/interface" \
		-v child::source/attribute::* -o " " -v child::mac/attribute::address -n | \
		grep -e "^$VCT_RD_LOCAL_BRIDGE " | awk '{print $2 }' || \
		err $FUNCNAME "Failed resolving MAC address for $VCRD_NAME $VCT_RD_LOCAL_BRIDGE" )
	fi


	local IPV6=${VCT_BR00_V6_RESCUE2_PREFIX64}:$( eui64_from_mac $MAC )
	local COUNT=0
	local COUNT_MAX=60

	while [ "$COUNT" -le $COUNT_MAX ]; do 

	    ping6 -c 1 -w 1 -W 1 $IPV6 > /dev/null && \
		break
	    
	    [ "$COUNT" = 0 ] && \
		echo -n "Waiting for $VCRD_ID to listen on $IPV6 (frstboot may take upto 40 secs)" || \
		echo -n "."

	    COUNT=$(( $COUNT + 1 ))
	done

	[ "$COUNT" = 0 ] || \
	    echo

	[ "$COUNT" -le $COUNT_MAX ] || \
	    err $FUNCNAME "Failed connecting to node=$VCRD_ID via $IPV6"
	


	echo > $VCT_KEYS_DIR/known_hosts

	if [ "$COMMAND" ]; then
	    ssh $VCT_SSH_OPTIONS root@$IPV6 ". /etc/profile > /dev/null; $@"
	else
	    ssh $VCT_SSH_OPTIONS root@$IPV6
	fi

    done
}

vct_node_scp() {

    local VCRD_ID_RANGE=$1
    local VCRD_ID=

    shift
    local WHAT="$@"

    for VCRD_ID in $( vcrd_ids_get $VCRD_ID_RANGE ); do

	local MAC=

	[ -f $VCT_NODE_MAC_DB  ] && \
	    MAC=$( grep -e "^$VCRD_ID " $VCT_NODE_MAC_DB | awk '{print $2}' )

	if  [ $MAC ]  ; then

	    echo $FUNCNAME "connecting to real node=$VCRD_ID mac=$MAC" >&2

	else

	    local VCRD_NAME="${VCT_RD_NAME_PREFIX}${VCRD_ID}"

	    if ! virsh -c qemu:///system dominfo $VCRD_NAME | grep -e "^State:" | grep "running" >/dev/null; then
		err $FUNCNAME "$VCRD_NAME not running"
	    fi

	    local MAC=$( virsh -c qemu:///system dumpxml $VCRD_NAME | \
		xmlstarlet sel -T -t -m "/domain/devices/interface" \
		-v child::source/attribute::* -o " " -v child::mac/attribute::address -n | \
		grep -e "^$VCT_RD_LOCAL_BRIDGE " | awk '{print $2 }' || \
		err $FUNCNAME "Failed resolving MAC address for $VCRD_NAME $VCT_RD_LOCAL_BRIDGE" )
	fi


	local IPV6=${VCT_BR00_V6_RESCUE2_PREFIX64}:$( eui64_from_mac $MAC )
	local COUNT=0
	local COUNT_MAX=60

	while [ "$COUNT" -le $COUNT_MAX ]; do 

	    ping6 -c 1 -w 1 -W 1 $IPV6 > /dev/null && \
		break
	    
	    [ "$COUNT" = 0 ] && \
		echo -n "Waiting for $VCRD_ID to listen on $IPV6 (frstboot may take upto 40 secs)" || \
		echo -n "."

	    COUNT=$(( $COUNT + 1 ))
	done

	[ "$COUNT" = 0 ] || \
	    echo

	[ "$COUNT" -le $COUNT_MAX ] || \
	    err $FUNCNAME "Failed connecting to node=$VCRD_ID via $IPV6"


	echo > $VCT_KEYS_DIR/known_hosts

	scp $VCT_SSH_OPTIONS $( echo $WHAT | sed s/remote:/root@\[$IPV6\]:/ )

    done
}




vct_node_mount() {

    local VCRD_ID_RANGE=$1
    local VCRD_ID=

    for VCRD_ID in $( vcrd_ids_get $VCRD_ID_RANGE ); do

	local VCRD_NAME="${VCT_RD_NAME_PREFIX}${VCRD_ID}"    
	local VCRD_PATH=$( virsh -c qemu:///system dumpxml $VCRD_NAME | \
	    xmlstarlet sel -T -t -m "/domain/devices/disk/source" -v attribute::file -n |
	    grep -e "^${VCT_SYS_DIR}" || \
		err $FUNCNAME "Failed resolving disk path for $VCRD_NAME" )
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
	    
	    vct_sudo mount -o loop,rw,offset=$(( $IMG_UNIT_SIZE * $IMG_ROOTFS_START )) $VCRD_PATH $VCRD_MNTP || \
		err $FUNCNAME "Failed mounting $VCRD_PATH"

	    echo $VCRD_MNTP

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
	local VCRD_MNTP=$VCT_MNT_DIR/$VCRD_NAME

	if  mount | grep "$VCRD_MNTP" >/dev/null ; then

	    vct_sudo umount $VCRD_MNTP || \
		err $FUNCNAME "Failed unmounting $VCRD_MNTP"

	    rmdir $VCRD_MNTP
	fi
    done
}

vct_node_customize() {

    echo "$FUNCNAME $# $@" >&2

    local VCRD_ID_RANGE=$1
    local PROCEDURE=${2:-online}
    local VCRD_ID=


    case "$PROCEDURE" in
	offline|online|sysupgrade) ;;
	*) err $FUNCNAME "Invalid customization procedure" ;;
    esac

    for VCRD_ID in $( vcrd_ids_get $VCRD_ID_RANGE ); do

	local VCRD_NAME="${VCT_RD_NAME_PREFIX}${VCRD_ID}"
	local PREP_ROOT=$VCT_VIRT_DIR/node_prepare/$VCRD_NAME-$( date +%Y%m%d-%H%M%S )-$BASHPID
	local PREP_UCI=$PREP_ROOT/etc/config

	    rm -rf $PREP_ROOT
	    mkdir -p $PREP_UCI

	if [ "$PROCEDURE" = "offline" ] ; then

	    local MNTP=$VCT_MNT_DIR/$VCRD_NAME
	    local MUCI=$MNTP/etc/config

	    mount | grep $MNTP >/dev/null || \
		vct_node_mount $VCRD_ID

	    cp $MUCI/confine* $PREP_UCI/

	elif [ "$PROCEDURE" = "online" ] ; then

	    if ! ( [ -f $VCT_NODE_MAC_DB  ] &&  grep -e "^$VCRD_ID" $VCT_NODE_MAC_DB >/dev/null ); then
		if ! virsh -c qemu:///system dominfo $VCRD_NAME | grep -e "^State:" | grep "running" >/dev/null; then
		    err $FUNCNAME "$VCRD_NAME not running" 
		fi
	    fi

	    vct_node_ssh $VCRD_ID "confine_node_disable"
	    vct_node_scp $VCRD_ID remote:/etc/config/confine* $PREP_UCI/

	elif [ "$PROCEDURE" = "sysupgrade" ] ; then

	    err $FUNCNAME "Not yet supported"

	fi

 	uci changes -c $PREP_UCI | grep -e "^confine" > /dev/null && \
	    err $FUNCNAME "confine configs dirty! Please commit or revert"

	touch $PREP_UCI/confine-defaults
	uci_set confine-defaults.defaults=defaults                                               path=$PREP_UCI
	uci_set confine-defaults.defaults.priv_ipv6_prefix48=$VCT_CONFINE_PRIV_IPV6_PREFIX48     path=$PREP_UCI
	uci_set confine-defaults.defaults.debug_ipv6_prefix48=$VCT_CONFINE_DEBUG_IPV6_PREFIX48   path=$PREP_UCI

	touch $PREP_UCI/confine
	uci_set confine.testbed=testbed                                                          path=$PREP_UCI
	uci_set confine.testbed.mgmt_ipv6_prefix48=$VCT_TESTBED_MGMT_IPV6_PREFIX48               path=$PREP_UCI
	uci_set confine.testbed.mac_dflt_prefix16=$VCT_TESTBED_MAC_PREFIX16                      path=$PREP_UCI
	uci_set confine.testbed.priv_dflt_ipv4_prefix24=$VCT_TESTBED_PRIV_IPV4_PREFIX24          path=$PREP_UCI

	uci_set confine.server=server                                                            path=$PREP_UCI
	uci_set confine.server.cn_url=$VCT_SERVER_CN_URL                                         path=$PREP_UCI
	uci_set confine.server.mgmt_pubkey="$( cat $VCT_KEYS_DIR/id_rsa.pub )"                   path=$PREP_UCI
	uci_set confine.server.tinc_ip=$VCT_SERVER_TINC_IP                                       path=$PREP_UCI
	uci_set confine.server.tinc_port=$VCT_SERVER_TINC_PORT                                   path=$PREP_UCI
	uci_set confine.server.tinc_pubkey="$( ssh-keygen -yf $VCT_KEYS_DIR/tinc/rsa_key.priv )" path=$PREP_UCI

	uci_set confine.node=node                                                                path=$PREP_UCI
	uci_set confine.node.id=$VCRD_ID                                                         path=$PREP_UCI
#       uci_set confine.node.rd_pubkey=""                                                        path=$PREP_UCI
	uci_set confine.node.cn_url=$( echo $VCT_NODE_CN_URL | sed s/NODE_ID/$VCRD_ID/ )         path=$PREP_UCI
	uci_set confine.node.mac_prefix16=$VCT_TESTBED_MAC_PREFIX16                              path=$PREP_UCI
	uci_set confine.node.priv_ipv4_prefix24=$VCT_TESTBED_PRIV_IPV4_PREFIX24                  path=$PREP_UCI

	uci_set confine.node.public_ipv4_avail=$VCT_NODE_PUBLIC_IPV4_AVAIL                       path=$PREP_UCI
	uci_set confine.node.rd_public_ipv4_proto=$VCT_NODE_RD_PUBLIC_IPV4_PROTO                 path=$PREP_UCI
	if [ "$VCT_NODE_RD_PUBLIC_IPV4_PROTO" = "static" ] && [ "$VCT_NODE_PUBLIC_IPV4_PREFIX16" ] ; then
	    uci_set confine.node.rd_public_ipv4=$( \
		echo $VCT_NODE_PUBLIC_IPV4_PREFIX16.$(( 16#${VCRD_ID:2:2} )).1/$VCT_NODE_PUBLIC_IPV4_PL ) path=$PREP_UCI
	    uci_set confine.node.rd_public_ipv4_gw=$VCT_NODE_PUBLIC_IPV4_GW                      path=$PREP_UCI
	    uci_set confine.node.rd_public_ipv4_dns=$VCT_NODE_PUBLIC_IPV4_DNS                    path=$PREP_UCI
	fi


	uci_set confine.node.sl_public_ipv4_proto=$VCT_NODE_SL_PUBLIC_IPV4_PROTO                 path=$PREP_UCI
	if [ "$VCT_NODE_SL_PUBLIC_IPV4_PROTO" = "static" ] && [ "$VCT_NODE_PUBLIC_IPV4_PREFIX16" ] ; then
	    uci_set confine.node.sl_public_ipv4_addrs="$( echo $( \
	    for i in $( seq 2 $VCT_NODE_PUBLIC_IPV4_AVAIL ); do \
	    echo $VCT_NODE_PUBLIC_IPV4_PREFIX16.$(( 16#${VCRD_ID:2:2} )).$i/$VCT_NODE_PUBLIC_IPV4_PL; \
	    done ) )"                                                                            path=$PREP_UCI
	    uci_set confine.node.sl_public_ipv4_gw=$VCT_NODE_PUBLIC_IPV4_GW                      path=$PREP_UCI
	    uci_set confine.node.sl_public_ipv4_dns=$VCT_NODE_PUBLIC_IPV4_DNS                    path=$PREP_UCI

	fi

	uci_set confine.node.rd_if_iso_parents="$VCT_NODE_ISOLATED_PARENTS"                  path=$PREP_UCI
	uci_set confine.node.state=prepared                                                  path=$PREP_UCI


	if [ "$PROCEDURE" = "offline" ] ; then

	    vct_sudo "cp -r $PREP_ROOT/* $MNTP/"
	    vct_node_unmount $VCRD_ID

	elif [ "$PROCEDURE" = "online" ] ; then

	    vct_node_scp $VCRD_ID -r $PREP_ROOT/* remote:/
	    vct_node_ssh $VCRD_ID "confine_node_enable"
	    vct_node_scp $VCRD_ID remote:/etc/tinc/confine/hosts/node_x$VCRD_ID $VCT_TINC_DIR/confine/hosts/

	elif [ "$PROCEDURE" = "sysupgrade" ] ; then

	    err $FUNCNAME ""

	fi


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
		uci_del $VCT_SLICE_DB.$SLIVER_ID soft
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

#    vct_slice_attributes update $SLICE_ID

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


	if ! ( [ -f $VCT_NODE_MAC_DB  ] &&  grep -e "^$VCRD_ID" $VCT_NODE_MAC_DB >/dev/null ); then
	    if ! virsh -c qemu:///system dominfo $VCRD_NAME | grep -e "^State:" | grep "running" >/dev/null ; then
		err $FUNCNAME "$VCRD_NAME not running"
	    fi
	fi

	if [ "$OS_TYPE" = "debian" ]; then
            cat <<EOF > ${VCT_RPC_DIR}/${RPC_REQUEST}
config sliver $SLICE_ID
    option user_pubkey     "$( cat $VCT_KEYS_DIR/id_rsa.pub )"
    option fs_template_url "$VCT_EXPERIMENT_DEBIAN_FS_URL"
    option exp_data_url    "$VCT_EXPERIMENT_DEBIAN_DATA_URL"
    option exp_name        "$VCT_EXPERIMENT_DEBIAN_NAME"
    option vlan_nr         "f${SLICE_ID:10:2}"    # mandatory for if-types isolated
    option if00_type       internal 
    option if00_name       priv 
    option if01_type       public   # optional
    option if01_name       pub0
    option if01_ipv4_proto $VCT_NODE_SL_PUBLIC_IPV4_PROTO   # mandatory for if-type public
    option if02_type       isolated # optional
    option if02_name       iso0
    option if02_parent     eth1     # mandatory for if-types isolated
EOF
	else
	    cat <<EOF > ${VCT_RPC_DIR}/${RPC_REQUEST}
config sliver $SLICE_ID
    option user_pubkey     "$( cat $VCT_KEYS_DIR/id_rsa.pub )"
    option fs_template_url "$VCT_EXPERIMENT_OPENWRT_FS_URL"
    option exp_data_url    "$VCT_EXPERIMENT_OPENWRT_DATA_URL"
    option exp_name        "$VCT_EXPERIMENT_OPENWRT_NAME"
    option vlan_nr         "f${SLICE_ID:10:2}"    # mandatory for if-types isolated
    option if00_type       internal 
    option if00_name       priv 
    option if01_type       public   # optional
    option if01_name       pub0
    option if01_ipv4_proto $VCT_NODE_SL_PUBLIC_IPV4_PROTO   # mandatory for if-type public
#    option if02_type       isolated # optional
#    option if02_name       iso0
#    option if02_parent     eth1     # mandatory for if-types isolated
#    option if03_type       isolated # optional
#    option if03_name       iso1
#    option if03_parent     wlan0     # mandatory for if-types isolated
#    option if04_type       isolated # optional
#    option if04_name       iso2
#    option if04_parent     wlan1     # mandatory for if-types isolated
EOF
	fi

	echo "# >>>> Input stream begin >>>>" >&1
	cat $VCT_RPC_DIR/$RPC_REQUEST         >&1
	echo "# <<<< Input stream end <<<<<<" >&1

	cat $VCT_RPC_DIR/$RPC_REQUEST | \
	    vct_node_ssh $VCRD_ID "confine_sliver_allocate $SLICE_ID" > $VCT_RPC_DIR/$RPC_REPLY

	cat $VCT_RPC_DIR/$RPC_REPLY           >&1


	if [ "$( uci_get $RPC_REPLY.$SLICE_ID soft,quiet,path=$VCT_RPC_DIR )" = "sliver" ] ; then

	    uci_show $RPC_REPLY.$SLICE_ID path=$VCT_RPC_DIR | \
		sed s/$RPC_REPLY\.${SLICE_ID}/${VCT_SLICE_DB}.${SLICE_ID}_${VCRD_ID}/ | \
		uci_merge $VCT_SLICE_DB 

	fi
    done
}


vct_sliver_deploy() {

    local SLICE_ID=$1; check_slice_id $SLICE_ID quiet
    local VCRD_ID_RANGE=$2
    local VCRD_ID=

#    vct_slice_attributes update $SLICE_ID

    local SLICE_STATE=$( uci_get $VCT_SLICE_DB.$SLICE_ID.state soft,quiet )

    [ "$SLICE_STATE" = "allocated" ] ||
	err $FUNCNAME "SLICE_ID=$SLICE_ID not in allocated state"
    

    for VCRD_ID in $( vcrd_ids_get $VCRD_ID_RANGE ); do

	local VCRD_NAME="${VCT_RD_NAME_PREFIX}${VCRD_ID}"    
	local RPC_REQUEST="${VCRD_ID}-$( date +%Y%m%d_%H%M%S )-${SLICE_ID}-deploy-request"
	local RPC_REPLY="${VCRD_ID}-$( date +%Y%m%d_%H%M%S )-${SLICE_ID}-deploy-reply"

	if ! ( [ -f $VCT_NODE_MAC_DB  ] &&  grep -e "^$VCRD_ID" $VCT_NODE_MAC_DB >/dev/null ); then
	    if ! virsh -c qemu:///system dominfo $VCRD_NAME | grep -e "^State:" | grep "running" >/dev/null ; then
		err $FUNCNAME "$VCRD_NAME not running"
	    fi
	fi

	if [ "$( uci_get $VCT_SLICE_DB.${SLICE_ID}_${VCRD_ID}.state soft )" != "allocated" ] ; then
	    err $FUNCNAME "sliver=${SLICE_ID}_${VCRD_ID} not in allocated state" soft
	    continue
	fi


	uci_show $VCT_SLICE_DB | \
	    grep $VCT_SLICE_DB.${SLICE_ID}_ | \
	    grep -v '.state=' | \
	    uci_dot_to_file $VCT_SLICE_DB > ${VCT_RPC_DIR}/${RPC_REQUEST}

	echo "# >>>> Input stream begin >>>>" >&1
	cat $VCT_RPC_DIR/$RPC_REQUEST         >&1
	echo "# <<<< Input stream end <<<<<<" >&1

	cat ${VCT_RPC_DIR}/${RPC_REQUEST} | \
	    vct_node_ssh $VCRD_ID "confine.lib confine_sliver_deploy $SLICE_ID" > ${VCT_RPC_DIR}/${RPC_REPLY}

	cat ${VCT_RPC_DIR}/${RPC_REPLY}       >&1

	if [ "$( uci_get $RPC_REPLY.$SLICE_ID soft,quiet,path=$VCT_RPC_DIR )" = "sliver" ] ; then

	    uci_show $RPC_REPLY.$SLICE_ID path=$VCT_RPC_DIR | \
		sed s/$RPC_REPLY\.${SLICE_ID}/${VCT_SLICE_DB}.${SLICE_ID}_${VCRD_ID}/ | \
		uci_merge $VCT_SLICE_DB 
	fi
    done
}







vct_sliver_start() {

    local SLICE_ID=$1; check_slice_id $SLICE_ID quiet
    local VCRD_ID_RANGE=$2

#    vct_slice_attributes update $SLICE_ID

    local SLICE_STATE=$( uci_get $VCT_SLICE_DB.$SLICE_ID.state soft,quiet )

    [ "$SLICE_STATE" = "deployed" ] || \
	err $FUNCNAME "slice=$SLICE_ID not in deployed state"

    local VCRD_ID=

    for VCRD_ID in $( vcrd_ids_get $VCRD_ID_RANGE ); do

	local VCRD_NAME="${VCT_RD_NAME_PREFIX}${VCRD_ID}"    
	local RPC_REPLY="${VCRD_ID}-$( date +%Y%m%d_%H%M%S )-${SLICE_ID}-start-reply"

	if ! ( [ -f $VCT_NODE_MAC_DB  ] &&  grep -e "^$VCRD_ID" $VCT_NODE_MAC_DB >/dev/null ); then
	    if ! virsh -c qemu:///system dominfo $VCRD_NAME | grep -e "^State:" | grep "running" >/dev/null ; then
	    err $FUNCNAME "$VCRD_NAME not running"
	    fi
	fi

	if [ "$( uci_get $VCT_SLICE_DB.${SLICE_ID}_${VCRD_ID}.state soft )" != "deployed" ] ; then
	    err $FUNCNAME "sliver=${SLICE_ID}_${VCRD_ID} not in deployed state" soft
	    continue
	fi
	
	vct_node_ssh $VCRD_ID "confine.lib confine_sliver_start $SLICE_ID" > ${VCT_RPC_DIR}/${RPC_REPLY}

	cat ${VCT_RPC_DIR}/${RPC_REPLY}       >&1

	if [ "$( uci_get $RPC_REPLY.$SLICE_ID soft,quiet,path=$VCT_RPC_DIR )" = "sliver" ] ; then

	    uci_show $RPC_REPLY.$SLICE_ID path=$VCT_RPC_DIR | \
		sed s/$RPC_REPLY\.${SLICE_ID}/${VCT_SLICE_DB}.${SLICE_ID}_${VCRD_ID}/ | \
		uci_merge $VCT_SLICE_DB 
	fi

    done
}


vct_sliver_stop() {

    local SLICE_ID=$1; check_slice_id $SLICE_ID quiet
    local VCRD_ID_RANGE=$2
    local VCRD_ID=

    for VCRD_ID in $( vcrd_ids_get $VCRD_ID_RANGE ); do

	local VCRD_NAME="${VCT_RD_NAME_PREFIX}${VCRD_ID}"    
	local RPC_REPLY="${VCRD_ID}-$( date +%Y%m%d_%H%M%S )-${SLICE_ID}-start-reply"


	if ! ( [ -f $VCT_NODE_MAC_DB  ] &&  grep -e "^$VCRD_ID" $VCT_NODE_MAC_DB >/dev/null ); then
	    if ! virsh -c qemu:///system dominfo $VCRD_NAME | grep -e "^State:" | grep "running" >/dev/null ; then
		err $FUNCNAME "$VCRD_NAME not running" soft
		continue
	    fi
	fi

	vct_node_ssh $VCRD_ID "confine.lib confine_sliver_stop $SLICE_ID" > ${VCT_RPC_DIR}/${RPC_REPLY}

	cat ${VCT_RPC_DIR}/${RPC_REPLY}       >&1

	if [ "$( uci_get $RPC_REPLY.$SLICE_ID soft,quiet,path=$VCT_RPC_DIR )" = "sliver" ] ; then

	    uci_show $RPC_REPLY.$SLICE_ID path=$VCT_RPC_DIR | \
		sed s/$RPC_REPLY\.${SLICE_ID}/${VCT_SLICE_DB}.${SLICE_ID}_${VCRD_ID}/ | \
		uci_merge $VCT_SLICE_DB
	fi

    done
}


vct_sliver_remove() {

    local SLICE_ID=$1; check_slice_id $SLICE_ID quiet
    local VCRD_ID_RANGE=$2
    local VCRD_ID=

    for VCRD_ID in $( vcrd_ids_get $VCRD_ID_RANGE ); do

	local VCRD_NAME="${VCT_RD_NAME_PREFIX}${VCRD_ID}"    

	if ! ( [ -f $VCT_NODE_MAC_DB  ] &&  grep -e "^$VCRD_ID" $VCT_NODE_MAC_DB >/dev/null ); then
	    if ! virsh -c qemu:///system dominfo $VCRD_NAME | grep -e "^State:" | grep "running" >/dev/null ; then
		err $FUNCNAME "$VCRD_NAME not running" soft
		continue
	    fi
	fi

	vct_node_ssh $VCRD_ID "confine.lib confine_sliver_remove $SLICE_ID"

	vct_slice_attributes flush $SLICE_ID $VCRD_ID

    done
}


vct_sliver_ssh() {


    local SLIVER=$1
    local VCRD_ID_RANGE=$2
    local COMMAND=${3:-}
    local VCRD_ID=

    for VCRD_ID in $( vcrd_ids_get $VCRD_ID_RANGE ); do

	local IPV6=$( uci_get $VCT_SLICE_DB.${SLIVER}_${VCRD_ID}.if01_ipv6 | awk -F'/' '{print $1}' )
	local COUNT=0
	local COUNT_MAX=60

	while [ "$COUNT" -le $COUNT_MAX ]; do 

	    ping6 -c 1 -w 1 -W 1 $IPV6 > /dev/null && \
		break
	    
	    [ "$COUNT" = 0 ] && \
		echo -n "Waiting for $VCRD_ID to listen on $IPV6 (frstboot may take upto 40 secs)" || \
		echo -n "."

	    COUNT=$(( $COUNT + 1 ))
	done

	[ "$COUNT" = 0 ] || \
	    echo

	[ "$COUNT" -le $COUNT_MAX ] || \
	    err $FUNCNAME "Failed connecting to node=$VCRD_ID via $IPV6"
	


	echo > $VCT_KEYS_DIR/known_hosts

	if [ "$COMMAND" ]; then
	    ssh $VCT_SSH_OPTIONS root@$IPV6 ". /etc/profile > /dev/null; $@"
	else
	    ssh $VCT_SSH_OPTIONS root@$IPV6
	fi

    done
}


vct_help() {

    echo "usage..."
    cat <<EOF

    vct_help

    vct_system_install [OVERRIDE_DIRECTIVES]           : install vct system requirements
    vct_system_init                                    : initialize vct system on host
    vct_system_cleanup                                 : revert vct_system_init


    Node Management Functions
    -------------------------

    vct_node_info      [NODE_SET]                      : summary of existing domain(s)
    vct_node_create    <NODE_SET>                      : create domain with given NODE_ID
    vct_node_start     <NODE_SET>                      : start domain with given NODE_ID
    vct_node_stop      <NODE_SET>                      : stop domain with given NODE_ID
    vct_node_remove    <NODE_SET>                      : remove domain with given NODE_ID
    vct_node_console   <NODE_ID>                       : open console to running domain

    vct_node_customize <NODE_SET> [online|offline|sysupgrade]  : configure & activate node

    vct_node_ssh       <NODE_SET> ["COMMANDS"]         : ssh connect via recovery IPv6
    vct_node_scp       <NODE_SET> <SCP_ARGS>           : copy via recovery IPv6
    vct_node_mount     <NODE_SET>
    vct_node_unmount   <NODE_SET>


    Slice and Sliver Management Functions
    -------------------------------------
    Following functions always connect to a running node for RPC execution.

    vct_sliver_allocate  <SL_ID> <NODE_SET> [OS_TYPE]
    vct_sliver_deploy    <SL_ID> <NODE_SET>
    vct_sliver_start     <SL_ID> <NODE_SET>
    vct_sliver_stop      <SL_ID> <NODE_SET>
    vct_sliver_remove    <SL_ID> <NODE_SET> 

    vct_slice_attributes <show|flush|update|state=<STATE>> <SL_ID|all> [NODE_ID]

   
    Argument Definitions
    --------------------

    OVERRIDE_DIRECTIVES:= comma seperated list (NO spaces) of override directives: 
                             override_node_template, override_server_template, override_keys
    NODE_ID:=             node id given by a 4-digit lower-case hex value (eg: 0a12)
    NODE_SET:=            set of nodes given by: 'all', NODE_ID, or NODE_ID-NODE_ID (0001-0003)
    SL_ID:=               slice id given by a 12-digit lower-case hex value
    OS_TYPE:=             openwrt|debian
    COMMANDS:=            Commands to be executed on node
    SCP_ARGS:=            MUST contain keyword='remote:' which is substituted by 'root@[IPv6]:'

-------------------------------------------------------------------------------------------

    Future requests (commands not yet implemented)
    ----------------------------------------------

    vct_link_get [NODE_ID]                               : show configured links
    vct_link_del [NODE_ID[:IF]] [NODE_ID[:IF]]           : del configured link(s)
    vct_link_add <NODE_ID:IF> <NODE_ID:IF> [PACKET_LOSS] : add virtually link between
                                                           given nodes and interfaces, eg:
                                                           vct_link_add 0003:1 0005:1 10
                                                           to setup link with 10% loss


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
	vct_help
    fi

else

    case "$CMD" in
	vct_help) $CMD;;

	vct_system_install_check)   $CMD "$@";;
	vct_system_install)         $CMD "$@";;
	vct_system_init_check)      $CMD "$@";;
	vct_system_init)            $CMD "$@";;
	vct_system_cleanup)         $CMD "$@";;

	vct_node_info)              $CMD "$@";;
	vct_node_create)            $CMD "$@";;
	vct_node_start)             $CMD "$@";;
	vct_node_stop)              $CMD "$@";;
	vct_node_remove)            $CMD "$@";;
	vct_node_console)           $CMD "$@";;
	vct_node_ssh)               $CMD "$@";;
	vct_node_scp)               $CMD "$@";;

        vct_node_customize)         $CMD "$@";;
        vct_node_mount)             $CMD "$@";;
        vct_node_unmount)           $CMD "$@";;

        vct_sliver_allocate)        $CMD "$@";;
        vct_sliver_deploy)          $CMD "$@";;
        vct_sliver_start)           $CMD "$@";;
        vct_sliver_stop)            $CMD "$@";;
        vct_sliver_remove)          $CMD "$@";;

	vct_slice_attributes)       $CMD "$@";;

	*) vct_help;;
    esac

fi

#echo "successfully finished $0 $*" >&2
