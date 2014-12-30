--[[



]]--

--- CONFINE Tree traversal library.
module( "confine.tree", package.seeall )


local util   = require "luci.util"
local tools  = require "confine.tools"
local cdata   = require "confine.data"
local dbg    = tools.dbg




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

local function get_key(obj, def, parent)

	if type(def) ~= "number" then
		return def
	
	
	elseif type(obj) == "string" and parent=="auth_tokens" then
		
		return tostring(def)

	elseif type(obj) == "table" and parent=="interfaces" then
		
		return tostring(obj.nr or def)

	--elseif type(obj) == "table" and parent=="addresses" then
	--	
	--	return tostring(def)

	elseif type(obj) == "table" then
		
		if obj.id then
			
			return tostring(obj.id)
			
		elseif type(obj.user)=="table" and obj.user.id then
			
			return tostring(obj.user.id)
			
		elseif obj.name then
			return obj.name
		
		end
		
	end
	
	return tostring(def)
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

function copy_recursive_rebase_keys(t, parent)
	local k,v
	local t2 = {}
	for k,v in pairs(t or {}) do
			
		local v_key = get_key(v, k, parent)
		assert(not t2[k] and not t2[v_key], "copy_recursive_rebase_keys() v_key=%s(%s) for val=%s key=%s parent=%s already used, object:%s"%{tostring(v_key),type(v_key), tostring(v), tostring(k), tostring(parent), as_string(v)})
		
		if type(v) == "table" then
			t2[v_key] = copy_recursive_rebase_keys(v, k)
		else
			t2[v_key] = v
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
		
		assert( not tree[tonumber(path_root)] )
		tree[path_root] = val
		
		return val
	
	else
		local path_new = path:sub(path_root:len()+2)
		
		assert(path_root and path_new)
		if tree[path_root] then
			assert( type(tree[path_root])=="table", "path=%s key=%s does not exist as table in tree=%s" %{path, path_root, tostring(tree)} )
			return set_path_val( tree[path_root], path_new, val, depth+1)
		end
	end
end

function get_path_val ( tree, path, depth)
	
	depth = depth or 0

	
	assert( tree~=nil )
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
	

		if not (type(path_root)=="string" and path_new) then
			assert(false, "path_root=%s path_new=%s" %{tostring(path_root), tostring(path_new)})
			
		elseif not (not tonumber(path_root) or not ( tree[path_root] and tree[tonumber(path_root)])) then
			assert( false, "path_root=%s tree:\n%s"%{tostring(path_root), as_string(tree)} )
		end
		
		assert( type(tree)=="table" or tree==cdata.null )
		
		if type(tree)=="table" and tonumber(path_root) and tree[tonumber(path_root)]~=nil then
			
			assert( tree[tostring(path_root)]==nil )
			
			return get_path_val( tree[tonumber(path_root)], path_new, depth+1)
			
		elseif type(tree)=="table" and tree[path_root]~=nil then
		
			return get_path_val( tree[path_root], path_new, depth+1)
			
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
	local curr_path = get_path_val(itree, path)
	local pk,pv

	for pk,pv in ipairs(rules) do
	
		local pattern  = pv[1]
		local key_form = pv[2]
		local val_form = pv[3]
		local pattern_ = pattern:match("/%*$") and pattern:gsub("/%*$","/") or pattern:gsub("/[^/]+$","/")

		local k
		for k in pairs(curr_path) do
				
			if (path..k):match("^%s$" %{pattern:gsub("*","[^/]+")} ) then
				
				local v = get_path_val(itree, path..k)
				local i = (key_form=="iterate" and (#otree+1)) or
					  (key_form=="number" and (tonumber(k))) or
					  (key_form=="number_p1" and (tonumber(k)+1)) or k
				
				if type(v) == "table" then
					otree[i] = {}
					filter(rules, itree, otree[i], path..k.."/")
				else
					otree[i] = (val_form=="number" and (tonumber(v))) or v
				end
				
			end
		end
	end
	
	return otree
end



function iterate(cb, rules, sys_conf, otree, ntree, path, unused, lvl)
	
	assert(cb and rules and otree and ntree and path)
	lvl = lvl or 0
	local up_changed = false
	local ocurr = get_path_val(otree, path)
	local ncurr = get_path_val(ntree, path)
	local tkall = tools.join_tables((type(ocurr)=="table" and ocurr or {}), (type(ncurr)=="table" and ncurr or {}))
	local pk,pv

--	dbg("lvl=%s cb=%s path=%s ov=%s nv=%s", lvl, cb(), path, tostring(ocurr), tostring(ncurr))
	
	for pk,pv in ipairs(rules) do
	
		local pattern     = pv[1]										-- eg: "/local_slivers/*/interfaces/*"	,eg2: "/local_slivers/*/interfaces"
		local task        = pv[2]
		local misc	  = pv[3]
		assert( type(pattern)=="string" and type(task)=="function", "pattern=%s task=%s pk=%s" %{tostring(pattern), tostring(task), tostring(pk) } )
		local pattern_path= pattern:match("/%*$") and pattern:gsub("/%*$","/") or pattern:gsub("/[^/]+$","/")	-- eg: "/local_slivers/*/interfaces/"	,eg2: "/local_slivers/*/"
--		local pattern_path= pattern:gsub("/%s$" %pattern_key,"/") -- DOES NOT WORK!!

--		dbg( "lvl=%s pk=%s path=%-25s pattern=%s %s %s", lvl, pk, path, pattern, pattern_path, pattern_key )
		if path:match("^%s$" %{pattern_path:gsub("*","[^/]+")}) then
		
--			dbg( "lvl=%s pk=%s path=%-25s pattern=%s %s %s", lvl, pk, path, pattern, pattern_path, pattern_key )

			local pattern_key = pattern:match("%*$") or pattern:match("[^/]+$") 				-- eg: "*" 				,eg2: "interfaces"
			local tkrel = ((pattern_key=="*") and tkall or { [pattern_key] = tkall[pattern_key] } )
			local matched = false
			local tk
			
			for tk in pairs( tkrel ) do
				
				assert( pattern_key=="*" or pattern_key == tk)
				assert( (path..tk):match("^%s$" %{pattern:gsub("*","[^/]+")} ) )
				
				matched = true
		
				local ov,nv
				if type(ocurr)=="table" then ov = ocurr[tk] end
				if type(ncurr)=="table" then nv = ncurr[tk] end
				local is_table = type(ov)=="table" or type(nv)=="table"
				local down_changed = false

				--dbg( "beg %s %-15s %s%s %s => %s (pattern=%s %s %s)",
				--    is_table and "TBL" or "VAL", tostring((task() or "???")), path, (type(tk)=="number" and tk or '"'..tk..'"'),
				--    cdata.val2string(ov):gsub("\n",""):sub(1,30), cdata.val2string(nv):gsub("\n",""):sub(1,30),
				--    pattern, up_changed and "upCHG" or "", down_changed and "downCHG" or "")
				
				if not ( ov~=nil or nv~=nil ) then
					assert(false, "path=%s ov=%s nv=%s" %{path..tk.."/", tostring(ov), tostring(nv)})
				elseif not (type(tk)=="number" and ((type(ncurr)=="table" and ncurr or {})[tostring(tk)]==nil) or ((type(ncurr)=="table" and ncurr or {})[tonumber(tk)]==nil)) then
					assert( false, "path=%s type(tk)=%s \nas number:\n%sas string:\n%s"
					       %{path..tk.."/", type(tk), as_string((type(ncurr)=="table" and ncurr or {})[tonumber(tk)]), qs_string((type(ncurr)=="table" and ncurr or {})[tostring(tk)])})
				elseif not (ov==nil or ov==get_path_val(otree, path..tk.."/")) then
					assert( false, "path=%s %s != %s"%{path..tk.."/", tostring(ov), tostring(get_path_val(otree, path..tk.."/"))})
				elseif not (nv==nil or nv==get_path_val(ntree, path..tk.."/")) then 
					assert( false, "path=%s %s != %s"%{path..tk.."/", tostring(nv), tostring(get_path_val(ntree, path..tk.."/"))})
				end
				
				
				if is_table then
					cb( task, rules, sys_conf, otree, ntree, path..tk.."/", true, false, misc, false)
					down_changed = iterate(cb, rules, sys_conf, otree, ntree, path..tk.."/", unused, lvl+1)
					cb( task, rules, sys_conf, otree, ntree, path..tk.."/", false, down_changed, misc, false)
				else
					cb( task, rules, sys_conf, otree, ntree, path..tk.."/", false, false, misc, true)
				end
				
				up_changed = up_changed or down_changed
				up_changed = up_changed or (ov ~= get_path_val(otree,path..tk.."/")) --otree changed
				up_changed = up_changed or (ov ~= nv and not (type(ov)=="table" and type(nv)=="table")) --otree vs ntree changed
				
				--dbg( "end %s %-15s %s%s %s => %s (pattern=%s %s %s)",
				--    is_table and "TBL" or "VAL", tostring(task() or "???"), path, (type(tk)=="number" and tk or '"'..tk..'"'),
				--    cdata.val2string((type(ocurr)=="table" and ocurr or {})[tk]):gsub("\n",""):sub(1,30), cdata.val2string(nv):gsub("\n",""):sub(1,30),
				--    pattern, up_changed and "upCHG" or "", down_changed and "downCHG" or "")
				
				--assert(type(tk)=="number" and ((type(ocurr)=="table" and ocurr or {})[tostring(tk)]==nil) or ((type(ocurr)=="table" and ocurr or {})[tonumber(tk)]==nil))
				if not (type(tk)=="number" and ((type(ocurr)=="table" and ocurr or {})[tostring(tk)]==nil) or ((type(ocurr)=="table" and ocurr or {})[tonumber(tk)]==nil)) then
					assert( false, "path=%s type(tk)=%s \nas number:\n%s as string:\n%s"
					       %{path..tk.."/", type(tk), as_string((type(ocurr)=="table" and ocurr or {})[tonumber(tk)]), as_string((type(ocurr)=="table" and ocurr or {})[tostring(tk)])})
				end

			end
			
			if (not matched) and pattern_key ~= "*" then
				--dbg("UNMATCHED lvl=%s pk=%s path=%-25s pattern=%s key=%s",
				--    lvl, tostring(pk), tostring(path), tostring(pattern), tostring(pattern_key))
				cb( task, rules, sys_conf, otree, ntree, path..pattern_key.."/", false, false, misc)
				up_changed = up_changed or (get_path_val(otree,path..pattern_key.."/")) --otree changed
			end
		end
	end

	return up_changed
end
