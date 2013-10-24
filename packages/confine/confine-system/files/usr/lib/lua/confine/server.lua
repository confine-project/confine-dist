--[[



]]--


--- CONFINE server library.
module( "confine.server", package.seeall )

local data    = require "confine.data"
local tree    = require "confine.tree"
local tools   = require "confine.tools"
local csliver = require "confine.sliver"
local dbg     = tools.dbg




local function get_local_group(sys_conf, obj, cert_file, cache)

	if obj.group and obj.group.uri then
		
		local group_id
		obj.local_group = data.http_get_keys_as_table(obj.group.uri, sys_conf.server_base_uri, cert_file, cache)
		assert(obj.local_group, "Unable to retrieve node.group.uri=%s" %obj.group.uri)


		if obj.local_group and obj.local_group.user_roles then
			
--			obj.local_group.user_roles = {}
		
			local role_id, role_uri
			for role_id, role_uri in pairs(obj.local_group.user_roles) do
	--			dbg("calling http_get_keys_as_table uri=%s", user_uri.uri)
				local user_obj,user_id = data.http_get_keys_as_table(role_uri.user.uri, sys_conf.server_base_uri, cert_file, cache)
				assert(user_obj and user_id == role_id, "Unable to retrieve referenced user_url=%s" %role_uri.user.uri)
	
				obj.local_group.user_roles[user_id].local_user = user_obj
			end
		end
	end
end


function get_server_node(sys_conf, cache)

	dbg("------ retrieving new node ------")

	if cache then
		cache.sqn = cache.sqn and (cache.sqn + 1) or 2
	end
	
	local cert_file = sys_conf.server_cert_file
	
	if require_server_cert and not cert_file then
		return nil
	end
	
	local node = data.http_get_keys_as_table("/nodes/%d" % sys_conf.id, sys_conf.server_base_uri ,cert_file, cache)
	assert(node, "Unable to retrieve node.id=%s" %sys_conf.id)
	
	
	node.local_server   = data.http_get_keys_as_table("/server/", sys_conf.server_base_uri ,cert_file, cache)
	
	node.local_gateways = {}
	local gateways = data.http_get_keys_as_table("/gateways/", sys_conf.server_base_uri ,cert_file, nil)
	local gw_idx, gw_uri
	for gw_idx, gw_uri in pairs(gateways) do
		local gw_obj,gw_id = data.http_get_keys_as_table(gw_uri.uri, sys_conf.server_base_uri, cert_file, cache)
		assert(gw_obj and gw_id, "Unable to retrieve referenced gateway_url=%s" %gw_uri.uri)
		assert( ((gw_obj.mgmt_net or {}).tinc_server or {}).name, "Gateway response does not define mgmt_net.tinc_server.name")
		node.local_gateways[gw_obj.mgmt_net.tinc_server.name] = gw_obj
	end

	get_local_group(sys_conf, node, cert_file, cache)

	node.local_slivers = { }
	
	local sliver_idx, sliver_uri
	for sliver_idx, sliver_uri in pairs(node.slivers) do

		local sliver_obj,sliver_uri_id = data.http_get_keys_as_table(sliver_uri.uri, sys_conf.server_base_uri, cert_file, cache)
		assert(sliver_obj and sliver_uri_id, "Unable to retrieve referenced sliver_url=%s" %sliver_uri.uri)
		assert(sliver_obj.slice, "Sliver response does not define slice")

		local slice_obj,slice_id = data.http_get_keys_as_table(sliver_obj.slice.uri, sys_conf.server_base_uri, cert_file, cache)
		assert(slice_obj and slice_id, "Unable to retrieve referenced slice_url=%s" %sliver_obj.slice.uri )
		sliver_obj.local_slice = slice_obj
		
		sliver_obj.uri_id = sliver_uri_id
		
		node.local_slivers[slice_id] = sliver_obj


		if type(sliver_obj.template)=="table" and sliver_obj.template.uri then
			local template_obj = data.http_get_keys_as_table(sliver_obj.template.uri, sys_conf.server_base_uri, cert_file, cache)
			assert(template_obj, "Unable to retrieve referenced template_url=%s" %sliver_obj.template.uri)
			sliver_obj.local_template = template_obj
		elseif type(slice_obj.template)=="table" and slice_obj.template.uri then
			local template_obj = data.http_get_keys_as_table(slice_obj.template.uri, sys_conf.server_base_uri, cert_file, cache)
			assert(template_obj, "Unable to retrieve referenced template_url=%s" %slice_obj.template.uri)
			sliver_obj.local_template = template_obj
		end
		
		
		
		get_local_group(sys_conf, slice_obj, cert_file, cache)
		
		if not sliver_obj.exp_data_uri or sliver_obj.exp_data_uri==data.null or sliver_obj.exp_data_uri=="" then
			sliver_obj.exp_data_uri = slice_obj.exp_data_uri
			sliver_obj.exp_data_sha256 = slice_obj.exp_data_sha256
		end
		
		if not ( type(sliver_obj.exp_data_uri)=="string" and sliver_obj.exp_data_uri:len() > 0 ) then
			sliver_obj.exp_data_uri = data.null
			sliver_obj.exp_data_sha256 = data.null
		end
		
		if not sliver_obj.set_state or sliver_obj.set_state==data.null or
			(slice_obj.set_state==csliver.SERVER.register) or
			(slice_obj.set_state==csliver.SERVER.deploy and (sliver_obj.set_state==csliver.SERVER.start))
			then
			sliver_obj.set_state = slice_obj.set_state
		end

		
	end
	
--	tree.dump(node.local_group)

	-- cleanup cache:
	
	if cache then
		local k1,v1
		for k1,v1 in pairs(cache) do
			if type(v1)=="table" then
				if v1.sqn then
					if v1.sqn < cache.sqn then
						cache[k1] = nil
					end
				else
					local k2,v2
					local empty=true
					for k2,v2 in pairs(v1) do
						if v2.sqn < cache.sqn then
							v1[k2] = nil
						else
							empty=false
						end
					end
					
					if empty then
						cache[k1] = nil
					end
				end
			end
		end
	end


	return node
end

