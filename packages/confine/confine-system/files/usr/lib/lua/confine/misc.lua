


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
