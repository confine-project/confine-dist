--[[



]]--

--- CONFINE data io library.
module( "confine.tinc", package.seeall )

local nixio  = require "nixio"
local sig    = require "signal"

local tools  = require "confine.tools"
local ctree   = require "confine.tree"
local dbg    = tools.dbg

local RSA_HEADER               = "%-%-%-%-%-BEGIN RSA PUBLIC KEY%-%-%-%-%-"
local RSA_TRAILER              = "%-%-%-%-%-END RSA PUBLIC KEY%-%-%-%-%-"



function get_connects (sys_conf)
	
	local connects = {}
	local node_name = "node_" .. sys_conf.id
	
	--dbg("canon_ipv6 test=%s", tools.canon_ipv6("8::8/128"))
	
	local file
	for file in nixio.fs.dir( sys_conf.tinc_hosts_dir ) do
			
		if file ~= node_name then
			
			local content = nixio.fs.readfile( sys_conf.tinc_hosts_dir..file )
			
			local subnet = content and tools.subfind(content,"Subnet","\n")
			
			if subnet then
				subnet = subnet:gsub(" ",""):gsub("Subnet=",""):gsub("\n","")
				if tools.canon_ipv6(subnet) ~= tools.canon_ipv6(sys_conf.mgmt_ipv6_prefix48.."::2/128") then
					subnet = nil
				end
			end
			
			if subnet then
				
				--dbg("get_local_node_tinc file=%s: %s\nsubnet=%s %s",
				--    file, content or "", tools.canon_ipv6(subnet), tools.canon_ipv6(sys_conf.mgmt_ipv6_prefix48.."::2/128"))

				local ip_addr  = tools.subfind(content,"Address","\n")
				local port     = tools.subfind(content,"Port","\n")
				local pubkey   = tools.subfind(content,RSA_HEADER,RSA_TRAILER)
				local name     = file

				if ip_addr and port and pubkey and name then
					connects[name] = {
						ip_addr  = ip_addr:gsub(" ",""):gsub("Address=",""):gsub("\n",""),
						port     = tonumber( (port:gsub(" ",""):gsub("Port=",""):gsub("\n","")) ),
						pubkey   = pubkey,
						name     = name
					}
				end
			end
		end
	end
	
	return connects
end

function get (sys_conf, cached_tinc)

	local tinc = {}
	
	tinc.name             = "node_" .. sys_conf.id
	
	tinc.pubkey           = tools.subfind(nixio.fs.readfile( sys_conf.tinc_node_key_pub ),RSA_HEADER,RSA_TRAILER)
	
	tinc.island           = cached_tinc and cached_tinc.island

	tinc.connect_to       = get_connects(sys_conf)
	
	
	return tinc
end


local function renew_tinc_conf (sys_conf, connects)

	if not connects then connects = get_connects(sys_conf) end

	local out = io.open(sys_conf.tinc_conf_file, "w")
	assert(out, "Failed to open %s" %file)
	
	out:write( "Name = node_"..sys_conf.id.."\n")
	
	local k,v
	for k,v in pairs(connects) do
		out:write( "ConnectTo = "..v.name.."\n")
	end
	
	out:close()
	
	local pid = nixio.fs.readfile( sys_conf.tinc_pid_file )
	if pid then
		dbg("sending SIGHUP to %s=%d", sys_conf.tinc_pid_file, tonumber(pid))
		nixio.kill(tonumber(pid),sig.SIGHUP)
	end

end

local function check_tinc_conf (sys_conf, connects)

	if not connects then connects = get_connects(sys_conf) end
		
	local content = nixio.fs.readfile( sys_conf.tinc_conf_file )
	
	local node_name = content and tools.subfind(content, "Name","\n")
	
	if not content or not node_name or node_name:gsub(" ",""):gsub("\n","") ~= "Name=node_"..sys_conf.id then
		renew_tinc_conf (sys_conf)
	else
		local k,v
		for k,v in pairs(connects) do
			local c_name = tools.subfind(content,"\nConnectTo",((v.name).."\n"))
			if not c_name or c_name:gsub(" ",""):gsub("\n","") ~= ("ConnectTo="..(v.name)) then
				dbg("check_tinc_conf() NO ConnectTo for %s in %s",
				    sys_conf.tinc_hosts_dir..v.name, sys_conf.tinc_conf_file)
				renew_tinc_conf (sys_conf)
				return
			end
		end
		
		local s=0
		while true do
				
			local t_line,b,e = tools.subfind(content:sub(s+1), "ConnectTo", "\n")
			
			if t_line then

				s = s + e

				local t_name = t_line:gsub(" ",""):gsub("\n",""):gsub("ConnectTo=","")
				
				if not connects[t_name] then
					dbg("check_tinc_conf() NO %s for %s in %s",
					    sys_conf.tinc_hosts_dir..t_name, t_line:gsub("\n",""), sys_conf.tinc_conf_file)
					renew_tinc_conf(sys_conf)
					break
				end
			else
				break
			end
		end
	end
end

function del_connect (sys_conf, connect)
	
	if connect.name then
		pcall( nixio.fs.remove, sys_conf.tinc_hosts_dir..connect.name )
		check_tinc_conf(sys_conf)
		return true
	else
		return false
	end
end

function add_connect (sys_conf, connect)
	
	if connect.ip_addr and connect.port and connect.pubkey and tools.subfind(connect.pubkey,RSA_HEADER,RSA_TRAILER) and connect.name then
	
		tools.mkdirr(sys_conf.tinc_hosts_dir)
	
		local file = sys_conf.tinc_hosts_dir .. connect.name
		
		local out = io.open(file, "w")
		assert(out, "Failed to open %s" %file)
		
		out:write( "Address = "..connect.ip_addr.."\n")
		out:write( "Port = "..connect.port.."\n")
		out:write( "Subnet = "..sys_conf.mgmt_ipv6_prefix48.."::2/128".."\n" )
		out:write( connect.pubkey.."\n" )
	
		out:close()
		
		check_tinc_conf(sys_conf)
				
		return true
	else
		dbg("ERROR: add_connect() Invalid connect_to parameters")
		return false
	end
end


--function cb_reconf_tinc( sys_conf, action, out_node, path, key, oldval, newval )
--	if action == "ADD" and not oldval and type(newval) == "table" then
--		if add_connect( sys_conf, newval) then
--			return ctree.copy_path_val( action, out_node, path, key, oldval, newval)
--		end
--	elseif action == "DEL" and type(oldval) == "table" and not newval then
--		if del_connect( sys_conf, oldval) then
--			return ctree.copy_path_val( action, out_node, path, key, oldval, newval)
--		end
--	elseif action == "CHG" and type(oldval) == "table" and type(newval) == "table" then
--		if del_connect( sys_conf, oldval) then
--			if add_connect( sys_conf, newval) then
--				return ctree.copy_path_val( action, out_node, path, key, oldval, newval)
--			elseif add_connect( sys_conf, oldval) then
--				dbg("CB_SET_TINC: failed! Restored old connect_to name=%s ip=%s",
--				    oldval.name, oldval.ip_addr)
--				return oldval
--			end
--		end
--	end
--end


function cb2_set_tinc( rules, sys_conf, otree, ntree, path, begin, changed )
	if not rules then return "cb2_set_tinc" end

	local old = ctree.get_path_val(otree,path)
	local new = ctree.get_path_val(ntree,path)
	local key = ctree.get_path_leaf(path)
	assert( type(old)=="table" or type(new)=="table" )
	
	if begin and not old and new then

		if add_connect( sys_conf, new) then
			ctree.set_path_val( otree, path, get_connects(sys_conf)[key])
		end
		
	elseif not begin and old and not new then

		if del_connect( sys_conf, old) then
			ctree.set_path_val(otree,path,nil)
		end
		
	elseif not begin and old and new and changed then
		
		if del_connect( sys_conf, old) then
			
			if add_connect( sys_conf, new) then
				ctree.set_path_val( otree, path, get_connects(sys_conf)[key] )
			elseif add_connect( sys_conf, old) then
				dbg("CB_SET_TINC: failed! Restored old connect_to name=%s ip=%s", old.name, old.ip_addr)
			end
			
		end
	end
end
