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




function cb2_nop( sys_conf, otree, ntree, path )
	if not sys_conf then return "cb2_nop" end
end

function cb2_log( sys_conf, otree, ntree, path )
	if not sys_conf then return "cb2_nop" end
	return true
end

function cb2_set( sys_conf, otree, ntree, path, begin, changed )
	
	if not sys_conf then return "cb2_set" end
	
	local old = ctree.get_path_val(otree,path)
	local new = ctree.get_path_val(ntree,path)
	local is_table = type(old)=="table" or type(new)=="table"
	
	if is_table and begin and ((not old or old==null) and new) then

		ctree.set_path_val(otree,path,{})
		
	elseif is_table and not begin and (old and (not new or new==null)) then

		ctree.set_path_val(otree,path,new)
		
	elseif not is_table and old ~= new then
		
		ctree.set_path_val(otree,path,new)
	end
	
	
end

function cb2( task, sys_conf, otree, ntree, path, begin, changed )
	
	if not sys_conf then return "cb2" end
	
	assert( type(otree)=="table" )
	assert( type(ntree)=="table" )
	
	local oldv = ctree.get_path_val(otree,path)
	local olds = data.val2string(oldv):gsub("\n",""):sub(1,30)
	local newv = ctree.get_path_val(ntree,path)
	local news = data.val2string(newv):gsub("\n",""):sub(1,30)
	local is_table = type(oldv)=="table" or type(newv)=="table"

	--if not is_table and (oldv ~= newv) then
	--	dbg( " %-15s %-45s %s => %s", task(), path, olds, news)
	--end

	local report = task( sys_conf, otree, ntree, path, begin, changed )
	
	local outv = ctree.get_path_val(otree,path)
	local outs = data.val2string(outv):sub(1,30)

	if oldv ~= outv or (oldv ~= newv and not is_table) or changed or report then
		dbg( " %s %-15s %-45s %s => %s ==> %s",
		    (is_table and (begin and "BEG" or (changed and "CHG" or "END")) or "VAL"),
		    task(), path, olds, news, outs)
	end
	
end


function cb(sys_conf, action, task, cb_tasks, out_node, path, key, oldval, newval )

	dbg("%4s %-22s %-40s %s => %s", action, task, path..key,
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

