#!/bin/sh
if confine.disk-parted > /root/confine.disk-parted.log 2>&1; then
	reboot
fi
