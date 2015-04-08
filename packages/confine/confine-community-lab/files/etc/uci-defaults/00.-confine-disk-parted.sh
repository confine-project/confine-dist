#!/bin/sh
if confine.disk-parted >> /root/confine.disk-parted.log 2>&1; then
	reboot
	# stop this script until reboot is finished
	sleep 300
fi
