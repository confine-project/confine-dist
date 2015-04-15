#!/bin/sh
if confine.disk-parted >> /root/confine.disk-parted.log 2>&1; then
	reboot
	# stop this script until reboot is finished
	sleep 5
	# due to /etc/init.d/boot logic, this script will NOT be removed 
	# before the one after the next reboot where confine.disk-parted 
	# returns false. But we dont want more uci-defaults scripts now!
	reboot -f
fi
