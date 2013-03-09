--[[



]]--


--- CONFINE processing rules.
module( "confine.rules", package.seeall )


local ctree    = require "confine.tree"
local data    = require "confine.data"
local tools   = require "confine.tools"

local dbg     = tools.dbg
local null    = data.null


function add_error( tree, path, msg, val )
	assert(tree and path and msg)

	tree.errors = tree.errors or {}

	table.insert(tree.errors, { member=path, message=tostring(msg).." value="..tostring(val) })
	return "Error path=%s msg=%s val=%s" , path, tostring(msg), tostring(val)
end

function set_or_err( err_func, otree, ntree, path, valtype, ... )
	
	local val = ctree.get_path_val( ntree, path )
	local success = false
	
	if type(val)==valtype then
		
		if arg.n==0 then
			success=true
		else
			local i,v
			for i,v in ipairs(arg) do
				if (type(val)=="string" and val:match(v)) or (val==v) then
					success=true
					break
				end
			end
		end
		
	end
	
	if success then
		ctree.set_path_val(otree, path, type(val)=="table" and {} or val)
		return val
	else
		dbg( err_func( otree, path, "Invalid", val) )
	end
end


function cb2_nop( rules, sys_conf, otree, ntree, path )
	if not rules then return "cb2_nop" end
end

function cb2_log( rules, sys_conf, otree, ntree, path )
	if not rules then return "cb2_log" end
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

function cb2( task, rules, sys_conf, otree, ntree, path, begin, changed, misc, is_val )
	
	if not rules then return "cb2" end
	
	assert( type(otree)=="table" )
	assert( type(ntree)=="table" )
	
	local oldv = ctree.get_path_val(otree,path)
	local olds = data.val2string(oldv):gsub("\n","")--:sub(1,28)
	local newv = ctree.get_path_val(ntree,path)
	local news = data.val2string(newv):gsub("\n","")--:sub(1,28)
	local is_table = type(oldv)=="table" or type(newv)=="table"

	
	--dbg( "cb2() path=%s begin=%s changed=%s old=%s new=%s", path, tostring(begin), tostring(changed), olds, news)
	--if not is_table and (oldv ~= newv) then
	--	dbg( " %-15s %-50s %s => %s", task(), path, olds, news)
	--end

	local report = task( rules, sys_conf, otree, ntree, path, begin, changed )
	
	local outv = ctree.get_path_val(otree,path), is_table
	local outs = data.val2string(outv)--:sub(1,28)

	if oldv ~= outv or (oldv ~= newv and not is_table) or changed or report then
		dbg( "%s %s %-15s %-50s %s => %s ==> %s",
		    is_val and "VAL" or "TBL", is_table and ((begin and "BEG" or (changed and "CHG" or "END"))) or "VAL",
		    task(), path, olds, news, outs)
	end
	
end


