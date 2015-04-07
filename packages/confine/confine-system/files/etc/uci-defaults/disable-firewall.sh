#!/bin/sh
/etc/init.d/firewall disable
/etc/init.d/firewall stop

rm /etc/config/firefall
touch /etc/config/firewall
