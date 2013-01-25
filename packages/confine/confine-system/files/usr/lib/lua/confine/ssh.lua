--[[



]]--


--- CONFINE ssh abstraction library.
module( "confine.ssh", package.seeall )


local data   = require "confine.data"
local tree   = require "confine.tree"
local tools  = require "confine.tools"
local dbg    = tools.dbg

RSA_HEADER   = "%-%-%-%-%-BEGIN RSA PUBLIC KEY%-%-%-%-%-"
RSA_TRAILER  = "%-%-%-%-%-END RSA PUBLIC KEY%-%-%-%-%-"
SSH_HEADER   = "ssh%-rsa "

local SSH_CONFINE_TAG = " CONFINE_USER="


local function del_ssh_keys(sys_conf, del_id)

	assert(not del_id or tonumber(del_id))
	
	local out_keys = ""
	local changed = false
	
	for line in io.lines(sys_conf.ssh_node_auth_file) do
	
		local confine = tools.subfind( line, SSH_CONFINE_TAG)
		
		if not confine then
			
			out_keys = out_keys..line.."\n"
			
		else
			local user_id = confine:gsub(SSH_CONFINE_TAG,""):gsub(" ",""):gsub("\n","")
			dbg("del_ssh_keys() user_id=%s", user_id)
			
			if del_id and tonumber(user_id) and (tonumber(del_id) ~= tonumber(user_id)) then
				out_keys = out_keys..line.."\n"
			else
				changed = true
			end
		end
	end

	if changed then
		assert( io.output(io.open(sys_conf.ssh_node_auth_file,"w")) )
		dbg("del_ssh_keys(): del_id=%s", del_id)
		io.write(out_keys)
		io.close()
	end
end

local function add_ssh_keys(sys_conf, user_id, ssh_tokens)

	assert( io.output(io.open(sys_conf.ssh_node_auth_file,"a+")) )

	local k,v
	for k,v in pairs(ssh_tokens) do
		local token = v..SSH_CONFINE_TAG..tostring(user_id)
		dbg("add_ssh_keys(): token=%s", token)
		io.write( token.."\n" )
	end				

	io.close()
end

function get_node_local_group(sys_conf)
	
	local group = { user_roles = {} }

	for line in io.lines(sys_conf.ssh_node_auth_file) do
			
		local user_id = tools.subfindex( line, SSH_CONFINE_TAG)
		
		if user_id then
			local id = user_id:gsub(" ",""):gsub("\n","")
			local user_key = tools.subfindex( line, "", SSH_CONFINE_TAG)
			
			if tonumber(id) and user_key and user_key:find("^%s"%SSH_HEADER) then
				
				if not group.user_roles[id] then
					group.user_roles[id] = {}
					group.user_roles[id].local_user = {}
					group.user_roles[id].local_user.auth_tokens = {}
				end
				
				local role = group.user_roles[id]
				
				role.is_technician = true
				role.local_user.is_active = true
				if not tools.get_table_by_key_val( role.local_user.auth_tokens, user_key) then
					role.local_user.auth_tokens[#(role.local_user.auth_tokens) + 1] = user_key
				end
				
			else
				del_ssh_keys(sys_conf)
				return data.null
				--group.user_roles = {}
				--break
			end
		end
	end
	
--	tree.dump(group)
	return group
end

--function get_node_group(sys_conf, local_group)
--	local group = {}
--	if local_group.id then
--		group.uri = sys_conf.server_base_uri.."/groups/"..local_group.id
--	end
--	return group
--end



local function auth_token_to_rsa( auth_tokens )
	
	ssh_tokens = {}

	local k,v
	for k,v in pairs(auth_tokens or {}) do
		
		if v:find("^%s"%SSH_HEADER) then
			ssh_tokens[#ssh_tokens + 1] = v
			
		elseif tools.subfind(v,RSA_HEADER,RSA_TRAILER) then
			
			local tmp_file = os.tmpname()
			io.output(io.open(tmp_file,"w"))
			io.write(v)
			io.close()
			local ssh_key = luci.util.exec( "ssh-keygen -f "..tmp_file.." -i -m PEM" )
			os.remove(tmp_file)

			assert( ssh_key and ssh_key:find("^%s"%SSH_HEADER) )

			ssh_tokens[#ssh_tokens + 1] = ssh_key:gsub("\n","")

		else
			assert(false)
		end
	end
	return ssh_tokens
end



function cb_set_local_group_role( sys_conf, action, out_node, path, user_id, oldval, newval )
	
	assert(path == "/local_group/user_roles/", "path=%q key=%q"%{path,user_id})
	
	if action == "DEL" then
		
		del_ssh_keys(sys_conf, user_id)
		
	elseif action == "ADD" or action == "CHG" then		
		
		if newval.is_technician and newval.local_user and newval.local_user.is_active then
			
			local new_tokens = auth_token_to_rsa( newval.local_user.auth_tokens )
			local old_tokens = oldval and oldval.local_user.auth_tokens
			
			if tree.process(function() end, nil, nil, nil, {[1]={["/[^/]+"] = ""}}, old_tokens, new_tokens, nil) then

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

