#!/bin/sh
echo "Firstboot executed, rebooting system in 5 seconds"
sleep 5
echo "$(date) zzz-reboot" >> /root/confine.daemon-starts
reboot
echo "$(date) zzz-reboot-000" >> /root/confine.daemon-starts
sleep 5
echo "$(date) zzz-reboot-005" >> /root/confine.daemon-starts
sleep 5
echo "$(date) zzz-reboot-010" >> /root/confine.daemon-starts
sleep 100
echo "$(date) zzz-reboot-110" >> /root/confine.daemon-starts
