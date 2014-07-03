#!/bin/sh

echo "Disabling uhttpd (for deferred startup by confine.lib daemon)"

/etc/init.d/uhttpd disable

