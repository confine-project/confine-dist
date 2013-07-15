#!/bin/sh

echo "Enable confine CGI API"

# FIXME adding this config prevents uhttpd from automatically starting during boot :(
#uci set uhttpd.main.lua_prefix=/confine/api
#uci set uhttpd.main.lua_handler=/usr/lib/lua/confine/api.lua

#uci commit uhttpd
