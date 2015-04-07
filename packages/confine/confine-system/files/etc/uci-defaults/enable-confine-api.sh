#!/bin/sh

echo "Enable IPv6 for uhttpd"

cp /etc/config/uhttpd /etc/config/uhttpd.orig

uci set uhttpd.main.listen_http='0.0.0.0:80 [::]:80'
uci set uhttpd.main.listen_https='0.0.0.0:443 [::]:443'

echo "Enable confine CGI API"

uci set uhttpd.main.lua_prefix=/confine/api
uci set uhttpd.main.lua_handler=/usr/lib/lua/confine/api.lua
