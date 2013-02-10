--[[



]]--


--- CONFINE server library.
module( "confine.server", package.seeall )

local data    = require "confine.data"
local tree    = require "confine.tree"
local tools   = require "confine.tools"
local dbg     = tools.dbg




local function get_local_group(sys_conf, obj, cert_file, cache)

	if obj.group and obj.group.uri then
		
		local group_id
		obj.local_group = data.http_get(obj.group.uri, sys_conf.server_base_uri, cert_file, cache)
		assert(obj.local_group, "Unable to retrieve node.group.uri=%s" %obj.group.uri)


		if obj.local_group and obj.local_group.user_roles then
			
--			obj.local_group.user_roles = {}
		
			local role_id, role_uri
			for role_id, role_uri in pairs(obj.local_group.user_roles) do
	--			dbg("calling http_get uri=%s", user_uri.uri)
				local user_obj,user_id = data.http_get(role_uri.user.uri, sys_conf.server_base_uri, cert_file, cache)
				assert(user_obj and user_id == role_id, "Unable to retrieve referenced user_url=%s" %role_uri.user.uri)
	
				obj.local_group.user_roles[user_id].local_user = user_obj
			end
		end
	end
end


function get_server_node(sys_conf)

	dbg("------ retrieving new node ------")

	local cache = {}
	local cert_file = sys_conf.server_cert_file
	
	if require_server_cert and not cert_file then
		return nil
	end
	
	local node = data.http_get("/nodes/%d" % sys_conf.id, sys_conf.server_base_uri ,cert_file, cache)
	assert(node, "Unable to retrieve node.id=%s" %sys_conf.id)

	get_local_group(sys_conf, node, cert_file, cache)

	node.local_slivers = { }
	
	local sliver_idx, sliver_uri
	for sliver_idx, sliver_uri in pairs(node.slivers) do

		local sliver_obj,sliver_id = data.http_get(sliver_uri.uri, sys_conf.server_base_uri, cert_file, cache)
		assert(sliver_obj and sliver_id, "Unable to retrieve referenced sliver_url=%s" %sliver_uri.uri)
		assert(sliver_obj.slice, "Sliver response does not define slice")
		node.local_slivers[sliver_id] = sliver_obj		

		local slice_obj,slice_id = data.http_get(sliver_obj.slice.uri, sys_conf.server_base_uri, cert_file, cache)
		assert(slice_obj and slice_id, "Unable to retrieve referenced slice_url=%s" %sliver_obj.slice.uri )
		sliver_obj.local_slice = slice_obj

		if type(sliver_obj.template)=="table" and sliver_obj.template.uri then
			local template_obj = data.http_get(sliver_obj.template.uri, sys_conf.server_base_uri, cert_file, cache)
			assert(template_obj, "Unable to retrieve referenced template_url=%s" %sliver_obj.template.uri)
			sliver_obj.local_template = template_obj
		elseif type(slice_obj.template)=="table" and slice_obj.template.uri then
			local template_obj = data.http_get(slice_obj.template.uri, sys_conf.server_base_uri, cert_file, cache)
			assert(template_obj, "Unable to retrieve referenced template_url=%s" %slice_obj.template.uri)
			sliver_obj.local_template = template_obj
		end
		
		
		
		get_local_group(sys_conf, slice_obj, cert_file, cache)
		
		if not sliver_obj.exp_data_uri or sliver_obj.exp_data_uri==data.null then
			sliver_obj.exp_data_uri = slice_obj.exp_data_uri
			sliver_obj.exp_data_sha256 = slice_obj.exp_data_sha256
		end
		
		if not sliver_obj.set_state or sliver_obj.set_state==data.null then
			sliver_obj.set_state = slice_obj.set_state
		end

		
	end
	
--	tree.dump(node.local_group)

	return node
end

