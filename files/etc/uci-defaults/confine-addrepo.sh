#!/bin/sh

echo "Replacing opkg.conf"

echo "
src/gz attitude_adjustment http://repo.confine-project.eu/x86/packages
dest root /
dest ram /tmp
lists_dir ext /var/opkg-lists
option overlay_root /overlay
" > /etc/opkg.conf
