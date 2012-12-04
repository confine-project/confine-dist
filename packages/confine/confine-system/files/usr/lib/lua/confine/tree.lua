--[[



]]--

--- CONFINE Tree traversal library.
module( "confine.tree", package.seeall )


local util   = require "luci.util"
local tools  = require "confine.tools"
local data   = require "confine.data"
local dbg    = tools.dbg

function get_url_keys( url )
	local api_first, api_last = url:find("/api")
	local full_key = api_last and url:sub(api_last+1) or url
	local base_key = full_key:sub( full_key:find( "/[%l]+/" ) )
	local index_first,index_last = full_key:find( "/[%d]+[-]*[%d]*" )
	local index_key = full_key:sub( index_first+1, index_last)
	
	return base_key, index_key
end


function dump( tree, maxdepth, spaces )
--	luci.util.dumptable(obj):gsub("%s"%tostring(data.null),"null")
	if not spaces then spaces = "" end

	local k,v
	for k,v in pairs(tree) do
		print(spaces..tostring(k).." : "..(type(v)=="string"and'"'or"")..data.val2string(v)..(type(v)=="string"and'"'or""))
		if type(v) == "table" then
			dump(v, maxdepth, spaces.."    ")
		end
	end
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


function copy(t, add)
	local k,v
	local t2 = {}
	for k,v in pairs(t) do
		t2[k] = v
	end
	if add then
		t2[#t2+1] = add
	end
	return t2
end

function copy_recursive(t)
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
	
	local curpath = path and "/"..table.concat(path, "/") or ""
	
	if not path then path = { } end
	if not new_tree then new_tree = { } end
	
	local pk, pv
	for pk,pv in ipairs(rules) do
	
		local pattern = util.keys(pv)[1]
		local task    = pv[pattern]
				

		local k,v
		for k,v in pairs(tree) do
--			dbg("filter_tree path=%s k=%s v=%s", curpath, tostring(k), tostring(v))
			if (curpath.."/"..k):match("^%s$" % pattern) then
				if type(tree[k]) == table then
					new_tree[k] = {}
					filter(rules, tree[k], new_tree[k], copy(path,k))
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
	local changed = false

	if not path then path = "/" end
	
	
	local pk, pv
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
					cb(sys_conf, "DEL", task, cb_tasks, out, path, tmp_key, tmp_obj, nil)
					tmp[tmp_key] = nil
					changed = true
				end
			end
		end
	
		local new_key, new_obj
		for new_key, new_obj in pairs(new) do
			if type(task) == "string" and (path..new_key):match("^%s$" % pattern) then
				if tmp[new_key] == nil then
					--dbg("%s %s (%s; %s) got added", curpath, v[1], k, tostring(v[2]))
					cb(sys_conf, "ADD", task, cb_tasks, out, path, new_key, nil, new_obj)
					tmp[new_key] = new_obj
					changed = true
				end
			end
		end
	
		for tmp_key, tmp_obj in pairs(tmp) do
	
			if type(task) == "string" and (path..tmp_key):match("^%s$" % pattern) then
				
				local  new_obj = new[tmp_key]

				if type(tmp_obj) == "table" then
					
					assert(type(new_obj) == "table")
					
					if process(cb, sys_conf, cb_tasks, out, rules, tmp_obj, new_obj, path..tmp_key.."/") then
						cb(sys_conf, "CHG", task, cb_tasks, out, path, tmp_key, tmp_obj, new_obj)
						changed = true
					end
					
				else
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
	
	return changed
end






function set_path_val ( action, tree, path, key, oldval, newval)

--	dbg("tree_path_set path=%s key=%s", path, key)
	assert( type(tree)=="table" and type(path)=="string" and (type(key)=="number" or type(key)=="string") ,"")

	if path ~= "/" then
		local root_key = tools.subfind(path,"^/","/"):gsub("/","")
		assert(root_key)
		set_path_val ( action, tree[root_key], path:gsub("^/"..root_key,""), key, oldval, newval )
		
	elseif action == "ADD" then
		
		assert( not oldval and newval )
		
		if type(key) == "number" then
			tree[#tree+1] = (type(newval) == "table") and copy_recursive(newval) or newval
		else
			assert(not tree[key])
			tree[key] = (type(newval) == "table") and copy_recursive(newval) or newval
		end

	elseif action == "DEL" then
		
		assert( tree[key] and oldval and not newval )
		
		tree[key] = nil
		
	elseif action == "CHG" then

		assert(tree[key] and oldval and newval)
		tree[key] = (type(newval) == "table") and copy_recursive(newval) or newval
		
	else
		assert( false )
	end
	
	return newval or ""
end
