#!/bin/sh

# This script disables all firewall settings.
# To ensure that automatically created firewall rules do not block confine-sliver
# networking; someting we observed with the openWrt firewall package.
# If you are building your own confine community, then disable this 
# script or start your own confine-community-package

/etc/init.d/firewall disable
/etc/init.d/firewall stop

rm /etc/config/firefall
touch /etc/config/firewall

chmod 000 /etc/init.d/firewall
