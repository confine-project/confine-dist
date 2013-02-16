


local k,o
for k,o in ipairs(arg) do
	dbg(k..": ".. o)
end


local k,j
for  k,j in pairs({{null},{false},{nil},{0},{""}}) do
	local v = j[1]
	print("type=%-8s val=%-20s NOTval=%-8s equalNil=%-8s unequalNil=%-8s"
	      %{ type(v), tostring(v), tostring(not v), tostring(v==nil), tostring(v~=nil) })
end






tmp_rules = {}
	table.insert(tmp_rules, {["/local_slivers"]					= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+"]				= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/uri"]				= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/slice"]				= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/slice/uri"]			= "CB_NOP"})
	
	table.insert(tmp_rules, {["/local_slivers/[^/]+/local_slice"]				= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/local_slice/id"]			= "CB_NOP"})
--	table.insert(tmp_rules, {["/local_slivers/[^/]+/local_slice/name"]			= "CB_NOP"})
--	table.insert(tmp_rules, {["/local_slivers/[^/]+/local_slice/description"]		= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/local_slice/expires_on"]		= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/local_slice/instance_sn"]		= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/local_slice/new_sliver_instance_sn"]	= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/local_slice/vlan_nr"]			= "CB_NOP"})
--	table.insert(tmp_rules, {["/local_slivers/[^/]+/local_slice/template"]			= "CB_NOP"})
--	table.insert(tmp_rules, {["/local_slivers/[^/]+/local_slice/template/uri"]		= "CB_NOP"})
--	table.insert(tmp_rules, {["/local_slivers/[^/]+/local_slice/exp_data_uri"]		= "CB_NOP"})
--	table.insert(tmp_rules, {["/local_slivers/[^/]+/local_slice/exp_data_sha256"]		= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/local_slice/set_state"]			= "CB_COPY"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/local_slice/properties"]		= "CB_COPY"})
	
	table.insert(tmp_rules, {["/local_slivers/[^/]+/local_slice/group"]							= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/local_slice/group/uri"]							= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/local_slice/local_group"]						= "CB_GET_SLIVER_GROUP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/local_slice/local_group/user_roles"]					= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/local_slice/local_group/user_roles/[^/]+"]		 		= "CB_SET_SLIVER_GROUP_ROLE"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/local_slice/local_group/user_roles/[^/]+/is_researcher"]		= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/local_slice/local_group/user_roles/[^/]+/local_user"] 	   		= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/local_slice/local_group/user_roles/[^/]+/local_user/is_active"]		= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/local_slice/local_group/user_roles/[^/]+/local_user/auth_tokens"]	= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/local_slice/local_group/user_roles/[^/]+/local_user/auth_tokens/[^/]+"]	= "CB_NOP"})
	
	table.insert(tmp_rules, {["/local_slivers/[^/]+/node"]				= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/node/uri"]			= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/description"]			= "CB_COPY"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/instance_sn"]			= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/template"]			= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/template/uri"]			= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/exp_data_uri"]			= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/exp_data_sha256"]		= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/interfaces"]			= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/interfaces/[^/]+"]		= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/interfaces/[^/]+/nr"]		= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/interfaces/[^/]+/name"]		= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/interfaces/[^/]+/type"]		= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/interfaces/[^/]+/parent_name"]	= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/properties"]			= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/properties/[^/]+"]		= "CB_COPY"})

	table.insert(tmp_rules, {["/local_slivers/[^/]+/local_template"]		= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/local_template/uri"]		= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/local_template/name"]		= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/local_template/description"]	= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/local_template/type"]		= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/local_template/arch"]		= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/local_template/is_active"]	= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/local_template/image_uri"]	= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/local_template/image_sha256"]	= "CB_NOP"})
	
	table.insert(tmp_rules, {["/local_slivers/[^/]+/local_exp_data_uri"]		= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/local_exp_data_sha256"]		= "CB_NOP"})
	
	table.insert(tmp_rules, {["/local_slivers/[^/]+/state"]				= "CB_NOP"})









--				ctree.process( rules.cb, sys_conf, cnode.cb_tasks, local_node, cnode.in_rules, local_node, server_node, "/" )
--				ctree.process, rules.cb, sys_conf, cnode.cb_tasks, local_node, cnode.in_rules, local_node, server_node, "/" )


in_rules = {}
tmp_rules = in_rules
	table.insert(tmp_rules, {["/description"]			= "CB_COPY"})
	table.insert(tmp_rules, {["/properties"]			= "CB_NOP"})
	table.insert(tmp_rules, {["/properties/[^/]+"]			= "CB_COPY"})
--	table.insert(tmp_rules, {["/properties/[^/]+/[^/]+"]		= "CB_COPY"})
	table.insert(tmp_rules, {["/cn"]				= "CB_NOP"})
	table.insert(tmp_rules, {["/cn/app_url"]			= "CB_COPY"})
	table.insert(tmp_rules, {["/cn/cndb_uri"]			= "CB_COPY"})
	table.insert(tmp_rules, {["/cn/cndb_cached_on"]			= "CB_COPY"})

--	table.insert(tmp_rules, {["/uri"]				= "CB_NOP"})
--	table.insert(tmp_rules, {["/id"] 				= "CB_SETUP"})
	table.insert(tmp_rules, {["/uuid"]				= "CB_SET_UUID"})
	table.insert(tmp_rules, {["/pubkey"] 				= "CB_SETUP"})
	table.insert(tmp_rules, {["/cert"] 				= "CB_SETUP"})
	table.insert(tmp_rules, {["/arch"]				= "CB_SETUP"})
	table.insert(tmp_rules, {["/local_iface"]			= "CB_SETUP"})
	table.insert(tmp_rules, {["/sliver_pub_ipv6"]			= "CB_SETUP"})
	table.insert(tmp_rules, {["/sliver_pub_ipv4"]			= "CB_SETUP"})
	table.insert(tmp_rules, {["/sliver_pub_ipv4_range"]		= "CB_SETUP"})

	table.insert(tmp_rules, {["/tinc"] 				= "CB_NOP"})
	table.insert(tmp_rules, {["/tinc/name"] 			= "CB_SETUP"})
	table.insert(tmp_rules, {["/tinc/pubkey"]			= "CB_SETUP"})
	table.insert(tmp_rules, {["/tinc/island"]			= "CB_COPY"})
	table.insert(tmp_rules, {["/tinc/island/uri"]			= "CB_COPY"})
	table.insert(tmp_rules, {["/tinc/connect_to"]			= "CB_NOP"})
	table.insert(tmp_rules, {["/tinc/connect_to/[^/]+"]		= "CB_SET_TINC"})
	table.insert(tmp_rules, {["/tinc/connect_to/[^/]+/ip_addr"] 	= "CB_NOP"})
	table.insert(tmp_rules, {["/tinc/connect_to/[^/]+/port"] 	= "CB_NOP"})
	table.insert(tmp_rules, {["/tinc/connect_to/[^/]+/pubkey"] 	= "CB_NOP"})
	table.insert(tmp_rules, {["/tinc/connect_to/[^/]+/name"] 	= "CB_NOP"})

	table.insert(tmp_rules, {["/priv_ipv4_prefix"]			= "CB_SET_SYS+REBOOT"})
	table.insert(tmp_rules, {["/direct_ifaces/[^/]+"]		= "CB_NOP"})
	table.insert(tmp_rules, {["/direct_ifaces"]			= "CB_SET_SYS+SLIVERS"})
	table.insert(tmp_rules, {["/sliver_mac_prefix"]			= "CB_SET_SYS+SLIVERS"})	
	
	table.insert(tmp_rules, {["/test"]				= "CB_TEST"})
	table.insert(tmp_rules, {["/test/[^/]+"]			= "CB_NOP"})
	table.insert(tmp_rules, {["/test/[^/]+/[^/]+"]			= "CB_NOP"})

	
	table.insert(tmp_rules, {["/local_group"]						= "CB_GET_LOCAL_GROUP"})
	table.insert(tmp_rules, {["/local_group/user_roles"]					= "CB_NOP"})
	table.insert(tmp_rules, {["/local_group/user_roles/[^/]+"]		 		= "CB_SET_LOCAL_GROUP_ROLE"})
	table.insert(tmp_rules, {["/local_group/user_roles/[^/]+/is_technician"]		= "CB_NOP"})
--	table.insert(tmp_rules, {["/local_group/user_roles/[^/]+/user"]		  		= "CB_NOP"})
--	table.insert(tmp_rules, {["/local_group/user_roles/[^/]+/user/uri"]			= "CB_NOP"})
	table.insert(tmp_rules, {["/local_group/user_roles/[^/]+/local_user"] 	   		= "CB_NOP"})
	table.insert(tmp_rules, {["/local_group/user_roles/[^/]+/local_user/is_active"]		= "CB_NOP"})
	table.insert(tmp_rules, {["/local_group/user_roles/[^/]+/local_user/auth_tokens"]	= "CB_NOP"})
	table.insert(tmp_rules, {["/local_group/user_roles/[^/]+/local_user/auth_tokens/[^/]+"]	= "CB_NOP"})
	
	table.insert(tmp_rules, {["/group"]				= "CB_SET_GROUP"})
	table.insert(tmp_rules, {["/group/uri"]				= "CB_NOP"})
	
	table.insert(tmp_rules, {["/boot_sn"] 				= "CB_SET_BOOT_SN"})
	table.insert(tmp_rules, {["/set_state"]				= "CB_COPY"})
	table.insert(tmp_rules, {["/state"]				= "CB_SET_STATE"})


	table.insert(tmp_rules, {["/local_slivers"]			= "CB_PROCESS_LSLIVERS"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+"]		= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/state"]		= "CB_NOP"})
	
	table.insert(tmp_rules, {["/slivers"]				= "CB_NOP"})
	table.insert(tmp_rules, {["/slivers/[^/]+"]			= "CB_NOP"})
	table.insert(tmp_rules, {["/slivers/[^/]+/uri"]			= "CB_NOP"})

	table.insert(tmp_rules, {["/sliver_pub_ipv4_avail"]		= "CB_NOP"})


cb_tasks = tools.join_tables( rules.dflt_cb_tasks, {
	
	["CB_FAILURE"] 	      	= function( sys_conf, action, out_node, path, key, oldval, newval )
					set_node_state( sys_conf, out_node, STATE.failure )
					return oldval
				end,
	["CB_SETUP"] 	      	= function( sys_conf, action, out_node, path, key, oldval, newval )
					set_node_state( sys_conf, out_node, STATE.setup )
					return oldval
				end,
	["CB_SET_STATE"]      	= function( sys_conf, action, out_node, path, key, oldval, newval )
					return set_node_state( sys_conf, out_node, out_node.set_state )
				end,

	["CB_SET_BOOT_SN"]     	= function( sys_conf, action, out_node, path, key, oldval, newval )
					if path=="/" and key=="boot_sn" and system.set_system_conf( sys_conf, key, newval) then
						system.reboot()
					end
				end,
	["CB_SET_UUID"]     	= function( sys_conf, action, out_node, path, key, oldval, newval )
					if path=="/" and key=="uuid" and system.set_system_conf( sys_conf, key, newval) then
						return ctree.copy_path_val( action, out_node, path, key, oldval, newval)
					end
				end,
				
	["CB_SET_TINC"]    	= function( sys_conf, action, out_node, path, key, oldval, newval )
					return tinc.cb_reconf_tinc( sys_conf, action, out_node, path, key, oldval, newval )
				end,

	["CB_GET_LOCAL_GROUP"]= function( sys_conf, action, out_node, path, key, oldval, newval )
					out_node.local_group = ssh.get_node_local_group(sys_conf)
					return out_node.local_group
				end,
	["CB_SET_LOCAL_GROUP_ROLE"]= function( sys_conf, action, out_node, path, key, oldval, newval )
					return ssh.cb_set_local_group_role( sys_conf, action, out_node, path, key, oldval, newval )
				end,
	["CB_SET_GROUP"]    	= function( sys_conf, action, out_node, path, key, oldval, newval )
					if type(out_node.local_group)=="table" and out_node.local_group.user_roles then
						return ctree.copy_path_val( action, out_node, path, key, oldval, newval)
					else
						out_node.group = null
						return out_node.group
					end
				end,
				
	["CB_SET_SYS+REBOOT"]	= function( sys_conf, action, out_node, path, key, oldval, newval )
					if action == "CHG" and system.set_system_conf( sys_conf, key, newval ) then
						system.set_system_conf( sys_conf, "sys_state", "prepared" )
						out_node.boot_sn = -1
						return ctree.copy_path_val( action, out_node, path, key, oldval, newval)
					end
				end,
	["CB_SET_SYS+SLIVERS"]	= function( sys_conf, action, out_node, path, key, oldval, newval )
					--dbg("CB_SET_SYS+SLIVERS")
					if action == "CHG" and system.set_system_conf( sys_conf, key, newval ) then
						sliver.remove_slivers( sys_conf, nil )
						return ctree.copy_path_val( action, out_node, path, key, oldval, newval)
					end
				end,
				
	["CB_PROCESS_LSLIVERS"]	= function( sys_conf, action, out_node, path, key, oldval, newval )
				--	ctree.dump(newval)
					return sliver.process_local_slivers( sys_conf, action, out_node, path, key, oldval, newval )
				end
					

	
} )



function cb(sys_conf, action, task, cb_tasks, out_node, path, key, oldval, newval )

	dbg("%4s %-22s %-40s %s => %s", action, task, path..key,
		data.val2string(oldval):gsub("\n",""):sub(1,28),
		data.val2string(newval):gsub("\n",""):sub(1,28))

	if cb_tasks[task] then
		
		local finval = cb_tasks[task](sys_conf, action, out_node, path, key, oldval, newval)
		
		if task ~= "CB_NOP" and task ~= "CB_COPY" then			
			dbg("%s %-22s %-40s   ===> %s", action, task, path..key, data.val2string(finval):gsub("\n",""):sub(1,28))
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



--register_rules = {}
--tmp_rules = register_rules
--	table.insert(tmp_rules, {["/local_slivers"]					= "CB_NOP"})
--	table.insert(tmp_rules, {["/local_slivers/[^/]+"]				= "CB_CONFIG_LSLIVER"})
----	table.insert(tmp_rules, {["/local_slivers/[^/]+/uri"]				= "CB_COPY"})
--	table.insert(tmp_rules, {["/local_slivers/[^/]+/instance_sn"]			= "CB_COPY"})
--
--	--table.insert(tmp_rules, {["/local_slivers/[^/]+/local_slice"]				= "CB_ADD_DEL_EMPTY_TABLE"})--"CB_SET_LSLIVER_LSLICE"})
--	--table.insert(tmp_rules, {["/local_slivers/[^/]+/local_slice/id"]			= "CB_COPY"})
--	--table.insert(tmp_rules, {["/local_slivers/[^/]+/local_slice/new_sliver_instance_sn"]	= "CB_COPY"})
--	--table.insert(tmp_rules, {["/local_slivers/[^/]+/local_slice/instance_sn"]		= "CB_COPY"})
--	--table.insert(tmp_rules, {["/local_slivers/[^/]+/local_slice/set_state"]			= "CB_COPY"})
--
--	table.insert(tmp_rules, {["/local_slivers/[^/]+/state"]				= "CB_NOP"})--"CB_SET_SLIVER_STATE"})




function config_local_sliver( sys_conf, action, out_node, path, key, oldslv, newslv )

	assert( not oldslv or oldslv.state )
	assert( not newslv or newslv.local_slice)

	if action == "ADD" then

		assert(oldslv == nil)
	
		local ret = ctree.copy_path_val( "ADD", out_node, path, key, nil, { ["state"] = STATE.bad_conf })
		
		return ret
	
	elseif action == "DEL" then -- the missing trigger
		
		
--		remove_slivers( sys_conf, oldslv )
		return ctree.copy_path_val( "DEL", out_node, path, key, oldslv, newslv)
	
	elseif action == "CHG" then
		
--		return ctree.copy_path_val( action, out_node, path, key, oldslv, newslv)
		return oldslv
	end
end


local sliver_cb_tasks = tools.join_tables( crules.dflt_cb_tasks, {
	
	["CB_CONFIG_LSLIVER"]	= function( sys_conf, action, out_node, path, key, oldslv, newslv )
				--	ctree.dump(newslv)
					return config_local_sliver( sys_conf, action, out_node, path, key, oldslv, newslv )
				end
	
} )


function process_local_slivers( sys_conf, action, out_node, path, key, oldval, newval )
	ctree.process( crules.cb, sys_conf, sliver_cb_tasks, out_node, register_rules, oldval, newval, path..key.."/" )
	return ctree.get_path_val(out_node, path..key.."/")
end



--TODO: Remove me!
function cb_set_local_group_role( sys_conf, action, out_node, path, user_id, oldval, newval )
	
	assert(path == "/local_group/user_roles/", "path=%q key=%q"%{path,user_id})
	
	if action == "DEL" then
		
		del_ssh_keys(sys_conf, user_id)
		
	elseif action == "ADD" or action == "CHG" then		
		
		if newval.is_technician and newval.local_user and newval.local_user.is_active then
			
			local new_tokens = auth_token_to_rsa( newval.local_user.auth_tokens )
			local old_tokens = oldval and oldval.local_user.auth_tokens
			
			if ctree.process(function() end, nil, nil, nil, {[1]={["/[^/]+"] = ""}}, old_tokens, new_tokens, nil) then

				if oldval then
					del_ssh_keys(sys_conf, user_id)
				end
				
				add_ssh_keys(sys_conf, user_id, new_tokens)
			end
			
		else	
			if oldval then
				del_ssh_keys(sys_conf, user_id)
			end
		end
	end
	
	return newval
end


--function cb_set_group( sys_conf, action, out_node, path, key, oldval, newval )
--	
--	out_node.group.uri = get_node_group(sys_conf, out_node.local_group)
--	
--	return out_node.group
--end

