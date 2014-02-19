#!/bin/sh

# if /lxc is a directory 
[ ! -h "/lxc" ] && {
	echo "Pointing /lxc to /home/lxc"
	mkdir -p /home/lxc 2>/dev/null
	mv /lxc /lxc.backup
	ln -s /home/lxc /lxc
}

