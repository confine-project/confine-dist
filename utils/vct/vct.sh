#!/bin/bash

set -u # set -o nounset
#set -o errexit

# We want to expand aliases because
# in a fedora environment it might be useful
# to alias virsh to 'sudo virsh' otherwise it would ask for
# a password every time the command is executed.
# Aliasses set before this line (outside the script), will not be expanded.
shopt -s expand_aliases

LANG=C


# Compute VCT_DIR, the absolute location of VCT source and configuration.
# Please do not use paths relative to the current directory, but make them
# relative to VCT_DIR instead.
if echo "$0" | grep -q /; then
    VCT_FILE=$0
else
    VCT_FILE=$(type "$0" | sed -ne 's#.* \(/.*\)#\1#p')
fi
VCT_DIR=$(dirname "$(readlink -f "$VCT_FILE")")

if [ -f "$VCT_DIR/vct.conf.overrides" ]; then
    . "$VCT_DIR/vct.conf.default"
    . "$VCT_DIR/vct.conf.overrides"
elif [ -f "$VCT_DIR/vct.conf" ]; then
    . "$VCT_DIR/vct.conf"
elif [ -f "$VCT_DIR/vct.conf.default" ]; then
    . "$VCT_DIR/vct.conf.default"
fi


# MAIN_PID=$BASHPID

UCI_DEFAULT_PATH=$VCT_UCI_DIR
ERR_LOG_TAG='VCT'
. "$VCT_DIR/lxc.functions"
. "$VCT_DIR/confine.functions"




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


vct_sudo_sh() {
    if [ "${VCT_DRY_RUN:-}" ]; then
	vct_do sudo sh -c "$@"
	return $?
    fi

    local QUERY=

    if [ "$VCT_SUDO_ASK" != "NO" ]; then

	echo "" >&2
	echo "$0 wants to execute (VCT_SUDO_ASK=$VCT_SUDO_ASK set to ask):" >&2
	echo ">>>>   sudo sh -c $@   <<<<" >&2
	read -p "Pleas type: y) to execute and continue, s) to skip and continue, or anything else to abort: " QUERY >&2

	if [ "$QUERY" == "y" ] ; then
	    sudo sh -c "$@"
	    return $?

	elif [ "$QUERY" == "s" ] ; then

	    return 0
	fi
	
	err $FUNCNAME "sudo execution cancelled: $QUERY"
	return 1
    fi

    sudo sh -c "$@"
    return $?
}


vct_do_ping() {
	if echo $1 | grep -e ":" >/dev/null; then
		PING="ping6 -c 1 -w 1 -W 1"
	else
		PING="ping -c 1 -w 1 -W 1"
	fi

	$PING $1 
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
    variable_check VCT_SSH_OPTIONS     quiet
    variable_check VCT_TINC_PID        quiet
    variable_check VCT_TINC_LOG        quiet
    variable_check VCT_TINC_START      quiet


# Typical cases:
# VCT_NODE_TEMPLATE_URL="http://media.confine-project.eu/vct/openwrt-x86-generic-combined-ext4.img.tgz"
# VCT_NODE_TEMPLATE_URL="ssh:22:user@example.org:///confine/confine-dist/openwrt/bin/x86/openwrt-x86-generic-combined-ext4.img.gz"
# VCT_NODE_TEMPLATE_URL="file:///../../openwrt/bin/x86/openwrt-x86-generic-combined-ext4.img.gz"

    variable_check VCT_NODE_TEMPLATE_URL  quiet

    VCT_NODE_TEMPLATE_COMP=$( ( echo $VCT_NODE_TEMPLATE_URL | grep -e "\.tgz$" >/dev/null && echo "tgz" ) ||\
                         ( echo $VCT_NODE_TEMPLATE_URL | grep -e "\.tar\.gz$" >/dev/null && echo "tar.gz" ) ||\
                         ( echo $VCT_NODE_TEMPLATE_URL | grep -e "\.gz$" >/dev/null && echo "gz" ) )
    variable_check VCT_NODE_TEMPLATE_COMP quiet
    VCT_NODE_TEMPLATE_TYPE=$(echo $VCT_NODE_TEMPLATE_URL | awk -F"$VCT_NODE_TEMPLATE_COMP" '{print $1}' | awk -F'.' '{print $(NF-1)}')
    variable_check VCT_NODE_TEMPLATE_TYPE quiet
    VCT_NODE_TEMPLATE_NAME=$(echo $VCT_NODE_TEMPLATE_URL | awk -F'/' '{print $(NF)}' | awk -F".${VCT_NODE_TEMPLATE_TYPE}.${VCT_NODE_TEMPLATE_COMP}" '{print $1}')
    variable_check VCT_NODE_TEMPLATE_NAME quiet
    VCT_NODE_TEMPLATE_SITE=$(echo $VCT_NODE_TEMPLATE_URL | awk -F"${VCT_NODE_TEMPLATE_NAME}.${VCT_NODE_TEMPLATE_TYPE}.${VCT_NODE_TEMPLATE_COMP}" '{print $1}')
    variable_check VCT_NODE_TEMPLATE_SITE quiet

    ( [ $VCT_NODE_TEMPLATE_TYPE = "vmdk" ] || [ $VCT_NODE_TEMPLATE_TYPE = "raw" ] || [ $VCT_NODE_TEMPLATE_TYPE = "img" ] ) ||\
           err $FUNCNAME "Non-supported fs template type $VCT_NODE_TEMPLATE_TYPE"

    [ "$VCT_NODE_TEMPLATE_URL" = "${VCT_NODE_TEMPLATE_SITE}${VCT_NODE_TEMPLATE_NAME}.${VCT_NODE_TEMPLATE_TYPE}.${VCT_NODE_TEMPLATE_COMP}" ] ||\
           err $FUNCNAME "Invalid $VCT_NODE_TEMPLATE_URL != ${VCT_NODE_TEMPLATE_SITE}${VCT_NODE_TEMPLATE_NAME}.${VCT_NODE_TEMPLATE_TYPE}.${VCT_NODE_TEMPLATE_COMP}"


    variable_check VCT_SLICE_OWRT_TEMPLATE_URL  quiet
    VCT_SLICE_OWRT_TEMPLATE_COMP=$((echo $VCT_SLICE_OWRT_TEMPLATE_URL | grep -e "\.tgz$" >/dev/null && echo "tgz" ) ||\
				   (echo $VCT_SLICE_OWRT_TEMPLATE_URL | grep -e "\.tar\.gz$" >/dev/null && echo "tar.gz" ))
    VCT_SLICE_OWRT_TEMPLATE_NAME=$(echo $VCT_SLICE_OWRT_TEMPLATE_URL | awk -F'/' '{print $(NF)}' | awk -F".${VCT_SLICE_OWRT_TEMPLATE_COMP}" '{print $1}')
    VCT_SLICE_OWRT_TEMPLATE_SITE=$(echo $VCT_SLICE_OWRT_TEMPLATE_URL | awk -F"${VCT_SLICE_OWRT_TEMPLATE_NAME}.${VCT_SLICE_OWRT_TEMPLATE_COMP}" '{print $1}')

    variable_check VCT_SLICE_OWRT_EXP_DATA_URL  quiet
    VCT_SLICE_OWRT_EXP_DATA_COMP=$(echo $VCT_SLICE_OWRT_EXP_DATA_URL | grep -e "\.tgz$" >/dev/null && echo "tgz" )
    VCT_SLICE_OWRT_EXP_DATA_NAME=$(echo $VCT_SLICE_OWRT_EXP_DATA_URL | awk -F'/' '{print $(NF)}' | awk -F".${VCT_SLICE_OWRT_EXP_DATA_COMP}" '{print $1}')
    VCT_SLICE_OWRT_EXP_DATA_SITE=$(echo $VCT_SLICE_OWRT_EXP_DATA_URL | awk -F"${VCT_SLICE_OWRT_EXP_DATA_NAME}.${VCT_SLICE_OWRT_EXP_DATA_COMP}" '{print $1}')

    variable_check VCT_SLICE_DEBIAN_TEMPLATE_URL  quiet
    VCT_SLICE_DEBIAN_TEMPLATE_COMP=$((echo $VCT_SLICE_DEBIAN_TEMPLATE_URL | grep -e "\.tgz$" >/dev/null && echo "tgz" ) ||\
				     (echo $VCT_SLICE_DEBIAN_TEMPLATE_URL | grep -e "\.tar\.gz$" >/dev/null && echo "tar.gz" ))
    VCT_SLICE_DEBIAN_TEMPLATE_NAME=$(echo $VCT_SLICE_DEBIAN_TEMPLATE_URL | awk -F'/' '{print $(NF)}' | awk -F".${VCT_SLICE_DEBIAN_TEMPLATE_COMP}" '{print $1}')
    VCT_SLICE_DEBIAN_TEMPLATE_SITE=$(echo $VCT_SLICE_DEBIAN_TEMPLATE_URL | awk -F"${VCT_SLICE_DEBIAN_TEMPLATE_NAME}.${VCT_SLICE_DEBIAN_TEMPLATE_COMP}" '{print $1}')

    variable_check VCT_SLICE_DEBIAN_EXP_DATA_URL  quiet
    VCT_SLICE_DEBIAN_EXP_DATA_COMP=$(echo $VCT_SLICE_DEBIAN_EXP_DATA_URL | grep -e "\.tgz$" >/dev/null && echo "tgz" )
    VCT_SLICE_DEBIAN_EXP_DATA_NAME=$(echo $VCT_SLICE_DEBIAN_EXP_DATA_URL | awk -F'/' '{print $(NF)}' | awk -F".${VCT_SLICE_DEBIAN_EXP_DATA_COMP}" '{print $1}')
    VCT_SLICE_DEBIAN_EXP_DATA_SITE=$(echo $VCT_SLICE_DEBIAN_EXP_DATA_URL | awk -F"${VCT_SLICE_DEBIAN_EXP_DATA_NAME}.${VCT_SLICE_DEBIAN_EXP_DATA_COMP}" '{print $1}')

}


vct_tinc_setup() {
    vct_do rm -rf $VCT_TINC_DIR/$VCT_TINC_NET
    vct_do mkdir -p $VCT_TINC_DIR/$VCT_TINC_NET/hosts

    vct_do_sh "cat <<EOF > $VCT_TINC_DIR/$VCT_TINC_NET/tinc.conf
BindToAddress = 0.0.0.0
Port = $VCT_SERVER_TINC_PORT
Name = server
StrictSubnets = yes
EOF
"
    vct_do_sh "cat <<EOF > $VCT_TINC_DIR/$VCT_TINC_NET/hosts/server
Address = $VCT_SERVER_TINC_IP
Port = $VCT_SERVER_TINC_PORT
Subnet = $VCT_TESTBED_MGMT_IPV6_PREFIX48:0:0:0:0:2/128
EOF
"
    #vct_do tincd -c $VCT_TINC_DIR/$VCT_TINC_NET  -K
    vct_do_sh "cat $VCT_KEYS_DIR/tinc/rsa_key.pub >> $VCT_TINC_DIR/$VCT_TINC_NET/hosts/server"
    vct_do ln -s $VCT_KEYS_DIR/tinc/rsa_key.priv $VCT_TINC_DIR/$VCT_TINC_NET/rsa_key.priv

    vct_do_sh "cat <<EOF > $VCT_TINC_DIR/$VCT_TINC_NET/tinc-up
#!/bin/sh
ip -6 link set \\\$INTERFACE up mtu 1400
ip -6 addr add $VCT_TESTBED_MGMT_IPV6_PREFIX48:0:0:0:0:2/48 dev \\\$INTERFACE
EOF
"
    vct_do_sh "cat <<EOF > $VCT_TINC_DIR/$VCT_TINC_NET/tinc-down
#!/bin/sh
ip -6 addr del $VCT_TESTBED_MGMT_IPV6_PREFIX48:0:0:0:0:2/48 dev \\\$INTERFACE
ip -6 link set \\\$INTERFACE down
EOF
"
    vct_do chmod a+rx $VCT_TINC_DIR/$VCT_TINC_NET/tinc-{up,down}
    
}


vct_tinc_start() {
    echo "$FUNCNAME $@" >&2
    vct_sudo $VCT_TINC_START
}


vct_tinc_stop() {
    echo "$FUNCNAME $@" >&2

    local TINC_PID=$( [ -f $VCT_TINC_PID ] && cat $VCT_TINC_PID )
    local TINC_CNT=0
    local TINC_MAX=20
    if [ "$TINC_PID" ] ; then 

	vct_sudo $VCT_TINC_STOP
#	vct_sudo kill $TINC_PID

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
	    echo "Killing vct tincd the hard way" >&2
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


vct_system_install_server() {
    local CURRENT_VERSION=$(python -c "from controller import get_version; print get_version();" || echo false)
    
    vct_sudo apt-get update
    vct_sudo apt-get install -y --force-yes python-pip
    
    vct_do mkdir -p $VCT_SERVER_DIR/{media/templates,static,private/exp_data,private/overlay,pki/ca}
    # Don't know why /pki gets created as root.. but here a quick fix:
    vct_sudo chown -R $VCT_USER $VCT_SERVER_DIR/pki
    
    # Executes pip commands on /tmp because of garbage they generate
    cd /tmp
    if [[ ! $(pip freeze|grep confine-controller) ]]; then
        # First time controller gets installed
        vct_sudo pip install confine-controller==$VCT_SERVER_VERSION
        vct_sudo controller-admin.sh install_requirements --local
    else
        # An older version is present, just go ahead and proceed with normal way
        vct_sudo python "$VCT_DIR/server/manage.py" upgradecontroller --pip_only --controller_version $VCT_SERVER_VERSION
    fi
    
    # cleanup possible pip shit
    # vct_sudo rm -fr {pip-*,build,src}
    
    cd -
    
    # We need to be sure that postgres is up:
    vct_sudo service postgresql start
    vct_sudo python "$VCT_DIR/server/manage.py" setuppostgres --db_name controller --db_user confine --db_password confine
    
    if [[ $CURRENT_VERSION != false ]]; then
        # Per version upgrade specific operations
        ( cd $VCT_DIR/server && vct_sudo python manage.py postupgradecontroller --no-restart --local --from $CURRENT_VERSION )
    else
        vct_sudo python "$VCT_DIR/server/manage.py" syncdb --noinput
        vct_sudo python "$VCT_DIR/server/manage.py" migrate --noinput
    fi
    
    vct_sudo python "$VCT_DIR/server/manage.py" setupceleryd --username $VCT_USER --processes 2 --greenlets 50
    
    if [ -d /etc/apache/sites-enabled ] && ! [ -d /etc/apache/sites-enabled.orig ]; then
        vct_sudo cp -ar /etc/apache/sites-enabled /etc/apache/sites-enabled.orig
        vct_sudo rm -f /etc/apache/sites-enabled/*
    fi
    
    # Setup tincd
    vct_sudo python "$VCT_DIR/server/manage.py" setuptincd --noinput --address="${VCT_SERVER_TINC_IP}"
    python "$VCT_DIR/server/manage.py" updatetincd

    # Setup https certificate for the management network
    vct_do python "$VCT_DIR/server/manage.py" setuppki --org_name VCT --noinput
    vct_sudo apt-get install -y libapache2-mod-wsgi
    vct_sudo python "$VCT_DIR/server/manage.py" setupapache --noinput --user $VCT_USER --processes 2 --threads 25

    # Move static files in a place where apache can get them
    python "$VCT_DIR/server/manage.py" collectstatic --noinput

    # Setup and configure firmware generation
    vct_sudo python "$VCT_DIR/server/manage.py" setupfirmware
    vct_do python "$VCT_DIR/server/manage.py" loaddata firmwareconfig
    vct_do python "$VCT_DIR/server/manage.py" loaddata "$VCT_DIR/server/vct/fixtures/firmwareconfig.json"
    vct_do python "$VCT_DIR/server/manage.py" syncfirmwareplugins
    
    # Apply changes
    vct_sudo python "$VCT_DIR/server/manage.py" startservices --no-tinc --no-celeryd --no-celerybeat --no-apache2
    vct_sudo python "$VCT_DIR/server/manage.py" restartservices
    vct_sudo $VCT_TINC_START
    
    # Create a vct user, default VCT group and provide initial auth token to vct user
    # WARNING the following code is sensitive to indentation !!
    cat <<- EOF | python "$VCT_DIR/server/manage.py" shell
	from users.models import *

	users = {}

	if not User.objects.filter(username='vct').exists():
	    print 'Creating vct superuser'
	    User.objects.create_superuser('vct', 'vct@localhost', 'vct', name='vct')
	    users['vct'] = User.objects.get(username='vct')

	for username in ['admin', 'researcher', 'technician', 'member']:
	    if not User.objects.filter(username=username).exists():
	        print 'Creating %s user' % username
	        User.objects.create_user(username, 'vct+%s@localhost' % username, username, name=username)
	    users[username] = User.objects.get(username=username)
	
	group, created = Group.objects.get_or_create(name='vct', allow_slices=True, allow_nodes=True)
	
	print '\nCreating roles ...'
	Roles.objects.get_or_create(user=users['vct'], group=group, is_admin=True)
	Roles.objects.get_or_create(user=users['admin'], group=group, is_admin=True)
	Roles.objects.get_or_create(user=users['researcher'], group=group, is_researcher=True)
	Roles.objects.get_or_create(user=users['technician'], group=group, is_technician=True)
	Roles.objects.get_or_create(user=users['member'], group=group)
	
	token_data = open('${VCT_KEYS_DIR}/id_rsa.pub', 'ro').read().strip()
	for __, user in users.items():
	    print '\nAdding auth token to user %s' % user.username
	    AuthToken.objects.get_or_create(user=user, data=token_data)
	
	EOF

    # Load further data into the database
    vct_do python "$VCT_DIR/server/manage.py" loaddata "$VCT_DIR/server/vct/fixtures/vcttemplates.json"
    vct_do python "$VCT_DIR/server/manage.py" loaddata "$VCT_DIR/server/vct/fixtures/vctslices.json"

    # Enable local system monitoring via crontab
    vct_do python "$VCT_DIR/server/manage.py" setuplocalmonitor
}


vct_system_purge_server() {
	vct_sudo python "$VCT_DIR/server/manage.py" stopservices --no-postgresql  || true
	ps aux | grep ^postgres > /dev/null || vct_sudo /etc/init.d/postgresql start # || true
	sudo su postgres -c 'psql -c "DROP DATABASE controller;"'  # || true
	vct_sudo pip uninstall confine-controller -y
	#grep "^confine" /etc/passwd > /dev/null && vct_sudo deluser --force --remove-home confine  || true
	#grep "^confine" /etc/group  > /dev/null && vct_sudo delgroup confine  || true
	if [ -d $VCT_SERVER_DIR ]; then
	    vct_do rm -rf $VCT_SERVER_DIR  || true
	fi
}


vct_system_install_check() {
    #echo $FUNCNAME $@ >&2

    local OPT_CMD=${1:-}
    local CMD_SOFT=$(      echo "$OPT_CMD" | grep -e "soft"      > /dev/null && echo "soft," )
    local CMD_QUICK=$(     echo "$OPT_CMD" | grep -e "quick"     > /dev/null && echo "quick," )
    local CMD_INSTALL=$(   echo "$OPT_CMD" | grep -e "install"   > /dev/null && echo "install," )

    local UPD_NODE=$(      echo "$OPT_CMD" | grep -e "node"      > /dev/null && echo "y" )
    local UPD_SLICE=$(     echo "$OPT_CMD" | grep -e "slice"     > /dev/null && echo "y" )
    local UPD_KEYS=$(      echo "$OPT_CMD" | grep -e "keys"      > /dev/null && echo "y" )
    local UPD_TINC=$(      echo "$OPT_CMD" | grep -e "tinc"      > /dev/null && echo "y" )
    local UPD_SERVER=$(    echo "$OPT_CMD" | grep -e "server"    > /dev/null && echo "y" )

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
    
    if is_rpm; then
        check_rpm
    else
        check_deb
    fi

    # check uci binary
    local UCI_URL="http://media.confine-project.eu/vct/uci.tgz"

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

	echo "Copying $VCT_DIR/vct-default-keys to $VCT_KEYS_DIR. " >&2
	echo "Keys are INSECURE unless vct_system_install is called with override_keys directive !! " >&2

	vct_do cp -rv "$VCT_DIR/vct-default-keys"  $VCT_KEYS_DIR

	vct_do chmod -R og-rwx $VCT_KEYS_DIR/*
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
	echo "Copy new public key: $VCT_KEYS_DIR/id_rsa.pub -> $VCT_DIR/../../files/etc/dropbear/authorized_keys" >&2
	read -p "(then please recompile your node images afterwards)? [Y|n]: " QUERY >&2

	[ "$QUERY" = "y" ] || [ "$QUERY" = "" ] && vct_do mkdir -p "$VCT_DIR/../../files/etc/dropbear/" && \
	    vct_do cp -v $VCT_KEYS_DIR/id_rsa.pub "$VCT_DIR/../../files/etc/dropbear/authorized_keys"

    fi

    [ -f $VCT_KEYS_DIR/tinc/rsa_key.priv ] && [ -f $VCT_KEYS_DIR/tinc/rsa_key.pub ] || \
	{ err $FUNCNAME "$VCT_KEYS_DIR/tinc/rsa_key.* not existing" $CMD_SOFT || return 1 ;}

    [ -f $VCT_KEYS_DIR/id_rsa ] &&  [ -f $VCT_KEYS_DIR/id_rsa.pub ] || \
	{ err $FUNCNAME "$VCT_KEYS_DIR/id_rsa not existing" $CMD_SOFT || return 1 ;}


    # check tinc configuration:
    [ -d $VCT_TINC_DIR ] && [ $CMD_INSTALL ] && [ $UPD_TINC ] && vct_do rm -rf $VCT_TINC_DIR/$VCT_TINC_NET

    if ! [ -d $VCT_TINC_DIR/$VCT_TINC_NET ] &&  [ $CMD_INSTALL ] ; then
	vct_tinc_setup
    fi

    [ -f /etc/tinc/nets.boot ] || vct_sudo touch /etc/tinc/nets.boot
    [ -f $VCT_TINC_DIR/nets.boot ] || vct_sudo touch $VCT_TINC_DIR/nets.boot

    [ -f $VCT_TINC_DIR/$VCT_TINC_NET/hosts/server ] || \
	{ err $FUNCNAME "$VCT_TINC_DIR/$VCT_TINC_NET/hosts/server not existing" $CMD_SOFT || return 1 ;}


    if [ "$CMD_INSTALL" ] &&  [ "$UPD_NODE" ]; then
	echo "" >&2
	read -p "Purge existing nodes and slivers (Please type 'y' or anything else to skip): " QUERY >&2

	if [ "$QUERY" == "y" ] ; then
	    vct_do vct_node_remove all
	fi
    fi


    # check for update and downloadable node-system-template file:
    [ "$UPD_NODE" ] && vct_do rm -f $VCT_DL_DIR/${VCT_NODE_TEMPLATE_NAME}.${VCT_NODE_TEMPLATE_TYPE}.${VCT_NODE_TEMPLATE_COMP}
    if ! vct_do install_url $VCT_NODE_TEMPLATE_URL $VCT_NODE_TEMPLATE_SITE $VCT_NODE_TEMPLATE_NAME.$VCT_NODE_TEMPLATE_TYPE $VCT_NODE_TEMPLATE_COMP $VCT_DL_DIR 0 "${CMD_SOFT}${CMD_INSTALL}" ; then
	err $FUNCNAME "Installing ULR=$VCT_NODE_TEMPLATE_URL failed" $CMD_SOFT || return 1
    else
	ln -fs $VCT_DL_DIR/$VCT_NODE_TEMPLATE_NAME.$VCT_NODE_TEMPLATE_TYPE.$VCT_NODE_TEMPLATE_COMP $VCT_DL_DIR/confine-node-template.img.gz
    fi

    # check for update and downloadable slice-openwrt-template file:
    [ "$UPD_SLICE" ] && vct_do rm -f $VCT_DL_DIR/${VCT_SLICE_OWRT_TEMPLATE_NAME}.${VCT_SLICE_OWRT_TEMPLATE_COMP}
    if ! vct_do install_url $VCT_SLICE_OWRT_TEMPLATE_URL $VCT_SLICE_OWRT_TEMPLATE_SITE $VCT_SLICE_OWRT_TEMPLATE_NAME $VCT_SLICE_OWRT_TEMPLATE_COMP $VCT_DL_DIR 0 "${CMD_SOFT}${CMD_INSTALL}" ; then
	err $FUNCNAME "Installing ULR=$VCT_SLICE_OWRT_TEMPLATE_URL failed" $CMD_SOFT || return 1
    else
	ln -fs $VCT_DL_DIR/$VCT_SLICE_OWRT_TEMPLATE_NAME.$VCT_SLICE_OWRT_TEMPLATE_COMP $VCT_DL_DIR/confine-slice-openwrt-template.tgz
    fi

    [ "$UPD_SLICE" ] && vct_do rm -f $VCT_DL_DIR/${VCT_SLICE_OWRT_EXP_DATA_NAME}.${VCT_SLICE_OWRT_EXP_DATA_COMP}
    if ! vct_do install_url $VCT_SLICE_OWRT_EXP_DATA_URL $VCT_SLICE_OWRT_EXP_DATA_SITE $VCT_SLICE_OWRT_EXP_DATA_NAME $VCT_SLICE_OWRT_EXP_DATA_COMP $VCT_DL_DIR 0 "${CMD_SOFT}${CMD_INSTALL}" ; then
	err $FUNCNAME "Installing ULR=$VCT_SLICE_OWRT_EXP_DATA_URL failed" $CMD_SOFT || return 1
    else
	ln -fs $VCT_DL_DIR/$VCT_SLICE_OWRT_EXP_DATA_NAME.$VCT_SLICE_OWRT_EXP_DATA_COMP $VCT_DL_DIR/confine-slice-openwrt-exp-data.tgz
    fi

    # check for update and downloadable slice-debian-template file:
    [ "$UPD_SLICE" ] && vct_do rm -f $VCT_DL_DIR/${VCT_SLICE_DEBIAN_TEMPLATE_NAME}.${VCT_SLICE_DEBIAN_TEMPLATE_COMP}
    if ! vct_do install_url $VCT_SLICE_DEBIAN_TEMPLATE_URL $VCT_SLICE_DEBIAN_TEMPLATE_SITE $VCT_SLICE_DEBIAN_TEMPLATE_NAME $VCT_SLICE_DEBIAN_TEMPLATE_COMP $VCT_DL_DIR 0 "${CMD_SOFT}${CMD_INSTALL}" ; then
	err $FUNCNAME "Installing ULR=$VCT_SLICE_DEBIAN_TEMPLATE_URL failed" $CMD_SOFT || return 1
    else
	ln -fs $VCT_DL_DIR/$VCT_SLICE_DEBIAN_TEMPLATE_NAME.$VCT_SLICE_DEBIAN_TEMPLATE_COMP $VCT_DL_DIR/confine-slice-debian-template.tgz
    fi

    [ "$UPD_SLICE" ] && vct_do rm -f $VCT_DL_DIR/${VCT_SLICE_DEBIAN_EXP_DATA_NAME}.${VCT_SLICE_DEBIAN_EXP_DATA_COMP}
    if ! vct_do install_url $VCT_SLICE_DEBIAN_EXP_DATA_URL $VCT_SLICE_DEBIAN_EXP_DATA_SITE $VCT_SLICE_DEBIAN_EXP_DATA_NAME $VCT_SLICE_DEBIAN_EXP_DATA_COMP $VCT_DL_DIR 0 "${CMD_SOFT}${CMD_INSTALL}" ; then
	err $FUNCNAME "Installing ULR=$VCT_SLICE_DEBIAN_EXP_DATA_URL failed" $CMD_SOFT || return 1
    else
	ln -fs $VCT_DL_DIR/$VCT_SLICE_DEBIAN_EXP_DATA_NAME.$VCT_SLICE_DEBIAN_EXP_DATA_COMP $VCT_DL_DIR/confine-slice-debian-exp-data.tgz
    fi


    if [ $CMD_INSTALL ] && [ $UPD_SERVER ] ; then
	echo "" >&2
	read -p "Purge server installation (type 'y' or anything else to skip): " QUERY >&2

	if [ "$QUERY" == "y" ] ; then
	    vct_system_purge_server
	fi
    fi

    if [ $CMD_INSTALL ] && ( [ $UPD_SERVER ] || ! [ -d $VCT_SERVER_DIR ] ); then
        vct_system_install_server
    fi

    if ! [ -d $VCT_SERVER_DIR ]; then
       err $FUNCNAME "Missing controller installation at $VCT_SERVER_DIR"
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
		local DHCPD_MASK=$( variable_check ${BRIDGE}_V4_DHCPD_MASK soft 2>/dev/null )

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
	    
		[ $CMD_INIT ] && [ ${UDHCPD_PID:-} ] && echo "kill udhcpd" >&2 && vct_sudo kill $UDHCPD_PID && sleep 1
		

		if [ $DHCPD_IP_MIN ] && [ $DHCPD_IP_MAX ] && [ $DHCPD_DNS ] && [ $DHCPD_MASK ]; then
		    if [ $CMD_INIT ] ; then
			vct_do_sh "cat <<EOF > $UDHCPD_CONF_FILE
start           $DHCPD_IP_MIN
end             $DHCPD_IP_MAX
interface       $BR_NAME 
lease_file      $UDHCPD_LEASE_FILE
option router   $( echo $BR_V4_LOCAL_IP | awk -F'/' '{print $1}' )
option dns      $DHCPD_DNS
option subnet   $DHCPD_MASK
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
#		local BR_V6_RESCUE2_IP=$BR_V6_RESCUE2_PREFIX64:$( vct_true eui64_from_link $BR_NAME )/64
		local BR_V6_RESCUE2_IP=$BR_V6_RESCUE2_PREFIX64::2/64
		if vct_true false || ! ip addr show dev $BR_NAME | grep -e "inet6 " | \
		    grep -ie " $( ipv6calc -I ipv6 $BR_V6_RESCUE2_IP -O ipv6 ) " >/dev/null; then
		    ( [ $CMD_INIT ] && vct_sudo ip addr add $BR_V6_RESCUE2_IP dev $BR_NAME ) ||\
                	{ err $FUNCNAME "unconfigured ipv6 rescue net: $BR_NAME $BR_V6_RESCUE2_IP" $CMD_SOFT || return 1 ;}
		fi
	    fi

# disabled, currently not needed...	    
#	    #check if local bridge has IPv6 for debug network:
#	    local BR_V6_DEBUG_IP=$( variable_check ${BRIDGE}_V6_DEBUG_IP soft 2>/dev/null ) 
#	    if [ $BR_V6_DEBUG_IP ] ; then
#		if ! ip addr show dev $BR_NAME | grep -e "inet6 " | \
#		    grep -ie " $( ipv6calc -I ipv6 $BR_V6_DEBUG_IP -O ipv6 ) " >/dev/null; then
#		    ( [ $CMD_INIT ] && vct_sudo ip addr add $BR_V6_DEBUG_IP dev $BR_NAME ) ||\
#               	{ err $FUNCNAME "unconfigured ipv6 debut net: $BR_NAME $BR_V6_DEBUG_IP" $CMD_SOFT || return 1 ;}
#		fi
#	    fi

            # check if bridge is UP:
	    if ! ip link show dev $BR_NAME | grep ",UP" >/dev/null; then
		    ( [ $CMD_INIT ] && vct_sudo ip link set dev  $BR_NAME up ) ||\
                	{ err $FUNCNAME "disabled link $BR_NAME" $CMD_SOFT || return 1 ;}
	    fi

	fi
    done

    # check if controller system and management network is running:
    [ $CMD_INIT ] && vct_tinc_stop
    [ $CMD_INIT ] && vct_sudo service postgresql start
    [ $CMD_INIT ] && vct_sudo python "$VCT_DIR/server/manage.py" startservices
    [ $CMD_INIT ] && vct_sudo $VCT_TINC_START
}


vct_system_init() {
    vct_system_init_check init
}


vct_system_cleanup() {
    local FLUSH_ARG="${1:-}"

    case $FLUSH_ARG in
        "") vct_do vct_node_stop all ;;
        "flush")
            vct_do vct_node_remove all  # also stops them
            ;;
        *) err $FUNCNAME "Invalid argument: $FLUSH_ARG" ;;
    esac

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
	    
		[ ${UDHCPD_PID:-} ] &&  echo "kill udhcpd" >&2 && vct_sudo kill $UDHCPD_PID
		
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

    if [ $VCT_SERVER_DIR ]; then
	vct_sudo python "$VCT_DIR/server/manage.py" stopservices --no-postgresql
    fi

}


vct_system_purge() {
    vct_system_cleanup flush
    vct_system_purge_server
    [ "$VCT_VIRT_DIR" != "/" ] && vct_sudo rm -rf $VCT_VIRT_DIR
}


##########################################################################
#######  
##########################################################################



vcrd_ids_get() {
    local VCRD_ID_RANGE=$1
    local VCRD_ID_STATE=${2:-}
    local VCRD_ID=

    if [ "$VCRD_ID_RANGE" = "all" ] ; then
	
	 virsh -c qemu:///system list --all 2>/dev/null | grep -e "$VCT_RD_NAME_PREFIX" | grep -e "$VCRD_ID_STATE$" | \
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


vct_node_get_ip_from_db() {
	local VCRD_ID=$1
	local IP=
	[ -f $VCT_NODE_MAC_DB  ]  && {
	        VCT_NODE_MACIP=$(grep -e "^$VCRD_ID" $VCT_NODE_MAC_DB | awk '{print $2}')
		if  echo $VCT_NODE_MACIP | grep -e "|" > /dev/null ; then
		    IP="$( grep -e "^$VCRD_ID" $VCT_NODE_MAC_DB | awk '{print $2}' | cut -d\| -f2 )"
		fi
	}
	echo "$IP"
}


vct_node_get_mac() {
    local VCRD_ID=$1
    local OPT_CMD=${2:-}
    local CMD_QUIET=$(  echo "$OPT_CMD" | grep -e "quiet" > /dev/null && echo "quiet," )
    local MAC=

    [ -f $VCT_NODE_MAC_DB  ] && \
	MAC="$( grep -e "^$VCRD_ID" $VCT_NODE_MAC_DB | awk '{print $2}' | cut -d\| -f1 )"

#    echo "vcrd_id=$VCRD_ID mac=$MAC db=$VCT_NODE_MAC_DB pwd=$(pwd)" >&2


    if  [ $MAC ]  ; then

	[ "$CMD_QUIET" ] || echo $FUNCNAME "connecting to real node=$VCRD_ID mac=$MAC" >&2

    else

	local VCRD_NAME="${VCT_RD_NAME_PREFIX}${VCRD_ID}"

	if ! virsh -c qemu:///system dominfo $VCRD_NAME | grep -e "^State:" >/dev/null; then
	    err $FUNCNAME "$VCRD_NAME not running"
	fi

	MAC=$( virsh -c qemu:///system dumpxml $VCRD_NAME | \
	    xmlstarlet sel -T -t -m "/domain/devices/interface" \
	    -v child::source/attribute::* -o " " -v child::mac/attribute::address -n | \
	    grep -e "^$VCT_RD_LOCAL_BRIDGE " | awk '{print $2 }' || \
	    err $FUNCNAME "Failed resolving MAC address for $VCRD_NAME $VCT_RD_LOCAL_BRIDGE" )

	[ "$CMD_QUIET" ] || echo $FUNCNAME "connecting to virtual node=$VCRD_ID mac=$MAC" >&2


    fi

    echo $MAC
}


vct_node_info() {
    local VCRD_ID_RANGE=${1:-}

    # virsh --connect qemu:///system list --all

    local REAL_IDS="$( [ -f $VCT_NODE_MAC_DB ] && cat $VCT_NODE_MAC_DB | awk '{print $1}' | grep -e "^[0-9,a-f][0-9,a-f][0-9,a-f][0-9,a-f]$" )"
    local VIRT_IDS="$( virsh -c qemu:///system list --all | grep ${VCT_RD_NAME_PREFIX} | awk '{print $2}' | awk -F'-' '{print $2}' )"
    local ALL_IDS="$REAL_IDS $VIRT_IDS"

    printf "%-4s %-8s %-39s %-5s  %-22s %-5s\n" node state rescue rtt management rtt
    echo   "-----------------------------------------------------------------------------------------"

    local ID=
    for ID in $( [ "$VCRD_ID_RANGE" ] && vcrd_ids_get $VCRD_ID_RANGE || echo "$ALL_IDS" ); do
	local NAME="${VCT_RD_NAME_PREFIX}${ID}"
	local STATE=$( echo "$VIRT_IDS" | grep -e "$ID" > /dev/null && \
	    ( virsh -c qemu:///system dominfo $NAME | grep -e "State:" | grep -e "running" > /dev/null && echo "running" || echo "down"  ) || \
	    echo "EXTERN" )
	local MAC=$( vct_node_get_mac $ID quiet )
	local IPV6_RESCUE="${VCT_BR00_V6_RESCUE2_PREFIX64}:$( eui64_from_mac $MAC )"
	local IP="$(vct_node_get_ip_from_db $ID)"
	IP="${IP:-$IPV6_RESCUE}"
	local RESCUE_DELAY="$( [ "$STATE" = "down" ] && echo "--" || vct_do_ping $IP  | grep avg | awk -F' = ' '{print $2}' | awk -F'/' '{print $1}')"
	local MGMT=$VCT_TESTBED_MGMT_IPV6_PREFIX48:$ID::2
	local MGMT_DELAY="$( [ "$STATE" = "down" ] && echo "--" || vct_do_ping $MGMT  | grep avg | awk -F' = ' '{print $2}' | awk -F'/' '{print $1}')"

	printf "%-4s %-8s %-39s %-5s  %-22s %-5s\n" $ID $STATE $IP ${RESCUE_DELAY:---} $MGMT ${MGMT_DELAY:---}
    done
    
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
#	local VCRD_PATH="${VCT_SYS_DIR}/${VCT_NODE_TEMPLATE_NAME}-rd${VCRD_ID}.${VCT_NODE_TEMPLATE_TYPE}"
	local VCRD_PATH="${VCT_SYS_DIR}/rd${VCRD_ID}.${VCT_NODE_TEMPLATE_TYPE}"

	virsh -c qemu:///system dominfo $VCRD_NAME 2>/dev/null && \
	    err $FUNCNAME "Domain name=$VCRD_NAME already exists"

	[ -f $VCRD_PATH ] && \
	    echo "Removing existing rootfs=$VCRD_PATH" >&2 && rm -f $VCRD_PATH


        local VCRD_FW_NAME="$( echo $VCT_SERVER_NODE_IMAGE_NAME | sed s/NODE_ID/$(( 16#${VCRD_ID} ))/ )"
        local FW_PATH="${VCT_SYS_DIR}/${VCRD_FW_NAME}"
        if ! [ -f $FW_PATH ]; then
	    err $FUNCNAME "Missing firmware=$FW_PATH for rd-id=$VCRD_ID"
	fi

	local FW_URL="file://${FW_PATH}"
	local FW_COMP=$( ( echo $FW_URL | grep -e "\.tgz$" >/dev/null && echo "tgz" ) ||\
                         ( echo $FW_URL | grep -e "\.tar\.gz$" >/dev/null && echo "tar.gz" ) ||\
                         ( echo $FW_URL | grep -e "\.gz$" >/dev/null && echo "gz" ) )
	    
	local FW_TYPE=$(echo $FW_URL | awk -F"$FW_COMP" '{print $1}' | awk -F'.' '{print $(NF-1)}')
	local FW_NAME=$(echo $FW_URL | awk -F'/' '{print $(NF)}' | awk -F".${FW_TYPE}.${FW_COMP}" '{print $1}')
	local FW_SITE=$(echo $FW_URL | awk -F"${FW_NAME}.${FW_TYPE}.${FW_COMP}" '{print $1}')

	( [ $FW_TYPE = "vmdk" ] || [ $FW_TYPE = "raw" ] || [ $FW_TYPE = "img" ] ) ||\
            err $FUNCNAME "Non-supported fs template type $FW_TYPE"

	[ "$FW_URL" = "${FW_SITE}${FW_NAME}.${FW_TYPE}.${FW_COMP}" ] ||\
            err $FUNCNAME "Invalid $FW_URL != ${FW_SITE}${FW_NAME}.${FW_TYPE}.${FW_COMP}"
	    
	if ! install_url  $FW_URL $FW_SITE $FW_NAME.$FW_TYPE $FW_COMP $VCT_SYS_DIR $VCRD_PATH install ; then
	    err $FUNCNAME "Installing $VCT_NODE_TEMPLATE_URL to $VCRD_PATH failed"
	fi


        # Enlarge the node image to the configured size if smaller.
        if [ "$VCT_NODE_IMAGE_SIZE_MiB" ]; then
            # With other template types we cannot even figure out image size.
            if [ "$VCT_NODE_TEMPLATE_TYPE" != "img" ]; then
                err $FUNCNAME "Unsupported template type $VCT_NODE_TEMPLATE_TYPE while enlarging $VCRD_PATH"
            fi

            local IMAGE_SIZE_B
            IMAGE_SIZE_B=$(stat -c %s "$VCRD_PATH")

            if [ $IMAGE_SIZE_B -lt $((VCT_NODE_IMAGE_SIZE_MiB * 1024 * 1024)) ]; then
                dd if=/dev/zero of="$VCRD_PATH" bs=1M count=0 seek=$VCT_NODE_IMAGE_SIZE_MiB 2>&1\
                    || err $FUNCNAME "Failed to enlarge $VCRD_PATH"
            fi
        fi

	local VCRD_NETW=""
	local BRIDGE=
	for BRIDGE in $VCT_BRIDGE_PREFIXES; do

	    local BR_NAME=

	    echo $BRIDGE | grep -e "^VCT_BR[0-f][0-f]$" >/dev/null || \
		err $FUNCNAME "Invalid VCT_BRIDGE_PREFIXES naming convention: $BRIDGE"

	    if BR_NAME=$( variable_check ${BRIDGE}_NAME soft 2>/dev/null ); then

		local BR_MODEL=$( variable_check ${BRIDGE}_MODEL soft 2>/dev/null || \
		    echo "${VCT_INTERFACE_MODEL}" ) 
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

	local TEMPLATE_TYPE=$( [ "$VCT_NODE_TEMPLATE_TYPE" = "img" ] && echo "raw" || echo "$VCT_NODE_TEMPLATE_TYPE" )
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

        local VCRD_NAME="${VCT_RD_NAME_PREFIX}${VCRD_ID}"

        if ! ( [ -f $VCT_NODE_MAC_DB  ]  && grep -e "^$VCRD_ID" $VCT_NODE_MAC_DB >&2 || virsh -c qemu:///system dominfo $VCRD_NAME | grep -e "^State:" | grep "running" >/dev/null ); then
            err $FUNCNAME "$VCRD_NAME not running"
        fi

	local MAC=$( vct_node_get_mac $VCRD_ID )
	local IP=$( vct_node_get_ip_from_db $VCRD_ID )
        local IPV6_RESCUE=${VCT_BR00_V6_RESCUE2_PREFIX64}:$( eui64_from_mac $MAC )
        local COUNT=0
        local COUNT_MAX=60
	[ -z "$IP" ] && IP=$IPV6_RESCUE

        while [ "$COUNT" -le $COUNT_MAX ]; do 

            vct_do_ping $IP >/dev/null && break
            
            [ "$COUNT" = 0 ] && \
                echo -n "Waiting for $VCRD_ID to listen on $IP (frstboot may take upto 40 secs)" || \
                echo -n "."

            COUNT=$(( $COUNT + 1 ))
        done

        [ "$COUNT" = 0 ] || \
            echo

        [ "$COUNT" -le $COUNT_MAX ] || \
            err $FUNCNAME "Failed connecting to node=$VCRD_ID via $IP"
        
        echo > $VCT_KEYS_DIR/known_hosts

        if [ "$COMMAND" ]; then
            ssh $VCT_SSH_OPTIONS root@$IP ". /etc/profile > /dev/null; $@"
        else
            ssh $VCT_SSH_OPTIONS root@$IP
        fi

    done
}


vct_node_scp() {
    local VCRD_ID_RANGE=$1
    local VCRD_ID=

    shift
    local WHAT="$@"

    for VCRD_ID in $( vcrd_ids_get $VCRD_ID_RANGE ); do

	local VCRD_NAME="${VCT_RD_NAME_PREFIX}${VCRD_ID}"

	if ! ( [ -f $VCT_NODE_MAC_DB  ]  && grep -e "^$VCRD_ID" $VCT_NODE_MAC_DB >&2 || virsh -c qemu:///system dominfo $VCRD_NAME | grep -e "^State:" | grep "running" >/dev/null ); then
	    err $FUNCNAME "$VCRD_NAME not running"
	fi
	
	local IP=$( vct_node_get_ip_from_db $VCRD_ID )
	local MAC=$( vct_node_get_mac $VCRD_ID )
	local IPV6_RESCUE=${VCT_BR00_V6_RESCUE2_PREFIX64}:$( eui64_from_mac $MAC )
	local COUNT_MAX=60
	local COUNT=

	[ -z "$IP" ] && IP="$IPV6_RESCUE"
	local IS_IPV6=$(echo $IP | grep -e ":" -c )
	
	COUNT=0
	while [ "$COUNT" -le $COUNT_MAX ]; do 

	    vct_do_ping $IP >/dev/null && break
	    
	    [ "$COUNT" = 0 ] && echo -n "Waiting for $VCRD_ID on $IP (frstboot may take upto 40 secs)" >&2 || echo -n "." >&2

	    COUNT=$(( $COUNT + 1 ))
	done

	#echo >&2
	# [ "$COUNT" = 0 ] || echo >&2
	[ "$COUNT" -le $COUNT_MAX ] || err $FUNCNAME "Failed ping6 to node=$VCRD_ID via $IP"

	COUNT=0
	while [ "$COUNT" -le $COUNT_MAX ]; do 

	    echo > $VCT_KEYS_DIR/known_hosts
	    ssh $VCT_SSH_OPTIONS root@$IP "exit" 2>/dev/null && break
	    sleep 1
	    
	    [ "$COUNT" = 0 ] && echo -n "Waiting for $VCRD_ID to accept ssh..." >&2 || echo -n "." >&2

	    COUNT=$(( $COUNT + 1 ))
	done
	#echo >&2
	# [ "$COUNT" = 0 ] || echo >&2
	[ "$COUNT" -le $COUNT_MAX ] || err $FUNCNAME "Failed ssh to node=$VCRD_ID via $IP"

	echo > $VCT_KEYS_DIR/known_hosts

	if [ $IS_IPV6 -ne 0 ]; then
		scp $VCT_SSH_OPTIONS $( echo $WHAT | sed s/remote:/root@\[$IP\]:/ ) 2>/dev/null
	else
		scp $VCT_SSH_OPTIONS $( echo $WHAT | sed s/remote:/root@$IP:/ )  2>/dev/null
	fi

    done
}

vct_node_scp_cns() {
    local VCRD_ID=$1; check_rd_id $VCRD_ID quiet
    
    local CNS_FILES_DIR="$VCT_DIR/../../packages/confine/confine-system/files"
    local LXC_FILES_DIR="$VCT_DIR/../../packages/confine/lxc/files"

#  This is automatic but slow:
#    for f in $(cd $CNS_FILES_DIR && find | grep -v "/etc/config"); do
#	echo $f
#	[ -f $CNS_FILES_DIR/$f ] && \
#	    vct_node_scp $VCRD_ID remote:/$f $CNS_FILES_DIR/$f || true
#    done

#  This is manual but faster:
    vct_node_scp $VCRD_ID remote:/usr/lib/lua/confine/*.lua   $CNS_FILES_DIR/usr/lib/lua/confine/
    vct_node_scp $VCRD_ID remote:/usr/sbin/confine.*          $CNS_FILES_DIR/usr/sbin/
    vct_node_scp $VCRD_ID remote:/home/lxc/scripts/*-confine.sh    $CNS_FILES_DIR/home/lxc/scripts/
    vct_node_scp $VCRD_ID remote:/etc/config/confine-defaults $CNS_FILES_DIR/etc/config/
    vct_node_scp $VCRD_ID remote:/etc/init.d/confine          $CNS_FILES_DIR/etc/init.d/
    vct_node_scp $VCRD_ID remote:/etc/confine-ebtables.lst    $CNS_FILES_DIR/etc/
    vct_node_scp $VCRD_ID remote:/usr/sbin/lxc.*              $LXC_FILES_DIR/usr/sbin/
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
	     virsh -c qemu:///system list --all 2>/dev/null | grep $VCRD_NAME  | grep "shut off" >/dev/null; then

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


vct_build_node_base_image() {
    local CPUS="$(cat /proc/cpuinfo  | grep processor | tail -1 | awk '{print $3}')"
    local BUILD_PATH="$VCT_DIR/../.."
    local IMAGE_NAME="vct-node-base-image-build.img.gz"
    
    cd $BUILD_PATH &&\
    make confclean &&\
    make J=$CPUS &&\
    ln -fs $BUILD_PATH/images/CONFINE-owrt-current.img.gz $VCT_DL_DIR/$IMAGE_NAME &&\
    echo &&\
    echo "The new image is available via the controller portal at:" &&\
    echo "administration->firmware->configuration->Image as:" &&\
    echo "$IMAGE_NAME" || {
	rm -f $VCT_DL_DIR/$IMAGE_NAME
	echo
	echo "Building new image failed!"
	return 1
    }
}


vct_build_sliver_exp_data() {
    local EXP_PATH=$1
    local EXP_TAIL="$(echo $EXP_PATH | sed 's/\/$//' | awk -F'/' '{print $NF}')"
    local EXP_NAME="vct-exp-data-build-$EXP_TAIL.tgz"

    [ -d $EXP_PATH ] &&\
    tar -czvf $VCT_DL_DIR/$EXP_NAME  --exclude=*~ --numeric-owner --group=root --owner=root -C $EXP_PATH . &&\
    echo &&\
    echo "The slice/sliver exp-data archive is available via the controller portal at:" &&\
    echo "slices->[select slice]->exp_data as:" &&\
    echo "$EXP_NAME" || {
	rm -f $VCT_DL_DIR/$EXP_NAME
	echo
	echo "Building new slice/sliver exp-data failed!"
	return 1
    }

}

vct_build_sliver_template() {
    local OS_TYPE=$1

    VCT_SLICE_TEMPLATE_PASSWD="confine"

    mkdir -p $VCT_VIRT_DIR/sliver-templates

    if echo $OS_TYPE | grep "debian" >/dev/null; then
	local TMPL_DIR=$VCT_VIRT_DIR/sliver-templates/debian
	local TMPL_NAME=vct-sliver-template-build-debian
	vct_sudo rm -rf $TMPL_DIR
	mkdir -p $TMPL_DIR
	

	if ! [ "LXCDEBCONFIG_SLIVER_TEMPLATE" ]; then

	    # Documentation: https://wiki.confine-project.eu/soft:debian-template

	    VCT_LXC_PACKAGES_DIR="/usr/share/lxc/packages"
	    VCT_LIVEDEB_CFG=$VCT_DIR/templates/debian,wheezy,i386.cfg
	    VCT_LIVEDEB_PACKAGE_URL="http://live.debian.net/files/4.x/packages/live-debconfig/4.0~a27-1/live-debconfig_4.0~a27-1_all.deb"
	    VCT_LIVEDEB_PACKAGE_SHA="7a7c154634711c1299d65eb5acb059eceff7d3328b5a34030b584ed275dea1fb"
	    VCT_LIVEDEB_PACKAGE_DEB="$(echo $VCT_LIVEDEB_PACKAGE_URL | awk -F'/' '{print $NF}')"
	    [ -f $VCT_LXC_PACKAGES_DIR/$VCT_LIVEDEB_PACKAGE_DEB ] && [ "$(sha256sum $VCT_LXC_PACKAGES_DIR/$VCT_LIVEDEB_PACKAGE_DEB |awk '{print $1}' )" = "$VCT_LIVEDEB_PACKAGE_SHA" ] || {
		vct_sudo rm -f $VCT_LXC_PACKAGES_DIR/$VCT_LIVEDEB_PACKAGE_DEB
		vct_sudo mkdir -p $VCT_LXC_PACKAGES_DIR
		vct_sudo wget -P $VCT_LXC_PACKAGES_DIR $VCT_LIVEDEB_PACKAGE_URL
	    }
	    vct_sudo lxc-create -t debian -n $TMPL_NAME -B --dir $TMPL_DIR  -- --preseed-file=$VCT_LIVEDEB_CFG
	    

	elif [ "DEBOOTSTRAP_SLIVER_TEMPLATE" ]; then

	    # Inspired by: http://www.wallix.org/2011/09/20/how-to-use-linux-containers-lxc-under-debian-squeeze/

	    vct_sudo debootstrap --verbose --variant=minbase --arch=i386 --include $VCT_SLIVER_TEMPLATE_DEBIAN_PACKAGES wheezy $TMPL_DIR/rootfs http://ftp.debian.org/debian
	    vct_sudo rm -f $TMPL_DIR/rootfs/var/cache/apt/archives/*.deb
	    vct_sudo rm -f $TMPL_DIR/rootfs/dev/shm
	    vct_sudo mkdir -p $TMPL_DIR/rootfs/dev/shm
	    
	    vct_sudo chroot $TMPL_DIR/rootfs /usr/sbin/update-rc.d -f umountfs remove
	    vct_sudo chroot $TMPL_DIR/rootfs /usr/sbin/update-rc.d -f hwclock.sh remove
	    vct_sudo chroot $TMPL_DIR/rootfs /usr/sbin/update-rc.d -f hwclockfirst.sh remove

#	    vct_sudo chroot $TMPL_DIR/rootfs /sbin/insserv -fr checkroot.sh           || true
#	    vct_sudo chroot $TMPL_DIR/rootfs /sbin/insserv -fr checkfs.sh             || true
#	    vct_sudo chroot $TMPL_DIR/rootfs /sbin/insserv -fr mtab.sh                || true
#	    vct_sudo chroot $TMPL_DIR/rootfs /sbin/insserv -fr checkroot-bootclean.sh || true
	    vct_sudo chroot $TMPL_DIR/rootfs /sbin/insserv -fr hwclockfirst.sh        || true
	    vct_sudo chroot $TMPL_DIR/rootfs /sbin/insserv -fr hwclock.sh             || true
	    vct_sudo chroot $TMPL_DIR/rootfs /sbin/insserv -fr kmod                   || true
	    vct_sudo chroot $TMPL_DIR/rootfs /sbin/insserv -fr module-init-tools      || true
#	    vct_sudo chroot $TMPL_DIR/rootfs /sbin/insserv -fr mountall.sh            || true
	    vct_sudo chroot $TMPL_DIR/rootfs /sbin/insserv -fr mountkernfs.sh         || true
	    vct_sudo chroot $TMPL_DIR/rootfs /sbin/insserv -fr umountfs               || true
	    vct_sudo chroot $TMPL_DIR/rootfs /sbin/insserv -fr umountroot             || true
	    
	    vct_sudo_sh "cat <<EOF >> $TMPL_DIR/rootfs/etc/ssh/sshd_config
PasswordAuthentication no
EOF
"
	    vct_sudo chroot $TMPL_DIR/rootfs passwd<<EOF
confine
confine
EOF

	    vct_sudo_sh "cat <<EOF > $TMPL_DIR/rootfs/etc/inittab 
id:2:initdefault:

si::sysinit:/etc/init.d/rcS

#~:S:wait:/sbin/sulogin

l0:0:wait:/etc/init.d/rc 0
l1:1:wait:/etc/init.d/rc 1
l2:2:wait:/etc/init.d/rc 2
l3:3:wait:/etc/init.d/rc 3
l4:4:wait:/etc/init.d/rc 4
l5:5:wait:/etc/init.d/rc 5
l6:6:wait:/etc/init.d/rc 6

z6:6:respawn:/sbin/sulogin

1:2345:respawn:/sbin/getty 38400 console

# new from vctc:
c1:12345:respawn:/sbin/getty 38400 tty1 linux
c2:12345:respawn:/sbin/getty 38400 tty2 linux
c3:12345:respawn:/sbin/getty 38400 tty3 linux
c4:12345:respawn:/sbin/getty 38400 tty4 linux

p0::powerfail:/sbin/init 0
p6::ctrlaltdel:/sbin/init 6

EOF
"

	    vct_sudo tar -czvf $VCT_DL_DIR/$TMPL_NAME.tgz --numeric-owner --directory $TMPL_DIR/rootfs .

	    echo 
            echo "The slice/sliver template image is available via the controller portal at:"
            echo "Slices->Templates->[select template]->image as:"
	    echo $TMPL_NAME.tgz
	    echo "You may have to delete and recreate the template to consider the new image"
	    echo

	fi
	


    elif echo $OS_TYPE | grep "openwrt" >/dev/null; then

	echo "Sorry, not yet implemented"

    fi
    return 1
}


vct_help() {
    echo "usage..."
    cat <<EOF

    vct_help

    vct_system_install [OVERRIDE_DIRECTIVES]    : install vct system requirements
    vct_system_init                             : initialize vct system on host
    vct_system_cleanup [flush]                  : revert vct_system_init
                                                  and optionally remove testbed data
    vct_system_purge                            : purge vct installation


    Node Management Functions
    -------------------------

    vct_node_info      [NODE_SET]               : summary of existing domain(s)
    vct_node_create    <NODE_SET>               : create domain with given NODE_ID
    vct_node_start     <NODE_SET>               : start domain with given NODE_ID
    vct_node_stop      <NODE_SET>               : stop domain with given NODE_ID
    vct_node_remove    <NODE_SET>               : remove domain with given NODE_ID
    vct_node_console   <NODE_ID>                : open console to running domain

    vct_node_ssh       <NODE_SET> ["COMMANDS"]  : ssh connect via recovery IPv6
    vct_node_scp       <NODE_SET> <SCP_ARGS>    : copy via recovery IPv6
    vct_node_mount     <NODE_SET>
    vct_node_unmount   <NODE_SET>

    Build Functions
    ---------------

    vct_build_node_base_image                   : Build node image from scratch 
    vct_build_sliver_exp_data <EXP_DIR>         : Build sliver exp_data from dir


    Argument Definitions
    --------------------

    OVERRIDE_DIRECTIVES:= comma seperated list of directives:  node,server,keys
    NODE_ID:=             node id given by a 4-digit lower-case hex value (eg: 0a12)
    NODE_SET:=            node set as: 'all', NODE_ID, NODE_ID-NODE_ID (0001-0003)
    COMMANDS:=            Commands to be executed on node
    SCP_ARGS:=            MUST include 'remote:' which is substituted by 'root@[IPv6]:'
    EXP_DIR:=             a directoy name that must exist in utis/vct/experiments
    OS_TYPE:=             either debian or openwrt

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
	vct_system_purge)           $CMD "$@";;

	vct_node_info)              $CMD "$@";;
	vct_node_create)            $CMD "$@";;
	vct_node_start)             $CMD "$@";;
	vct_node_stop)              $CMD "$@";;
	vct_node_remove)            $CMD "$@";;
	vct_node_console)           $CMD "$@";;
	vct_node_ssh)               $CMD "$@";;
	vct_node_scp)               $CMD "$@";;
	vct_node_scp_cns)           $CMD "$@";;

        vct_node_mount)             $CMD "$@";;
        vct_node_unmount)           $CMD "$@";;

        vct_build_node_base_image)  $CMD "$@";;
        vct_build_sliver_exp_data)  $CMD "$@";;
        vct_build_sliver_template)  $CMD "$@";;

	*) vct_help;;
    esac

fi

#echo "successfully finished $0 $*" >&2
