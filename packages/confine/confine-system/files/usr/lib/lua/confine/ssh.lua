--[[



]]--


--- CONFINE ssh abstraction library.
module( "confine.ssh", package.seeall )

local nixio   = require "nixio"

local data   = require "confine.data"
local ctree  = require "confine.tree"
local tools  = require "confine.tools"
local ssl    = require "confine.ssl"
local dbg    = tools.dbg
local err    = tools.err


local SSH_CONFINE_TAG = " CONFINE_USER="


local function del_ssh_keys(auth_file, del_id)

	assert(not del_id or tonumber(del_id))
	
	local out_keys = ""
	local changed = false
	
	if nixio.fs.stat(auth_file) then

		for line in io.lines(auth_file) do
		
			local confine = tools.subfind( line, SSH_CONFINE_TAG)
			
			if not confine then
				
				out_keys = out_keys..line.."\n"
				
			else
				local user_id = confine:gsub(SSH_CONFINE_TAG,""):gsub(" ",""):gsub("\n","")
				
				if del_id and tonumber(user_id) and (tonumber(del_id) ~= tonumber(user_id)) then
					out_keys = out_keys..line.."\n"
				else
					changed = true
				end
			end
		end
	end

	if changed then
		assert( io.output(io.open(auth_file,"w")) )
		io.write(out_keys)
		io.close()
	end
	
	dbg("del_ssh_keys(): file=%s del_id=%s %s", auth_file, tostring(del_id), changed and "deleted" or "unchanged" )

end

local function add_ssh_keys(auth_file, user_id, ssh_tokens)

	local auth_dir = auth_file:gsub("/[^/]+$","/")
	
	if not nixio.fs.stat(auth_dir) then
		tools.mkdirr(auth_dir)
	end


	assert( io.output(io.open(auth_file,"a+")) )

	local k,v
	for k,v in pairs(ssh_tokens) do
		local token = (v..SSH_CONFINE_TAG..tostring(user_id)):gsub("\n","")
		dbg("add_ssh_keys(): file=%s token=%s", auth_file, token)
		io.write( token.."\n" )
	end				

	io.close()
end



local function auth_token_to_rsa( auth_tokens )
	
	ssh_tokens = {}

	local k,v
	for k,v in pairs(auth_tokens or {}) do
			
		if type(v)=="table" and type(v.data)=="string" then
			v = v.data
		end
		
		if type(v)=="string" and v:match("^%s[^\n]+$" %ssl.SSH_HEADER) then
			ssh_tokens[k] = v
			
		elseif type(v)=="string" and v:match("^%s.*%s$" %{ssl.RSA_HEADER,ssl.RSA_TRAILER}) then
			
			local tmp_file = os.tmpname()
			io.output(io.open(tmp_file,"w"))
			io.write(v)
			io.close()
			local ssh_key = ssl.get_ssh_pubkey_pem( tmp_file )
			os.remove(tmp_file)

			assert( ssh_key and ssh_key:find("^%s"%ssl.SSH_HEADER) )

			ssh_tokens[k] = ssh_key:gsub("\n","")

		else
			dbg("Ignoring auth_token=%s", ctree.as_string(v) )
		end
	end
	return ssh_tokens
end



function sys_get__lgroup(auth_file, node_not_slice_admin)
	
	local group = { user_roles = {} }

	if nixio.fs.stat(auth_file) then
	
		for line in io.lines(auth_file) do
				
			local user_id = tools.subfindex( line, SSH_CONFINE_TAG)
			
			if user_id then
				local id = user_id:gsub(" ",""):gsub("\n","")
				local user_key = tools.subfindex( line, "", SSH_CONFINE_TAG)
				
				if tonumber(id) and user_key and user_key:find("^%s"%ssl.SSH_HEADER) then
					
					group.user_roles[id] = group.user_roles[id] or { local_user = { auth_tokens = {} } }				
					local role = group.user_roles[id]
					
					if node_not_slice_admin then
						role.is_node_admin = true
					else
						role.is_slice_admin = true
					end
					
					role.local_user.is_active = true
					if not tools.get_table_by_key_val( role.local_user.auth_tokens, user_key) then
						role.local_user.auth_tokens[#(role.local_user.auth_tokens) + 1] = user_key
					end
					
				else
					err( "Corrupted "..auth_file.."! Removing all CONFINE tokens!")
					del_ssh_keys(auth_file)
					group.user_roles = {}
					break
				end
			end
		end
	end
	
	return group
end



function sys_set__lgroup_role( auth_file, sync, node_not_slice_admin, otree, ntree, path, begin, changed )

	local old = ctree.get_path_val(otree,path)
	local new = ctree.get_path_val(ntree,path)
	local user_id = ctree.get_path_leaf(path)
	assert( not (old or new) or type(old)=="table" or type(new)=="table" )
		
	if begin and old and not new then

		if sync then
			del_ssh_keys(auth_file, user_id)
		end
		
		ctree.set_path_val(otree, path, nil)
		
	elseif begin and not old and new then
		
		ctree.set_path_val(otree, path, {})
				
	elseif not begin and old and new and changed and sync then
		
		dbg("updating auth_tokens for path=%s", path)
		del_ssh_keys(auth_file, user_id)
		
		if (old.is_group_admin or (node_not_slice_admin and old.is_node_admin or old.is_slice_admin)) and old.local_user and old.local_user.is_active then
			
			add_ssh_keys(auth_file, user_id, auth_token_to_rsa( old.local_user.auth_tokens ))
		end
		
	end
	
	return true
end



--function cb2_lnode_group( rules, sys_conf, otree, ntree, path, begin, changed )
--	if not rules then return "cb2_lnode_lgroup" end
--
--	local old = ctree.get_path_val(otree,path)
--	
--	assert( old and type(old.user_roles)=="table" )
--	
--	if not begin and changed then
--		otree.group = {uri = otree.local_group.uri}
--	end	
--end
