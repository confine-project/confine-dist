#!/bin/sh

echo "Configuring network for CONFINE..."
uci set network.wan=interface
uci set network.wan.type=bridge
uci set network.wan.ifname=eth0
uci set network.wan.proto=dhcp

uci set network.lan=interface
uci set network.lan.type=bridge
uci set network.lan.ifname=eth1
uci set network.lan.proto=dhcp

uci commit

