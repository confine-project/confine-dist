#!/bin/sh

port=22222

for interf in `uci -q get confine.node.rd_if_iso_parents`
do
	uci -q >/dev/null -c /etc/config/ add dlep_proxy dlep_radio
	uci -q -c /etc/config/ set dlep_proxy.@dlep_radio[-1].name=$interf
	uci -q -c /etc/config/ set dlep_proxy.@dlep_radio[-1].not_proxied=true
	uci -q -c /etc/config/ set dlep_proxy.@dlep_radio[-1].proxied=false
	uci -q -c /etc/config/ set dlep_proxy.@dlep_radio[-1].datapath_if=br-internal
	uci -q -c /etc/config/ set dlep_proxy.@dlep_radio[-1].discovery_port=$port
	uci -q -c /etc/config/ set dlep_proxy.@dlep_radio[-1].session_port=$port

	uci -q >/dev/null -c /etc/config/ add dlep_proxy dlep_router
	uci -q -c /etc/config/ set dlep_proxy.@dlep_router[-1].name=$interf

	port=$(( $port + 1 ))
done

uci -q -c /etc/config commit dlep_proxy
