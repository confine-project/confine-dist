--[[



]]--

--- CONFINE data io library.
module( "confine.tinc", package.seeall )

local nixio  = require "nixio"
local sig    = require "signal"

local ctree  = require "confine.tree"
local cdata  = require "confine.data"
local crules = require "confine.rules"
local ssl    = require "confine.ssl"
local tools  = require "confine.tools"
local dbg    = tools.dbg


local TINC_PORT = 655



local function get_mgmt_nets (sys_conf)
	
	local nets = {}
	local node_name = "node_" .. sys_conf.id
	
	local name
	for name in nixio.fs.dir( sys_conf.tinc_hosts_dir ) do
			
		if name ~= node_name then
			
			local content = nixio.fs.readfile( sys_conf.tinc_hosts_dir..name )
			
--			dbg( sys_conf.tinc_hosts_dir..file.." = "..content )
			if type(content)=="string" then
				local subnet = tools.subfind(content,"Subnet","\n")
				subnet = subnet and subnet:gsub(" ",""):gsub("Subnet=",""):gsub("\n","")
--				subnet = subnet and subnet:match("^[%x]+:.*/[%d]+")
--				dbg(tostring(subnet))
				subnet = subnet and tools.canon_ipv6(subnet) and subnet
				
				local addr  = tools.subfind(content,"Address","\n")
				addr = addr and addr:match("[%d]+%.[%d]+%.[%d]+%.[%d]+")
				
				local port  = tools.subfind(content,"Port","\n") or (addr and tools.subfind(content,"Address","\n"):match(" [%d]+[^.]+\n"))
				port = port and tonumber( (port and (port:match("[%d]+"))) or TINC_PORT )
				
				local pubkey = tools.subfind(content,ssl.RSA_HEADER,ssl.RSA_TRAILER)
				
				if subnet and addr and port and pubkey then
					nets[name] = { addr=subnet, backend="tinc_server", tinc_client=cdata.null,
						       tinc_server={addresses={[1]={addr=addr, port=port}}, is_active=true, name=name, pubkey=pubkey} }
				else
					dbg("Missing host=%s subnet=%s addr=%s port=%s pubkey=%s",
					    sys_conf.tinc_hosts_dir..name, tostring(subnet), tostring(addr), tostring(port), tostring(pubkey))
				end
				
			end
		end
	end
	
	return nets
end



--local function get_connects (sys_conf)
--	
--	local connects = {}
--	local node_name = "node_" .. sys_conf.id
--	
--	--dbg("canon_ipv6 test=%s", tools.canon_ipv6("8::8/128"))
--	
--	local file
--	for file in nixio.fs.dir( sys_conf.tinc_hosts_dir ) do
--			
--		if file ~= node_name then
--			
--			local content = nixio.fs.readfile( sys_conf.tinc_hosts_dir..file )
--			
----			dbg( sys_conf.tinc_hosts_dir..file.." = "..content )
--			
--			local subnet = content and tools.subfind(content,"Subnet","\n")
--			
--			if subnet then
--				subnet = subnet:gsub(" ",""):gsub("Subnet=",""):gsub("\n","")
--				if tools.canon_ipv6(subnet) ~= tools.canon_ipv6(sys_conf.mgmt_ipv6_prefix48.."::2/128") then
--					subnet = nil
--				end
--			end
--			
--			if subnet then
--				
--				--dbg("get_local_node_tinc file=%s: %s\nsubnet=%s %s",
--				--    file, content or "", tools.canon_ipv6(subnet), tools.canon_ipv6(sys_conf.mgmt_ipv6_prefix48.."::2/128"))
--
--				local ip_addr  = tools.subfind(content,"Address","\n")
--				local port     = tools.subfind(content,"Port","\n") or (ip_addr and ip_addr:match(" [%d]+[^.]+\n"))
--				local pubkey   = tools.subfind(content,ssl.RSA_HEADER,ssl.RSA_TRAILER)
--				local name     = file
--
--				if ip_addr and pubkey and name then
--					connects[name] = {
--						ip_addr  = ip_addr:match("[%d]+%.[%d]+%.[%d]+%.[%d]+"),
--						port     = tonumber( (port and (port:match("[%d]+"))) or TINC_PORT ),
--						pubkey   = pubkey,
--						name     = name
--					}
--				end
--				
--			end
--		end
--	end
--	
--	return connects
--end

--function get (sys_conf, cached_tinc)
--
--	local tinc = {}
--	
--	tinc.name             = "node_" .. sys_conf.id
--	
--	tinc.pubkey           = tools.subfind(nixio.fs.readfile( sys_conf.tinc_node_key_pub ),ssl.RSA_HEADER,ssl.RSA_TRAILER)
--	
--	tinc.island           = cached_tinc and cached_tinc.island
--
--	tinc.connect_to       = get_connects(sys_conf)
--	
--	
--	return tinc
--end


local function renew_tinc_conf (sys_conf, nets)

	local out = io.open(sys_conf.tinc_conf_file, "w")
	assert(out, "Failed to open %s" %file)
	
	out:write( "Name = node_"..sys_conf.id.."\n")
	
	local k,v
	for k,v in pairs(nets) do
		out:write( "ConnectTo = "..v.tinc_server.name.."\n")
	end
	
	out:close()
	
	local pid = nixio.fs.readfile( sys_conf.tinc_pid_file )
	if pid then
		dbg("sending SIGHUP to %s=%d", sys_conf.tinc_pid_file, tonumber(pid))
		nixio.kill(tonumber(pid),sig.SIGHUP)
	end

end

local function check_tinc_conf( sys_conf )

	local nets = get_mgmt_nets(sys_conf)
		
	local content = nixio.fs.readfile( sys_conf.tinc_conf_file )
	
	local node_name = content and tools.subfind(content, "Name","\n")
	
	if not content or not node_name or node_name:gsub(" ",""):gsub("\n","") ~= "Name=node_"..sys_conf.id then
		renew_tinc_conf(sys_conf, nets)
	else
		local k,v
		for k,v in pairs(nets) do
			if not content:match("ConnectTo *= *%s" %v.tinc_server.name) then
				dbg("check_tinc_conf() NO ConnectTo for %s in %s",
				    sys_conf.tinc_hosts_dir..v.tinc_server.name, sys_conf.tinc_conf_file)
				renew_tinc_conf(sys_conf, nets)
				return
			end
		end
		
		local s=0
		while true do
				
			local t_line,b,e = tools.subfind(content:sub(s+1), "ConnectTo", "\n")
			
			if t_line then

				s = s + e

				local t_name = t_line:gsub(" ",""):gsub("\n",""):gsub("ConnectTo=","")
				
				if not nets[t_name] then
					dbg("check_tinc_conf() NO %s for %s in %s",
					    sys_conf.tinc_hosts_dir..t_name, t_line:gsub("\n",""), sys_conf.tinc_conf_file)
					renew_tinc_conf(sys_conf, nets)
					return
				end
			else
				return
			end
		end
	end
end


local function del_mgmt_net(sys_conf, net)

	assert( net and net.tinc_server and net.tinc_server.name)
	
	if net.tinc_server.name == "node_"..sys_conf.id then
		dbg("NOT removing own tinc host="..sys_conf.tinc_hosts_dir..net.tinc_server.name)
	else
		pcall( nixio.fs.remove, sys_conf.tinc_hosts_dir..net.tinc_server.name )
		check_tinc_conf(sys_conf)
		return true
	end
end

--function del_connect (sys_conf, connect)
--	
--	if connect.name then
--		pcall( nixio.fs.remove, sys_conf.tinc_hosts_dir..connect.name )
--		check_tinc_conf(sys_conf)
--		return true
--	else
--		return false
--	end
--end


local function add_mgmt_net(sys_conf, otree, ntree, path)

	assert( sys_conf and otree and ntree and path)
	local nval = ctree.get_path_val(ntree,path)
	local oval = ctree.get_path_val(otree,path)
	assert( nval and not oval )

	ctree.set_path_val(otree, path, {})

	local failure = false
	failure = not crules.set_or_err( crules.add_error, otree, ntree, path.."addr", "string", "[%x]+:.*:[%x]+" ) or failure
	failure = not crules.set_or_err( crules.add_error, otree, ntree, path.."backend", "string", "^tinc_server$" ) or failure
	failure = not crules.set_or_err( crules.add_error, otree, ntree, path.."tinc_client", type(cdata.null), cdata.null ) or failure
	failure = not crules.set_or_err( crules.add_error, otree, ntree, path.."tinc_server", "table") or failure
	failure = not crules.set_or_err( crules.add_error, otree, ntree, path.."tinc_server/addresses", "table") or failure
	failure = not crules.set_or_err( crules.add_error, otree, ntree, path.."tinc_server/addresses/1", "table") or failure
	failure = not crules.set_or_err( crules.add_error, otree, ntree, path.."tinc_server/addresses/1/addr", "string", "^[%d]+%.[%d]+%.[%d]+%.[%d]+$") or failure
	failure = not crules.set_or_err( crules.add_error, otree, ntree, path.."tinc_server/addresses/1/port", "number") or failure
	failure = not crules.set_or_err( crules.add_error, otree, ntree, path.."tinc_server/is_active", "boolean") or failure
	failure = not crules.set_or_err( crules.add_error, otree, ntree, path.."tinc_server/name", "string") or failure
	failure = not crules.set_or_err( crules.add_error, otree, ntree, path.."tinc_server/pubkey", "string", "^%s.*%s$"%{ssl.RSA_HEADER,ssl.RSA_TRAILER}) or failure
	
	
	if failure then
		ctree.set_path_val( otree, path, nil )
		return false
	else
		
		ctree.set_path_val(otree, path.."tinc_server/addresses/1/island", ctree.copy_recursive(nval.tinc_server.addresses[1].island) )
		
		if nval.tinc_server.is_active then
	
			tools.mkdirr(sys_conf.tinc_hosts_dir)
		
			local file = sys_conf.tinc_hosts_dir .. nval.tinc_server.name
			
			local out = io.open(file, "w")
			assert(out, "Failed to open %s" %file)
			
			out:write( "Address = "..nval.tinc_server.addresses[1].addr.."\n")
			out:write( "Port = "..nval.tinc_server.addresses[1].port.."\n")
			out:write( "Subnet = "..nval.addr.."/128".."\n" )
			out:write( nval.tinc_server.pubkey.."\n" )
		
			out:close()
			
			check_tinc_conf(sys_conf)
		end
		
--		ctree.dump(ctree.get_path_val(otree,path))
				
		return true
	end
end

--function add_connect (sys_conf, connect)
--	
--	if connect.ip_addr and connect.port and connect.pubkey and tools.subfind(connect.pubkey,ssl.RSA_HEADER,ssl.RSA_TRAILER) and connect.name then
--	
--		tools.mkdirr(sys_conf.tinc_hosts_dir)
--	
--		local file = sys_conf.tinc_hosts_dir .. connect.name
--		
--		local out = io.open(file, "w")
--		assert(out, "Failed to open %s" %file)
--		
--		out:write( "Address = "..connect.ip_addr.."\n")
--		out:write( "Port = "..connect.port.."\n")
--		out:write( "Subnet = "..sys_conf.mgmt_ipv6_prefix48.."::2/128".."\n" )
--		out:write( connect.pubkey.."\n" )
--	
--		out:close()
--		
--		check_tinc_conf(sys_conf)
--				
--		return true
--	else
--		dbg("ERROR: add_connect() Invalid connect_to parameters")
--		return false
--	end
--end





function cb2_set_mgmt_net( rules, sys_conf, otree, ntree, path, begin, changed )
	if not rules then return "cb2_set_lsrv_mgmt_net" end
	if begin then return true end

	local old = ctree.get_path_val(otree,path)
	local new = ctree.get_path_val(ntree,path)
	assert( type(old)=="table" or type(new)=="table" )
	
	if not begin and not old and new then

		if add_mgmt_net( sys_conf, otree, ntree, path) then
--			ctree.set_path_val( otree, path, get_mgmt_nets(sys_conf)[new.tinc_server.name])
		end
		
	elseif not begin and old and not new then

		if del_mgmt_net( sys_conf, old) then
			ctree.set_path_val(otree, path, nil)
		end
		
	elseif not begin and old and new and changed then
		
		local backup_tree = ctree.copy_recursive(otree)
		
		if del_mgmt_net( sys_conf, old) then
			
			if add_mgmt_net( sys_conf, otree, ntree, path) then
--				ctree.set_path_val( otree, path, get_mgmt_nets(sys_conf)[new.tinc_server.name] )
			elseif add_mgmt_net( sys_conf, otree, backup_tree, path) then
				dbg("Failed! Restored old connect_to name=%s ip=%s", old.tinc_server.name, old.tinc_server[1].addr)
			end
			
		end
	end
end

--function cb2_set_tinc( rules, sys_conf, otree, ntree, path, begin, changed )
--	if not rules then return "cb2_set_tinc" end
--
--	local old = ctree.get_path_val(otree,path)
--	local new = ctree.get_path_val(ntree,path)
--	local key = ctree.get_path_leaf(path)
--	assert( type(old)=="table" or type(new)=="table" )
--	
--	if begin and not old and new then
--
--		if add_connect( sys_conf, new) then
--			ctree.set_path_val( otree, path, get_connects(sys_conf)[key])
--		end
--		
--	elseif not begin and old and not new then
--
----		if del_connect( sys_conf, old) then
----			ctree.set_path_val(otree,path,nil)
----		end
--		
--	elseif not begin and old and new and changed then
--		
--		if del_connect( sys_conf, old) then
--			
--			if add_connect( sys_conf, new) then
--				ctree.set_path_val( otree, path, get_connects(sys_conf)[key] )
--			elseif add_connect( sys_conf, old) then
--				dbg("CB_SET_TINC: failed! Restored old connect_to name=%s ip=%s", old.name, old.ip_addr)
--			end
--			
--		end
--	end
--end
