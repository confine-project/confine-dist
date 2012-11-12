--[[



]]--

--- CONFINE Tree traversal library.
module( "confine.sliver", package.seeall )


local util   = require "luci.util"
local tools  = require "confine.tools"
local dbg    = tools.dbg


function cb_remove_slivers( sys_conf, action, out_node, path, key, oldval, newval )
	dbg("cb_remove_slivers()... (TBD)")
end

