#!/bin/sh

# if /lxc is a directory and /home/lxc a link
[ ! -h "/lxc" ] && [ -h "/home/lxc" ] && {
	echo "Moving /lxc to /home/lxc"
	rm -f /home/lxc
	mv /lxc /home/
	ln -s /home/lxc /lxc
	}

