#!/bin/sh

echo "Configuring network for CONFINE..."


uci del network.lan

uci set network.local=interface
uci set network.local.type=bridge
uci set network.local.proto=none
uci set network.local.ifname=eth0
uci set network.local.macaddr=$( ip link show dev eth0 | grep "link/ether" | awk '{print $2}' )

uci set network.recovery=alias
uci set network.recovery.interface=local
uci set network.recovery.proto=static
uci set network.recovery.ipaddr=192.168.241.130  # see VCT_RD_RESCUE_V4_IP
uci set network.recovery.netmask=255.255.255.128 # see VCT_RD_RESCUE_V4_PL

uci commit

mkdir -p /etc/uci-originals
cp /etc/uci-defaults/network.sh /etc/uci-originals/

