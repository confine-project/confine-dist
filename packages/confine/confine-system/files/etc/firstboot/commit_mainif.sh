#!/bin/sh

count=0
stop=0
main_if=$( uci get confine.node.local_ifname )

# copy local_ifname to lxc interface names
echo "Configuring lxc for CONFINE..."

while [ $stop == 0 ]
do
        uci -q get lxc.@container[$count].if00_name >/dev/null
        stop=$?

        if [ $stop == 0 ]
        then
                uci set lxc.@container[$count].if00_name=$main_if
        fi
        count=$((count+1))
done

uci commit lxc
cp /etc/config/lxc /etc/config/lxc.orig

# copy local_ifname to confine-defaults
echo "Configuring confine-defaults for CONFINE..."

uci set confine-defaults.system.local_ifname=$main_if
uci commit confine-defaults
