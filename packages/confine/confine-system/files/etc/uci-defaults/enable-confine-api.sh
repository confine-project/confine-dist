#!/bin/sh

echo "Enable confine CGI API"

uci set uhttpd.main.lua_prefix=/confine/api
uci set uhttpd.main.lua_handler=/usr/lib/lua/confine/api.lua

uci commit uhttpd
