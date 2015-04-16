#!/bin/bash

port=22222
nl80211_set=0

for interf in `uci -q get confine.node.rd_if_iso_parents`
do
        if [[ $interf == wlan* ]]
        then
                if [ "$nl80211_set" == "0" ]
                then
                        uci -q >/dev/null -c /etc/config/ add dlep_proxy nl80211_listener
                        nl80211_set=1
                fi
                uci -q -c /etc/config/ add_list dlep_proxy.@nl80211_listener[-1].if=$interf
        else
                uci -q >/dev/null -c /etc/config/ add dlep_proxy dlep_router
                uci -q -c /etc/config/ set dlep_proxy.@dlep_router[-1].name=$interf
        fi

        uci -q >/dev/null -c /etc/config/ add dlep_proxy dlep_radio
        uci -q -c /etc/config/ set dlep_proxy.@dlep_radio[-1].name=$interf
        uci -q -c /etc/config/ set dlep_proxy.@dlep_radio[-1].not_proxied=true
        uci -q -c /etc/config/ set dlep_proxy.@dlep_radio[-1].proxied=false
        uci -q -c /etc/config/ set dlep_proxy.@dlep_radio[-1].datapath_if=br-internal
        uci -q -c /etc/config/ set dlep_proxy.@dlep_radio[-1].discovery_port=$port
        uci -q -c /etc/config/ set dlep_proxy.@dlep_radio[-1].session_port=$port

        port=$(( $port + 1 ))
done
