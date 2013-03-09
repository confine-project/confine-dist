--[[



]]--


--- CONFINE ssh abstraction library.
module( "confine.ssh", package.seeall )


local data   = require "confine.data"
local ctree  = require "confine.tree"
local tools  = require "confine.tools"
local ssl    = require "confine.ssl"
local dbg    = tools.dbg
local err    = tools.err


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
		dbg("del_ssh_keys(): del_id=%s", tostring(del_id))
		io.write(out_keys)
		io.close()
	end
end

local function add_ssh_keys(sys_conf, user_id, ssh_tokens)

	assert( io.output(io.open(sys_conf.ssh_node_auth_file,"a+")) )

	local k,v
	for k,v in pairs(ssh_tokens) do
		local token = (v..SSH_CONFINE_TAG..tostring(user_id)):gsub("\n","")
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
			
			if tonumber(id) and user_key and user_key:find("^%s"%ssl.SSH_HEADER) then
				
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
				err( "Corrupted "..sys_conf.ssh_node_auth_file.."! Removing all CONFINE tokens!")
				del_ssh_keys(sys_conf)
				group.user_roles = {}
				break
			end
		end
	end
	
--	ctree.dump(group)
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
			
		if type(v)=="table" and type(v.data)=="string" then
			v = v.data
		end
		
		if type(v)=="string" and v:match("^%s[^\n]+$" %ssl.SSH_HEADER) then
			ssh_tokens[#ssh_tokens + 1] = v
			
		elseif type(v)=="string" and v:match("^%s.*%s$" %{ssl.RSA_HEADER,ssl.RSA_TRAILER}) then
			
			local tmp_file = os.tmpname()
			io.output(io.open(tmp_file,"w"))
			io.write(v)
			io.close()
			local ssh_key = ssl.get_ssh_pubkey_pem( tmp_file )
			os.remove(tmp_file)

			assert( ssh_key and ssh_key:find("^%s"%ssl.SSH_HEADER) )

			ssh_tokens[#ssh_tokens + 1] = ssh_key:gsub("\n","")

		else
			dbg("Ignoring auth_token=%s", ctree.as_string(v) )
		end
	end
	return ssh_tokens
end

function cb2_set_lgroup( rules, sys_conf, otree, ntree, path, begin, changed )
	if not rules then return "cb2_set_lgroup" end

	local old = ctree.get_path_val(otree,path)
	local new = ctree.get_path_val(ntree,path)
	local key = ctree.get_path_leaf(path)
	
	
	assert( old and type(old.user_roles)=="table" )
	
	if not begin and changed then
		otree.group = {uri = otree.local_group.uri}
	end
	
end

function cb2_set_lgroup_role( rules, sys_conf, otree, ntree, path, begin, changed )
	if not rules then return "cb2_set_lgroup_role" end

	local old = ctree.get_path_val(otree,path)
	local new = ctree.get_path_val(ntree,path)
	local user_id = ctree.get_path_leaf(path)
	assert( not (old or new) or type(old)=="table" or type(new)=="table" )
	
	
	dbg("cb2_set_lgroup_role")
	if begin and old and not new then

		del_ssh_keys(sys_conf, user_id)
		ctree.set_path_val(otree,path,nil)
				
	elseif not begin and changed and new then
		
		dbg("")
		if new.is_technician and new.local_user and new.local_user.is_active then
			
			local new_tokens = auth_token_to_rsa( new.local_user.auth_tokens )
			local old_tokens = old and old.local_user and old.local_user.auth_tokens or {}
			
			if ctree.iterate(function() end, {[1]={"/*", function() end}}, sys_conf, old_tokens, new_tokens, "/") then --just scan for changes

				if old then
					del_ssh_keys(sys_conf, user_id)
				end
				
				add_ssh_keys(sys_conf, user_id, new_tokens)
			end
			
		else	
			if old then
				del_ssh_keys(sys_conf, user_id)
			end
		end
		
		ctree.set_path_val( otree, path, ((get_node_local_group(sys_conf)).user_roles)[user_id])
		
	end
	
	return true
end
