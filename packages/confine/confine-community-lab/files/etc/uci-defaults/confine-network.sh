#!/bin/sh

echo "Configuring network for CONFINE..."


uci del network.lan
uci commit network

uci del network.wan
uci commit network

main_if=$( uci get confine.node.local_ifname )

uci set network.local=interface
uci set network.local.type=bridge
uci set network.local.proto=dhcp
uci set network.local.ifname=$main_if
#uci set network.local.macaddr=$( ip link show dev $main_if | grep "link/ether" | awk '{print $2}' )

uci set network.recovery1=interface
uci set network.recovery1.ifname=br-local
uci set network.recovery1.proto=static
uci set network.recovery1.ip6addr=fdbd:e804:6aa9:0001::2/64
uci set network.recovery1.ipaddr=192.168.241.130
uci set network.recovery1.netmask=255.255.255.128

uci set network.recovery2=interface
uci set network.recovery2.ifname=br-local
uci set network.recovery2.proto=static
uci set network.recovery2.ip6addr=fdbd:e804:6aa9:0002:$( confine.lib eui64_from_link $main_if soft )/64

uci commit network
