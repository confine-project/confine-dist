--[[



]]--


--- CONFINE processing rules.
module( "confine.rules", package.seeall )


local ctree    = require "confine.tree"
local data    = require "confine.data"
local tools   = require "confine.tools"
--local sliver  = require "confine.sliver"
--local ssh     = require "confine.ssh"
--local tinc    = require "confine.tinc"
--local node    = require "confine.node"
--local system  = require "confine.system"

local dbg     = tools.dbg
local null    = data.null




function cb(sys_conf, action, task, cb_tasks, out_node, path, key, oldval, newval )

	dbg("%s %-22s %-40s %s => %s", action, task, path..key,
		data.val2string(oldval):gsub("\n",""):sub(1,30),
		data.val2string(newval):gsub("\n",""):sub(1,30))

	if cb_tasks[task] then
		
		local finval = cb_tasks[task](sys_conf, action, out_node, path, key, oldval, newval)
		
		if task ~= "CB_NOP" and task ~= "CB_COPY" then			
			dbg("%s %-22s %-40s   ===> %s", action, task, path..key, data.val2string(finval):gsub("\n",""):sub(1,30))
		end

		--if task ~= "CB_NOP" and finval == nil then
		--	node.set_node_state( sys_conf, out_node, node.STATE.setup )
		--end
		
		return finval
		
	else
		dbg("cb() undefined cb_task=%s", task)
	end	
	
--	assert(sliver_obj.local_template.local_arch == own_node_arch,
--       "Sliver_arch=%q does not match local_arch=%q!"
--	   %{ sliver_obj.local_template.arch, own_node_arch })

end



dflt_cb_tasks = {
	["CB_TEST"] 	      	= function( sys_conf, action, out_node, path, key, oldval, newval )
					dbg("cb_test()")
					ctree.dump(newval)
					return oldval
				end,
	["CB_NOP"] 	      	= function( sys_conf, action, out_node, path, key, oldval, newval )
					return oldval
				end,
	["CB_COPY"] 	      	= function( sys_conf, action, out_node, path, key, oldval, newval )
					return ctree.copy_path_val( action, out_node, path, key, oldval, newval)
				end,

	["CB_ADD_DEL_EMPTY_TABLE"] = function( sys_conf, action, out_node, path, key, oldval, newval )
					return ctree.add_del_empty_table( action, out_node, path, key, oldval, newval)
				end
}

