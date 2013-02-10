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
	local index_key = full_key:sub( index_first+1, index_last)
	
	return base_key, index_key
end


function as_string( tree, maxdepth, spaces )
--	luci.util.dumptable(obj):gsub("%s"%tostring(cdata.null),"null")
	if not maxdepth then maxdepth = 10 end
	if not spaces then spaces = "" end
	local result = ""
	local k,v
	for k,v in pairs(tree) do
			
		result = result .. spaces..tostring(k).." : "..(type(v)=="string"and'"'or"")..cdata.val2string(v)..(type(v)=="string"and'"'or"").."\n"
		
		if type(v) == "table"  then
			assert( maxdepth > 1, "maxdepth reached!")
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
			
		elseif obj.user and obj.user.uri then
			
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


function filter(rules, tree, new_tree, path)
	
--	local curpath = path and "/"..table.concat(path, "/") or ""	
--	path = path or {} 
	path = path or "/"
	new_tree = new_tree or {}
	
	local pk, pv
	for pk,pv in ipairs(rules) do
	
		local pattern = util.keys(pv)[1]
		local task    = pv[pattern]

		local k,v
		for k,v in pairs(tree) do
--			dbg("filter_tree path=%s k=%s v=%s", curpath, tostring(k), tostring(v))
--			if (curpath.."/"..k):match("^%s$" % pattern) then
			if (path..k):match("^%s$" % pattern) then
				if type(tree[k]) == table then
					new_tree[k] = {}
--					filter(rules, tree[k], new_tree[k], copy(path,k))
					filter(rules, tree[k], new_tree[k], path..k.."/")
				else
					new_tree[k] = tree[k]
				end
				break
			end
		end
	end
	
	return new_tree
end



function process(cb, sys_conf, cb_tasks, out, rules, old, new, path)

	local tmp = {}
	local tmp_add_or_del = {}
	local changed = false
	
	path = path or "/"
	
--	dbg( "process(): rules=%s old=%s new=%s path=%s", tostring(rules), tostring(old), tostring(new), path)
		
	local pk,pv
	for pk,pv in ipairs(rules) do
	
		local pattern = util.keys(pv)[1]
		local task    = pv[pattern]
	
--		dbg("compare_results pattern=%-40s task=%s", pattern, task)

		local old_key, old_obj
		for old_key,old_obj in pairs( old or {} ) do
			if type(task) == "string" and (path..old_key):match("^%s$" % pattern) then
				tmp[old_key] = old_obj
			end
		end
		
		local tmp_key, tmp_obj
		for tmp_key, tmp_obj in pairs(tmp) do
			if type(task) == "string" and (path..tmp_key):match("^%s$" % pattern) then
				if new[tmp_key] == nil then
					--dbg("%s %s (%s; %s) got removed", curpath, v[1], k, tostring(v[2]))
					--cb(sys_conf, "DEL", task, cb_tasks, out, path, tmp_key, tmp_obj, nil)
					--tmp[tmp_key] = nil
					tmp[tmp_key] = cb(sys_conf, "DEL", task, cb_tasks, out, path, tmp_key, tmp_obj, nil)
					tmp_add_or_del[tmp_key] = true
					changed = true
				end
			end
		end
	
		local new_key, new_obj
		for new_key, new_obj in pairs(new or {}) do
			if type(task) == "string" and (path..new_key):match("^%s$" % pattern) then
				if tmp[new_key] == nil then
					--dbg("%s %s (%s; %s) got added", curpath, v[1], k, tostring(v[2]))
					--cb(sys_conf, "ADD", task, cb_tasks, out, path, new_key, nil, new_obj)
					--tmp[new_key] = new_obj
					tmp[new_key] = cb(sys_conf, "ADD", task, cb_tasks, out, path, new_key, nil, new_obj)
					tmp_add_or_del[new_key] = true
					changed = true
				end
			end
		end
	
		for tmp_key, tmp_obj in pairs(tmp) do
	
			if type(task) == "string" and (path..tmp_key):match("^%s$" % pattern) then
				
				if type(tmp_obj) == "table" then
					
					local new_obj = new[tmp_key] or {}
					
					if type(new_obj) == "table" and tmp_obj ~= new_obj then
					
						assert(type(new_obj) == "table")
						
						if process(cb, sys_conf, cb_tasks, out, rules, tmp_obj, new_obj, path..tmp_key.."/") then
							cb(sys_conf, "FIN", task, cb_tasks, out, path, tmp_key, tmp_obj, new_obj)
							changed = true
						end
					end
				else
					local new_obj = new[tmp_key]

					if not tmp_add_or_del[tmp_key] then
					
						assert( new_obj ~= nil, "No new_obj for path=%q tmp_key=%q, tmp_obj=%q"
							%{path, tostring(tmp_key), tostring(tmp_obj)} )
	
						if tmp_obj ~= new_obj then
							--dbg("%s %s (%s; %s => %s) got changed",
							--    curpath, json_key, k, tmp_obj, new_obj)
							cb(sys_conf, "CHG", task, cb_tasks, out, path, tmp_key, tmp_obj, new_obj)
							changed = true
						end
					end
				end
			end
		end
	end
	
	return changed
end





--TODO: Remove me!
function copy_path_val ( action, tree, path, key, oldval, newval, depth)
	
	depth = depth or 0

	assert( type(tree)=="table" )
	assert( type(path)=="string" )
	assert( type(key)=="number" or type(key)=="string" )

	if path ~= "/" then
		local path_root = tools.subfind(path,"^/","/"):gsub("/","")
--		local path_new = path:gsub("^/%s/"%path_root,"/") -- WTF: why doesnt this work with "/2-111/" !!!!!
		local path_new = path:sub(path_root:len()+2)
		assert(path_root)
		--dbg("copy_path_val() depth=%s action=%s tree=%s path=%s key=%s oldval=%s newval=%s",
		--    depth, action, tostring(tree), path, key, cdata.val2string(oldval), cdata.val2string(newval))
		return copy_path_val( action, tree[path_root], path_new, key, oldval, newval, depth+1 )
		
	elseif action == "ADD" then
		
		assert( not oldval and newval )
		
		--if type(key) == "number" then
		--	tree[#tree+1] = copy_recursive(newval)
		--else
			assert(not tree[key])
			tree[key] = copy_recursive(newval)
		--end

	elseif action == "DEL" then
		
		assert( tree[key] and oldval and not newval )
		
		tree[key] = nil
		
	elseif action == "CHG" then

		assert(tree[key] and oldval and newval)
		tree[key] = copy_recursive(newval)
		
	else
		assert( false )
	end
	
	--dbg("copy_path_val() depth=%s action=%s tree=%s path=%s key=%s oldval=%s newval=%s -> %s",
	--    depth, action, tostring(tree), path, key, cdata.val2string(oldval), cdata.val2string(newval), cdata.val2string(tree[key]))
	
	return tree[key]
end


--function get_path_val_old ( tree, path, key)
--
--	dbg("tree=%s path=%s key=%s", tostring(tree), path, tostring(key))
--	assert( not tree or type(tree)=="table" )
--	assert( type(path)=="string" )
--	assert( not key or (type(key)=="number" or type(key)=="string"))
--
--	if not tree then
--		
--		return nil
--	
--	elseif path ~= "/" then
--
--		local path_root = tools.subfind(path,"^/","/"):gsub("/","")
--		local path_new = path:sub(path_root:len()+2)
--		assert(path_root)
--		return get_path_val_old( tree[path_root], path_new, key)
--
--	elseif not key then
--		
--		return tree
--
--	elseif tree[key] then
--		
--		return tree[key]
--	
--	else
--		
--		return nil
--	end
--end

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
		assert( tree[path_root] and type(tree[path_root])=="table", "key=%s does not exist in tree=%s" %{path_root, tostring(tree)} )
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
	

		assert(path_root and path_new)
		assert( not tonumber(path_root) or not ( tree[path_root] and tree[tonumber(path_root)]) )
		
		if tree[path_root] then
		
			return get_path_val( tree[path_root], path_new, depth+1)
		
		elseif tonumber(path_root) and tree[tonumber(path_root)] then
			
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


function add_del_empty_table( action, out_node, path, key, oldval, newval)

	if action == "ADD" then

		assert(oldval == nil)
		
		local ret = copy_path_val( "ADD", out_node, path, key, nil, {})
		--dump( tree.get_path_val(out_node,"/"))
		return ret
	
	elseif action == "DEL" then
		
		-- It is expected that all items are removed via successive rules and the final CHG call will just remove the empty table
		return oldval

	elseif action == "CHG" then
		--dump( tree.get_path_val(out_node,"/"))
		assert( type(oldval) == "table" )
		if tools.get_table_items( oldval ) == 0 then
			local ret = copy_path_val( "DEL", out_node, path, key, oldval, nil)
			return ret
		else
			return oldval
		end
	end
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
	
		local pattern = pv[1]
		local task    = pv[2]
		assert( type(pattern)=="string" and type(task)=="function", "pattern=%s task=%s" %{tostring(pattern), tostring(task)} )
		local pattern_key = pattern:match("%*$") or pattern:match("[^/]+$")
		local pattern_ = pattern:match("/%*$") and pattern:gsub("/%*$","/") or pattern:gsub("/[^/]+$","/")
--		local pattern_ = pattern:gsub("/%s$" %pattern_key,"/") -- DOES NOT WORK!!

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
			
					local ov = type(ocurr)=="table" and ocurr[tk] or nil
					local nv = type(ncurr)=="table" and ncurr[tk] or nil
					local is_table = type(ov)=="table" or type(nv)=="table"
	
					--dbg( "pk=%s path=%s tk=%s pattern=%s cb=%s task=%s ov=%s nv=%s",
					--    pk, path, tk, pattern, cb(), task(),
					--    cdata.val2string(ov):gsub("\n",""):sub(1,30), cdata.val2string(nv):gsub("\n",""):sub(1,30))
					
					assert( ov or nv )
					
					if is_table then
						cb( task, sys_conf, otree, ntree, path..tk.."/", true, false, misc)
						local down_changed = iterate(cb, rules, sys_conf, otree, ntree, path..tk.."/", misc, lvl+1)
						cb( task, sys_conf, otree, ntree, path..tk.."/", false, down_changed, misc)
					else
						cb( task, sys_conf, otree, ntree, path..tk.."/", false, false, misc)
					end
					
					up_changed = up_changed or down_changed
					up_changed = up_changed or (ov ~= get_path_val(otree,path..tk.."/")) --otree changed
					up_changed = up_changed or (ov ~= nv and not (type(ov)=="table" and type(nv)=="table")) --ntree changed
				end
			end
			
			if unmatched and pattern_key ~= "*" then
				dbg("UNMATCHED lvl=%s pk=%s path=%-25s pattern=%s key=%s", lvl, pk, path, pattern, pattern_key)
				cb( task, sys_conf, otree, ntree, path..pattern_key.."/", false, false, misc)
				up_changed = up_changed or (get_path_val(otree,path..pattern_key.."/")) --otree changed
			end
		end
	end

	return up_changed
end
