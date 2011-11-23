#!/bin/sh

echo "Configuring network for CONFINE..."
uci set network.wan=interface
uci set network.wan.ifname=eth1
uci set network.wan.proto=dhcp
uci commit

