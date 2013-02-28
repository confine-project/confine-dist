--[[



]]--

--- CONFINE sliver library.
module( "confine.sliver", package.seeall )


local util   = require "luci.util"
local tools  = require "confine.tools"
local dbg    = tools.dbg



function stop_slivers( sys_conf, sliver )
	dbg("stop_slivers() sliver=%s... (TBD)" %tostring(sliver))
end


function remove_slivers( sys_conf, sliver)
	stop_slivers( sys_conf, sliver )
	dbg("remove_slivers() sliver=%s... (TBD)" %tostring(sliver))
end

function start_slivers( sys_conf, sliver)
	stop_slivers( sys_conf, sliver )
	dbg("start_slivers() sliver=%s... (TBD)" %tostring(sliver))
end
