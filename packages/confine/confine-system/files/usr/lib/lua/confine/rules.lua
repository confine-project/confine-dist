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

	table.insert(tree.errors, { member=(path:gsub("/$","")), message="Value="..data.val2string(val).." "..tostring(msg) })
	return "Error path=%s value=%s msg=%s" , path, tostring(msg), data.val2string(val)
end

function set_or_err( err_func, otree, ntree, path, valtype, patterns, no_set, description )
	
	local val = ctree.get_path_val( ntree, path )
	local success = false
	
	if patterns then
		assert( type(patterns)=="table" )
		local i,v
		for i,v in pairs(patterns) do
			if ( (val==v) or
				((valtype==nil or valtype=="string") and type(val)=="string" and type(v)=="string" and val:match(v)) or
				((valtype==nil or valtype=="number") and type(val)=="number" and type(v)=="number" and val <= v)
				) then
				success=true
				break
			end
		end
		
	elseif type(val)==valtype then
		
		success=true
	end
		
	
	if success then
		if not no_set then
			ctree.set_path_val(otree, path, type(val)=="table" and {} or val)
		end
		return val
	else
		if not description and patterns then
			description = "Invalid, must be one of:"
			local i,v
			for i,v in pairs(patterns) do
				if type(v)=="string" then
					description = description .. ' stringPattern:"' .. v .. '"'
				elseif type(v) == "boolean" then
					description = description .. " " .. tostring(v)
				elseif type(v) == "number" then
					description = description .. " " .. tostring(v)
				elseif v == null then
					description = description .. " " .. "null"
				elseif v == nil then
					description = description .. " " .. "nil"
				end
			end
			description = description .. " !"
			
		elseif not description then
			description = "Invalid"
		end
	

		dbg( err_func( otree, path, description, val) )
	end
end

function chk_or_err( err_func, otree, ntree, path, valtype, patterns, no_set )
	return set_or_err( err_func, otree, ntree, path, valtype, pattern, true )
end

function cb2_nop( rules, sys_conf, otree, ntree, path )
	if not rules then return "cb2_nop" end
end

function cb2_set_null( rules, sys_conf, otree, ntree, path )
	if not rules then return "cb2_set_null" end
	
	ctree.set_path_val(otree, path, null)
end

function cb2_set_empty_table( rules, sys_conf, otree, ntree, path, begin, changed )
	if not rules then return "cb2_set_empty_table" end
	
	if begin then
		ctree.set_path_val(otree, path, {})
	end
end

function cb2_set_table( rules, sys_conf, otree, ntree, path, begin, changed )
	if not rules then return "cb2_set_table" end
	
	local old = ctree.get_path_val(otree,path)
	local new = ctree.get_path_val(ntree,path)
	
	assert(not old or old==null or type(old)=="table")
	assert(not new or new==null or type(new)=="table")

	if begin and (not old or old==null) then
		ctree.set_path_val(otree, path, {})
	end
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

function cb2_overwrite( rules, sys_conf, otree, ntree, path, begin, changed )
	
	if not rules then return "cb2_set" end
	
	local old = ctree.get_path_val(otree,path)
	local new = ctree.get_path_val(ntree,path)
	local is_table = type(old)=="table" or type(new)=="table"
	
	if is_table and begin and ((not old or old==null) and new) then

		ctree.set_path_val(otree,path,{})
		
	elseif not is_table and old ~= new and new then
		
		ctree.set_path_val(otree,path,new)
	end
end

function cb2( task, rules, sys_conf, otree, ntree, path, begin, changed, misc, is_val )
	
	if not rules then return "cb2" end
	
	local max_val_len = 28
	
	assert( type(otree)=="table" )
	assert( type(ntree)=="table" )
	
	local oldv = ctree.get_path_val(otree,path)
	local olds = data.val2string(oldv):gsub("\n",""):sub(1,max_val_len)
	local newv = ctree.get_path_val(ntree,path)
	local news = data.val2string(newv):gsub("\n",""):sub(1,max_val_len)
	local is_table = type(oldv)=="table" or type(newv)=="table"

	
	--dbg( "%s %s %-15s %-50s %s => %s",
	--    is_val and "VAL" or "TBL", is_table and ((begin and "BEG" or (changed and "CHG" or "END"))) or "VAL",
	--    task(), path, olds, news)

	local report = task( rules, sys_conf, otree, ntree, path, begin, changed, misc )
	
	local outv = ctree.get_path_val(otree,path)
	local outs = data.val2string(outv):sub(1,max_val_len)

	if oldv ~= outv or (oldv ~= newv and not is_table) or changed or report then
		dbg( "%s %s %-15s %-50s %s %s => %s ==> %s",
		    is_val and "VAL" or "TBL", is_table and ((begin and "BEG" or (changed and "CHG" or "END"))) or "VAL",
		    task(), path, (oldv==nil and newv==nil and "UNMATCHED" or ""), olds, news, outs)
	end
	
end


