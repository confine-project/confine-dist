#!/bin/sh

echo "Configuring network for CONFINE..."
uci set network.wan=interface
uci set network.wan.ifname=eth1
uci set network.wan.proto=dhcp

uci set network.lan=interface
uci set network.lan.ifname=eth0
uci set network.lan.proto=static
uci set network.lan.ipaddr=192.168.0.1
uci set network.lan.netmask=255.255.255.0

uci commit

