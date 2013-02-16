--[[



]]--


--- CONFINE processing rules.
module( "confine.rules", package.seeall )


local ctree    = require "confine.tree"
local data    = require "confine.data"
local tools   = require "confine.tools"

local dbg     = tools.dbg
local null    = data.null




function cb2_nop( rules, sys_conf, otree, ntree, path )
	if not rules then return "cb2_nop" end
end

function cb2_log( rules, sys_conf, otree, ntree, path )
	if not rules then return "cb2_nop" end
	return true
end

function cb2_set( rules, sys_conf, otree, ntree, path, begin, changed )
	
	if not rules then return "cb2_set" end
	
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

function cb2( task, rules, sys_conf, otree, ntree, path, begin, changed )
	
	if not rules then return "cb2" end
	
	assert( type(otree)=="table" )
	assert( type(ntree)=="table" )
	
	local oldv = ctree.get_path_val(otree,path)
	local olds = data.val2string(oldv):gsub("\n",""):sub(1,28)
	local newv = ctree.get_path_val(ntree,path)
	local news = data.val2string(newv):gsub("\n",""):sub(1,28)
	local is_table = type(oldv)=="table" or type(newv)=="table"

	--if not is_table and (oldv ~= newv) then
	--	dbg( " %-15s %-50s %s => %s", task(), path, olds, news)
	--end

	local report = task( rules, sys_conf, otree, ntree, path, begin, changed )
	
	local outv = ctree.get_path_val(otree,path)
	local outs = data.val2string(outv):sub(1,28)

	if oldv ~= outv or (oldv ~= newv and not is_table) or changed or report then
		dbg( " %s %-15s %-50s %s => %s ==> %s",
		    (is_table and (begin and "BEG" or (changed and "CHG" or "END")) or "VAL"),
		    task(), path, olds, news, outs)
	end
	
end


