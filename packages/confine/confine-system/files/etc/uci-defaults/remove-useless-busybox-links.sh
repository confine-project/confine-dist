#!/bin/sh

echo "Remove busybox links which are already installed as packet"

# remove useless busybox links:	     
[ -h /bin/ping ] && [ -x /usr/bin/ping ] && rm /bin/ping
[ -h /bin/rm ] && [ -x /usr/bin/rm ] && rm /bin/rm

