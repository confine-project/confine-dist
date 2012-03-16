#!/bin/sh

echo "Configuring network for CONFINE..."


uci del network.lan

uci set network.local=interface
uci set network.local.type=bridge
uci set network.local.proto=none
uci set network.local.ifname=eth0
uci set network.local.auto=1
#uci set network.local.ipaddr=
#uci set network.local.netmask=
uci set network.local.macaddr=$( ip link show dev eth0 | grep "link/ether" | awk '{print $2}' )

uci set network.local_ipv4_rescue_ip=alias
uci set network.local_ipv4_rescue_ip.interface=local
uci set network.local_ipv4_rescue_ip.proto=static
uci set network.local_ipv4_rescue_ip.ipaddr=192.168.241.241  # see VCT_RD_RESCUE_V4_IP
uci set network.local_ipv4_rescue_ip.netmask=255.255.255.252 # see VCT_RD_RESCUE_V4_PL

uci commit

mkdir -p /etc/uci-originals
cp /etc/uci-defaults/network.sh /etc/uci-originals/

