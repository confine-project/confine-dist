#!/bin/sh

echo "Check/remove installed uhttpd certs"

if ! uci get confine.node.https_cert; then
    mv -f /etc/uhttpd.crt     /etc/uhttpd.crt.der.orig
    mv -f /etc/uhttpd.key     /etc/uhttpd.key.der.orig
    mv -f /etc/uhttpd.crt.pem /etc/uhttpd.crt.pem.orig
    mv -f /etc/uhttpd.key.pem /etc/uhttpd.key.pem.orig

fi

uci commit uhttpd



