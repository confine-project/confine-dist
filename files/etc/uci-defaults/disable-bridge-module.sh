#!/bin/sh
# Disable bridge module load on boot

rm -rf /etc/modules.d/09-llc /etc/modules.d/10-stp /etc/modules.d/11-bridge
