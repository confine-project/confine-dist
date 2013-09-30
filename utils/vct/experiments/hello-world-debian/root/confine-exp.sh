#!/bin/bash

#set -x


PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

get_json_value() {
    local path="$1"
    local jsdata="${2:--}"
    cat "$jsdata" | /root/JSON.sh -b | grep "$path" | sed 's/^\[.*\]\t//' |sed 's/^"//' |sed 's/"$//'
}

get_json_members() {
    local path="$1"
    local jsdata="${2:--}"
    cat "$jsdata" | /root/JSON.sh -b | grep "$path" | sed 's/\t.*$//'
}

get_json_url_value() {
    local path="$1"
    local url="$2"
    wget -O- $url 2>/dev/null | get_json_value "$path"
}

get_json_url_members() {
    local path="$1"
    local url="$2"
    wget -O- $url 2>/dev/null | get_json_members "$path"
}

experiment() {
    local log=$1

    echo "new cycle $(date)" >> $log

    if ! which ping >/dev/null    ; then apt-get update && apt-get install iputils-ping || { echo "failed installing iputils-ping" >> $log; return 1 ; } ; fi
    if ! which wget >/dev/null    ; then apt-get update && apt-get install wget || { echo "failed installing wget" >> $log; return 1 ; } ; fi
    if ! which killall >/dev/null ; then apt-get update && apt-get install psmisc || { echo "failed installing psmisc" >> $log; return 1 ; } ; fi
    if ! [ -f /root/JSON.sh ]     ; then wget --no-check-certificate -O /root/JSON.sh https://raw.github.com/dominictarr/JSON.sh/master/JSON.sh || { echo "failed installing JSON.sh" >> $log; return 1 ; } ; fi
    if ! [ -x /root/JSON.sh ]     ; then chmod u+x /root/JSON.sh || { return 1 ; } ; fi

    local x s i a
    local MGMT_IPV6_PREFIX="$( get_json_url_value '\["testbed_params","mgmt_ipv6_prefix"\]' http://[fdbd:e804:6aa9::1]/confine/api 2>/dev/null )"
    local MGMT_IPV6_SERVER="$( echo $MGMT_IPV6_PREFIX | sed 's/\/48/2/' )"
    local MY_SLICE_ID=$(cat /confine/slice-id)
    local MY_SLIVER_URLS="$( get_json_url_value '\["slivers",[0-9]*,"uri"\]' http://[$MGMT_IPV6_SERVER]/api/slices/$MY_SLICE_ID 2>/dev/null )"
    local MY_NODE_URLS="$( for x in $MY_SLIVER_URLS; do get_json_url_value '\["node","uri"\]' $x 2>/dev/null; done )"
    local MGMT_IPV6_NODES="$( for x in $MY_NODE_URLS; do get_json_url_value '\["mgmt_net","addr"\]' $x 2>/dev/null; done )"
    local MY_SLIVER_PUB4="$(
    for x in $MGMT_IPV6_NODES; do
	local NODE_SLIVER_URLS="$( get_json_url_value '\[[0-9]*,"uri"\]' http://[$x]/confine/api/slivers 2>/dev/null )"
	for s in $NODE_SLIVER_URLS; do
	    local NODE_SLIVER_JSON="$( wget -O- $s 2>/dev/null )"
	    if echo "$NODE_SLIVER_JSON" | get_json_value '\["slice","uri"\]' | grep "/slices/${MY_SLICE_ID}$" >/dev/null; then
		local NODE_SLIVER_INTERFACES="$( echo "$NODE_SLIVER_JSON" | get_json_members '\["interfaces",[0-9]*,"type"\]' 2>/dev/null |awk -F',' '{print $2}' )"
		for i in $NODE_SLIVER_INTERFACES; do
		    if [ "$( echo "$NODE_SLIVER_JSON" | get_json_value "\[\"interfaces\",$i,\"type\"\]" 2>/dev/null )" == "public4" ]; then
			echo "$NODE_SLIVER_JSON" | get_json_value "\[\"interfaces\",$i,\"ipv4_addr\"\]"
		    fi
		done
	    fi
	done
    done
)"

    for a in $MY_SLIVER_PUB4 ; do
	ping -c1 $a >> $log
    done
}

while true; do
    experiment $1
    sleep 10
done

