--[[



]]--


--- CONFINE ssh abstraction library.
module( "confine.ssh", package.seeall )


local util   = require "luci.util"
local tools  = require "confine.tools"
local dbg    = tools.dbg


function cb_node_group( sys_conf, action, out_node, path, key, oldval, newval )
	dbg("cb_node_group()... (TBD)")
end

