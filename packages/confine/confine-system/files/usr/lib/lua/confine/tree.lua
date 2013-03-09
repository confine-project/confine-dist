--[[



]]--

--- CONFINE Tree traversal library.
module( "confine.tree", package.seeall )


local util   = require "luci.util"
local tools  = require "confine.tools"
local cdata   = require "confine.data"
local dbg    = tools.dbg


function get_url_keys( url )
	local api_first, api_last = url:find("/api")
	local full_key = api_last and url:sub(api_last+1) or url
	local base_key = full_key:sub( full_key:find( "/[%l]+/" ) )
	local index_first,index_last = full_key:find( "/[%d]+[-]*[%d]*" )
	local index_key = index_first and full_key:sub( index_first+1, index_last)
	
	return base_key, index_key
end


function as_string( tree, maxdepth, spaces )
--	luci.util.dumptable(obj):gsub("%s"%tostring(cdata.null),"null")
	if not maxdepth then maxdepth = 15 end
	if not spaces then spaces = "" end
	if type(tree)~="table" then return tostring(tree) end
	local result = ""
	local k,v
	for k,v in pairs(tree or {}) do
			
		result = result .. spaces..
			(type(k)=="string"and'"'or"")..cdata.val2string(k)..(type(k)=="string"and'"'or"").." : "..
			(type(v)=="string"and'"'or"")..cdata.val2string(v)..(type(v)=="string"and'"'or"").."\n"
		
		if type(v) == "table"  then
			assert( maxdepth > 1, "maxdepth reached!")
			--dbg( "depth=%2s %s %s", cdata.val2string(maxdepth), spaces, cdata.val2string(k) )
			result = result .. as_string(v, (maxdepth - 1), spaces.."    ")
		end
	end
	return result
end

function dump( tree, maxdepth, spaces )
	print( as_string( tree, maxdepth, spaces) )
end

function get_key(obj, def)

	if type(def) ~= "number" then
		return def
	end

	if type(obj) == "table" then
		
		if obj.id and def and obj.id ~= def then
			dbg("get_key(): WARNING - obj_id=%s def=%s should have been assigned already!!?", obj.id, def)
		end
		
		if obj.id then
			return obj.id
		
		elseif obj.uri then
			
			local base_key,index_key = get_url_keys(obj.uri)
			return index_key
			
		elseif type(obj.user)=="table" and obj.user.uri then
			
			local base_key,index_key = get_url_keys(obj.user.uri)
			return index_key
			
		elseif obj.name then
			return obj.name
		
		elseif obj.ip_addr
			then return obj.ip_addr
			
		else
			return def
		end
		
	end
	
	return obj
end


--function copy(t, add)
--	local k,v
--	local t2 = {}
--	for k,v in pairs(t) do
--		t2[k] = v
--	end
--	if add then
--		t2[#t2+1] = add
--	end
--	return t2
--end

function copy_recursive(t)
	if type(t) == "table" then
		local k,v
		local t2 = {}
		for k,v in pairs(t) do
			if type(v) == "table" then
				t2[k] = copy_recursive(v)
			else
				t2[k] = v
			end
		end
		return t2
	else
		return t
	end
end

function copy_recursive_rebase_keys(t)
	local k,v
	local t2 = {}
	for k,v in pairs(t or {}) do
		if type(v) == "table" then
			local v_key = get_key(v, k)
			assert(not t2[v_key], "copy_recursive_rebase_keys() key=%s for val=%s already used", tostring(v_key), tostring(v) )
			t2[v_key] = copy_recursive_rebase_keys(v)
		else
			t2[k] = v
		end
	end
	return t2
end








function set_path_val ( tree, path, val, depth)

	depth = depth or 0

	--dbg("l=%s tree=%s path=%s val=%s", depth, tostring(tree), path, tostring(val))

	assert( tree )
	assert( type(path)=="string" )
	assert( path:len() >= 1 )
	
	path = (path:sub(path:len(),path:len())=="/") and path or path.."/"
	

	assert( path~="/" )
	assert( tools.subfind(path,"^/","/") )
	
	local path_root = tools.subfind(path,"^/","/"):gsub("/","")
	
	if path:match("^%s$" %"/[^/]+/") then
		
		tree[path_root] = val
		return val
	
	else
		local path_new = path:sub(path_root:len()+2)
		
		assert(path_root and path_new)
		assert( tree[path_root] and type(tree[path_root])=="table", "path=%s key=%s does not exist in tree=%s" %{path, path_root, tostring(tree)} )
		return set_path_val( tree[path_root], path_new, val, depth+1)
	end
end

function get_path_val ( tree, path, depth)
	
	depth = depth or 0

	
	assert( tree )
	assert( type(path)=="string" )
	assert( path:len() >= 1 )
	
	path = (path:sub(path:len(),path:len())=="/") and path or path.."/"

	if path=="/" then
		
--		dbg("l=%s path=%s tree=%s", depth, path, tostring(tree))		
		return tree
	
	else
		local path_root = tools.subfind(path,"^/","/"):gsub("/","")
		local path_new = path:sub(path_root:len()+2)

--		dbg("l=%s path=%s root=%s new=%s newroot=%s tree=%s", depth, path, path_root, path_new, tostring(tree[path_root]), tostring(tree))
	

		assert(type(path_root)=="string" and path_new, "path_root=%s path_new=%s" %{tostring(path_root), tostring(path_new)})
		assert( not tonumber(path_root) or not ( tree[path_root] and tree[tonumber(path_root)]),
		       "path_root=%s tree:\n%s"%{tostring(path_root), as_string(tree)} )
		
		assert( type(tree)=="table" or tree==cdata.null )
		
		if type(tree)=="table" and tree[path_root] then
		
			return get_path_val( tree[path_root], path_new, depth+1)
		
		elseif type(tree)=="table" and tonumber(path_root) and tree[tonumber(path_root)] then
			
			return get_path_val( tree[tonumber(path_root)], path_new, depth+1)
			
		else
			return nil
		end
	end
end


function get_path_leaf ( path, depth)
	
	depth = depth or 0

	--dbg("l=%s path=%s", depth, path)
	
	assert( type(path)=="string" )
	assert( path:len() >= 1 )
	
	path = (path:sub(path:len(),path:len())=="/") and path or path.."/"

	if path=="/" then
		return nil
	else
		local path_root = tools.subfind(path,"^/","/"):gsub("/","")
		local path_new = path:sub(path_root:len()+2)
		
		assert(path_root and path_new)
		
		if path_new=="/" or path_new=="" then
			return path_root
		else
			return get_path_leaf( path_new, depth+1)
		end
	end
end


function filter(rules, itree, otree, path)
	
	otree = otree or {}
	path = path or "/"

	assert(rules and otree and itree and path)
	local pk,pv
	
	for pk,pv in ipairs(rules) do
	
		local pattern  = pv[1]
		local pattern_ = pattern:match("/%*$") and pattern:gsub("/%*$","/") or pattern:gsub("/[^/]+$","/")

		local k
		for k in pairs(get_path_val(itree, path)) do
				
			if (path..k):match("^%s$" %{pattern:gsub("*","[^/]+")} ) then
				
				local v = get_path_val(itree, path..k)
				
				if type(v) == "table" then
					get_path_val(otree, path)[k] = {}
					filter(rules, itree, otree, path..k.."/")
				else
					get_path_val(otree, path)[k] = v
				end
				
			end
		end
	end
	
	return otree
end



function iterate(cb, rules, sys_conf, otree, ntree, path, misc, lvl)
	
	assert(cb and sys_conf and rules and otree and ntree and path)
	lvl = lvl or 0
	local up_changed = false
	local ocurr = get_path_val(otree, path)
	local ncurr = get_path_val(ntree, path)
	local tkeys = tools.join_tables((type(ocurr)=="table" and ocurr or {}), (type(ncurr)=="table" and ncurr or {}))
	local pk,pv

--	dbg("lvl=%s cb=%s path=%s ov=%s nv=%s", lvl, cb(), path, tostring(ocurr), tostring(ncurr))
	
	for pk,pv in ipairs(rules) do
	
		local pattern     = pv[1]
		local task        = pv[2]
		assert( type(pattern)=="string" and type(task)=="function", "pattern=%s task=%s" %{tostring(pattern), tostring(task)} )
		local pattern_key = pattern:match("%*$") or pattern:match("[^/]+$")
		local pattern_    = pattern:match("/%*$") and pattern:gsub("/%*$","/") or pattern:gsub("/[^/]+$","/")
--		local pattern_    = pattern:gsub("/%s$" %pattern_key,"/") -- DOES NOT WORK!!

--		dbg( "lvl=%s pk=%s path=%-25s pattern=%s %s %s", lvl, pk, path, pattern, pattern_, pattern_key )
		if path:match("^%s$" %{pattern_:gsub("*","[^/]+")}) then
		
--			dbg( "lvl=%s pk=%s path=%-25s pattern=%s %s %s", lvl, pk, path, pattern, pattern_, pattern_key )

			local tk
			local unmatched = true
			
			for tk in pairs( tkeys ) do
				
--				dbg( "pk=%s path=%-25s pattern=%s", pk, path..tk, pattern )
					
				if (path..tk):match("^%s$" %{pattern:gsub("*","[^/]+")} ) then
					
					assert( pattern_key=="*" or pattern_key == tk)
					
					unmatched = false
			
					local ov,nv
					if type(ocurr)=="table" then ov = ocurr[tk] end
					if type(ncurr)=="table" then nv = ncurr[tk] end
					local is_table = type(ov)=="table" or type(nv)=="table"
	
					--dbg( "pk=%s path=%s tk=%s pattern=%s cb=%s task=%s ov=%s nv=%s",
					--    pk, path, tk, pattern, cb(), task(),
					--    cdata.val2string(ov):gsub("\n",""):sub(1,30), cdata.val2string(nv):gsub("\n",""):sub(1,30))
					
					assert( ov~=nil or nv~=nil )
					
					local down_changed = false
					
					if is_table then
						cb( task, rules, sys_conf, otree, ntree, path..tk.."/", true, false, misc)
						down_changed = iterate(cb, rules, sys_conf, otree, ntree, path..tk.."/", misc, lvl+1)
						cb( task, rules, sys_conf, otree, ntree, path..tk.."/", false, down_changed, misc)
					else
						cb( task, rules, sys_conf, otree, ntree, path..tk.."/", false, false, misc, true)
					end
					
					up_changed = up_changed or down_changed
					up_changed = up_changed or (ov ~= get_path_val(otree,path..tk.."/")) --otree changed
					up_changed = up_changed or (ov ~= nv and not (type(ov)=="table" and type(nv)=="table")) --otree vs ntree changed
				end
			end
			
			if unmatched and pattern_key ~= "*" then
				dbg("UNMATCHED lvl=%s pk=%s path=%-25s pattern=%s key=%s",
				    lvl, tostring(pk), tostring(path), tostring(pattern), tostring(pattern_key))
				cb( task, rules, sys_conf, otree, ntree, path..pattern_key.."/", false, false, misc)
				up_changed = up_changed or (get_path_val(otree,path..pattern_key.."/")) --otree changed
			end
		end
	end

	return up_changed
end
