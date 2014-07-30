#!/bin/sh

# Author: Henning Rogge, Fraunhofer FKIE
# Date: 16.07.2014
# Task: Log onto sliver or execute a command on a sliver. Needs only slice ID
#	and sliver number. Slivers are counted starting from 0 in the sequential
#	order of the node IDs.

PATH="/home/vct/confine-dist/ns3/utils/get_sliver_ips.sh"

if [ "$#" -lt "2" ]
then
	echo "ssh_sliver.sh <slice-id> <sliver-index>"
	echo "ssh_sliver.sh <slice-id> <sliver-index> <command>"
	exit 1
fi

i=0
for ip in `${PATH} ${1}`
do
	if [ "${i}" = "${2}" ]
	then
		ssh -i /var/lib/vct/keys/id_rsa root@${ip} ${3}
		exit 0
	fi
	i=$((i+1))
done

i=$((i-1))
echo "Illegal sliver index, must be between 0 and ${i}"
exit 1
