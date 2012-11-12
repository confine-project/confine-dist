#!/usr/bin/lua
-- System variables and defaults
-- SERVER_URI=nil eg:"https://controller.confine-project.eu/api"
-- COUNT=0

local util   = require "luci.util"
local nixio  = require "nixio"
local lmo    = require "lmo"
local socket = require "socket"
local sig    = require "signal"
local lsys   = require "luci.sys"


local tree   = require "confine.tree"
local data   = require "confine.data"
local uci    = require "confine.uci"
local tinc   = require "confine.tinc"
local sliver = require "confine.sliver"

local tools  = require "confine.tools"
local dbg = tools.dbg

--table.foreach(sig, print)


local require_server_cert = false
local require_node_cert   = false


local node_cache_file          = "/tmp/confine.cache"
	
local node_www_dir             = "/www/confine"
local node_rest_confine_dir    = "/tmp/confine"
local node_rest_base_dir       = node_rest_confine_dir.."/api/"
local node_rest_node_dir       = node_rest_confine_dir.."/api/node/"
local node_rest_slivers_dir    = node_rest_confine_dir.."/api/slivers/"
local node_rest_templates_dir  = node_rest_confine_dir.."/api/templates/"

local RSA_HEADER               = "%-%-%-%-%-BEGIN RSA PUBLIC KEY%-%-%-%-%-"
local RSA_TRAILER              = "%-%-%-%-%-END RSA PUBLIC KEY%-%-%-%-%-"



local sys_conf



local count = tonumber(lsys.getenv("COUNT")) or 0

local stop = false

local function handler(signo)
	nixio.signal(nixio.const.SIGINT,  "ign")
	nixio.signal(nixio.const.SIGTERM, "ign")
	print("going to stop now...")
	stop = true
end


local STATE = {
	["setup"]  	= "setup",
	["failure"] 	= "failure",
	["safe"] 	= "safe",
	["production"]  = "production"
}


local node_rules = {}
	table.insert(node_rules, {["/description"]			= "CB_COPY"})
	table.insert(node_rules, {["/properties"]			= "CB_NOP"})
	table.insert(node_rules, {["/properties/[^/]+"]			= "CB_COPY"})
--	table.insert(node_rules, {["/properties/[^/]+/[^/]+"]		= "CB_COPY"})
	table.insert(node_rules, {["/cn"]				= "CB_NOP"})
	table.insert(node_rules, {["/cn/app_url"]			= "CB_COPY"})
	table.insert(node_rules, {["/cn/cndb_uri"]			= "CB_COPY"})
	table.insert(node_rules, {["/cn/cndb_cached_on"]		= "CB_COPY"})

	table.insert(node_rules, {["/uri"]				= "CB_NOP"})
	table.insert(node_rules, {["/id"] 				= "CB_SETUP"})
	table.insert(node_rules, {["/uuid"]				= "CB_SETUP"})
	table.insert(node_rules, {["/pubkey"] 				= "CB_SETUP"})
	table.insert(node_rules, {["/cert"] 				= "CB_SETUP"})
	table.insert(node_rules, {["/arch"]				= "CB_SETUP"})
	table.insert(node_rules, {["/local_iface"]			= "CB_SETUP"})
	table.insert(node_rules, {["/sliver_pub_ipv6"]			= "CB_SETUP"})
	table.insert(node_rules, {["/sliver_pub_ipv4"]			= "CB_SETUP"})
	table.insert(node_rules, {["/sliver_pub_ipv4_range"]		= "CB_SETUP"})

	table.insert(node_rules, {["/tinc"] 				= "CB_NOP"})
	table.insert(node_rules, {["/tinc/name"] 			= "CB_SETUP"})
	table.insert(node_rules, {["/tinc/pubkey"]			= "CB_SETUP"})
	table.insert(node_rules, {["/tinc/island"]			= "CB_COPY"})
	table.insert(node_rules, {["/tinc/island/uri"]			= "CB_COPY"})
	table.insert(node_rules, {["/tinc/connect_to"]			= "CB_NOP"})
	table.insert(node_rules, {["/tinc/connect_to/[^/]+"]		= "CB_RECONF_TINC"})
	table.insert(node_rules, {["/tinc/connect_to/[^/]+/ip_addr"] 	= "CB_NOP"})
	table.insert(node_rules, {["/tinc/connect_to/[^/]+/port"] 	= "CB_NOP"})
	table.insert(node_rules, {["/tinc/connect_to/[^/]+/pubkey"] 	= "CB_NOP"})
	table.insert(node_rules, {["/tinc/connect_to/[^/]+/name"] 	= "CB_NOP"})

	table.insert(node_rules, {["/priv_ipv4_prefix"]			= "CB_SET_SYS+REBOOT"})
	table.insert(node_rules, {["/direct_ifaces/[^/]+"]		= "CB_NOP"})
	table.insert(node_rules, {["/direct_ifaces"]			= "CB_SET_SYS+SLIVERS"})
	table.insert(node_rules, {["/sliver_mac_prefix"]		= "CB_SET_SYS+SLIVERS"})	
	
	
	table.insert(node_rules, {["/group"]				= "CB_NOP"})
	table.insert(node_rules, {["/group/uri"]			= "CB_NOP"})
	
	table.insert(node_rules, {["/boot_sn"] 				= "CB_BOOT_SN"})
	table.insert(node_rules, {["/set_state"]			= "CB_COPY"})
	table.insert(node_rules, {["/state"]				= "CB_SET_STATE"})
	table.insert(node_rules, {["/soft_version"]			= "CB_NOP"})
	
	table.insert(node_rules, {["/slivers"]				= "CB_NOP"})
	table.insert(node_rules, {["/slivers/[^/]+"]			= "CB_NOP"})
	table.insert(node_rules, {["/slivers/[^/]+/uri"]		= "CB_NOP"})

	table.insert(node_rules, {["/sliver_pub_ipv4_avail"]		= "CB_NOP"})
	table.insert(node_rules, {["/dbg_iteration"]			= "CB_NOP"})


--local node_rules = {
--	["/"] = {
----		"local_slivers",
--		"id", "pubkey", "cert", "local_iface",
--		"priv_ipv4_prefix", "sliver_mac_prefix",
--		"boot_sn", "direct_ifaces", "tinc" },
--	
--	["/tinc"] = {
--		"name", "pubkey", "connect_to" },
--
--	["/tinc/connect_to"] = "ALL",
--	["/tinc/connect_to/[^/]+"] = { "ip_addr", "port", "pubkey", "name" },
----	["/tinc/connect_to/[%a%d_]+"] = { "ip_addr", "port", "pubkey", "name" },
--
--	["/local_slivers/"] = "ALL",
----	["/local_slivers/[%d]+[-][%d]+"] = {
--	["/local_slivers/[^/]+"] = {
--		"interfaces", "local_template", "instance_sn", "local_slice" },
--	
----	["/local_slivers/[%d]+[-][%d]+/local_template"] = {
--	["/local_slivers/[^/]+/local_template"] = {
--		"local_arch", "is_active", "image_uri", "image_sha256" },
--
----	["/local_slivers/[%d]+[-][%d]+/local_slice"] = {
--	["/local_slivers/[^/]+/local_slice"] = {
--		"instance_sn", "id", "local_users", "new_sliver_instance_sn", "exp_data_uri" },
--
--	["/local_slivers/[^/]+/local_slice/local_users"] = "ALL",
----	["/local_slivers/[%d]+[-][%d]+/local_slice/local_users/[0-9]+"] = {
--	["/local_slivers/[^/]+/local_slice/local_users/[^/]+"] = {
--		"auth_tokens", "is_active" }
--}


local filter_node_out_rules = {
	--["/"] = {
	--  "uri", "id", "uuid", "pubkey", "cert", "description", "arch", "local_iface",
	--  "priv_ipv4_prefix", "sliver_mac_prefix", "sliver_pub_ipv6",
	--  "sliver_pub_ipv4", "sliver_pub_ipv4_range", "sliver_pub_ipv4_avail",
	--  "soft_version", "boot_sn", "set_state", "state",
	--  "direct_ifaces", "properties", "cn", "tinc", "admin", "slivers" },
	--["/description"] = "ALL",
	--["/tinc"] = "ALL",
	--["/tinc/connect_to"] = "ALL",
	--["/tinc/connect_to/[^/]+"] = "ALL",
}

local filter_slivers_out_rules = {
----	["/"] = {"[%d]+[-][%d]+"},
--	["/[%d]+[-][%d]+"] = {
--	  "uri", "slice", "node", "description", "instance_sn",
--	  "template", "exp_data_uri", "exp_data_sha256", "nr", "state", "errors",
--	  "interfaces", "properties" }
}








local function sleep(sec)
	local interval=1
	if stop then
		return
	else
		dbg("sleeping for %s seconds...", sec)
	end
		
	while sec>0 do
		if stop then return end
		if sec > interval then
			sec = sec - interval
		else
			interval = sec
			sec = 0
		end
		socket.select(nil, nil, interval)
	end
end




local function get_system_conf()

	if uci.dirty( "confine" ) then return false end
	
	local conf = {}
	sys_conf = conf

	conf.id                    = tonumber((uci.getd("confine", "node", "id") or "x"), 16)
	conf.uuid                  = ""
	conf.arch                  = tools.canon_arch(nixio.uname().machine)
	conf.soft_version          = (tools.subfindex( nixio.fs.readfile( "/etc/banner" ) or "???", "show%?branch=", "\n" ) or "???"):gsub("&rev=",".")

	conf.mgmt_ipv6_prefix48    = uci.getd("confine", "testbed", "mgmt_ipv6_prefix48")

	conf.node_base_uri         = "http://["..conf.mgmt_ipv6_prefix48..":".."%X"%conf.id.."::2]/confine/api"
--	conf.server_base_uri       = "https://controller.confine-project.eu/api"
	conf.server_base_uri       = lsys.getenv("SERVER_URI") or "http://["..conf.mgmt_ipv6_prefix48.."::2]/confine/api"
	
	conf.local_iface           = uci.getd("confine", "node", "local_ifname")
	
	conf.sys_state             = uci.getd("confine", "node", "state")
	conf.boot_sn               = tonumber(uci.getd("confine", "node", "boot_sn")) or 0

	conf.node_pubkey_file      = "/etc/dropbear/openssh_rsa_host_key.pub" --must match /etc/dropbear/dropbear_rsa_*
--	conf.server_cert_file      = "/etc/confine/keys/server.ca"
--	conf.node_cert_file        = "/etc/confine/keys/node.crt.pem" --must match /etc/uhttpd.crt and /etc/uhttpd.key

	conf.tinc_node_key_priv    = "/etc/tinc/confine/rsa_key.priv" -- required
	conf.tinc_node_key_pub     = "/etc/tinc/confine/rsa_key.pub"  -- created by confine_node_enable
	conf.tinc_hosts_dir        = "/etc/tinc/confine/hosts/"       -- required
	conf.tinc_conf_file        = "/etc/tinc/confine/tinc.conf"    -- created by confine_tinc_setup
	conf.tinc_pid_file         = "/var/run/tinc.confine.pid"


	
	conf.priv_ipv4_prefix      = uci.getd("confine", "node", "priv_ipv4_prefix24") .. ".0/24"
	conf.sliver_mac_prefix     = "0x" .. uci.getd("confine", "node", "mac_prefix16"):gsub(":", "")
	
	conf.sliver_pub_ipv4       = uci.getd("confine", "node", "sl_public_ipv4_proto")
	conf.sl_pub_ipv4_addrs     = uci.getd("confine", "node", "sl_public_ipv4_addrs")
	conf.sl_pub_ipv4_total     = tonumber(uci.getd("confine", "node", "public_ipv4_avail"))
	

	conf.direct_ifaces         = tools.str2table(uci.getd("confine", "node", "rd_if_iso_parents"),"[%a%d_]+")
	
	conf.lxc_if_keys           = uci.getd("lxc", "general", "lxc_if_keys" )

	conf.uci = {}
--	conf.uci.confine           = uci.get_all("confine")
	conf.uci.slivers           = uci.get_all("confine-slivers")

end

local function set_system_conf( opt, val)
	
	assert(opt and type(opt)=="string" and val, "set_system_conf()")
	
	if opt == "boot_sn" then
		
		if type(val)~="number" then return false end
		
		uci.set("confine", "node", "boot_sn", val)
		
	elseif opt == "sys_state" then
		
		if val~="prepared" or val~="applied" or val~="failure" then return false end
		
		uci.set("confine", "node", "state", val)
		
	elseif opt == "priv_ipv4_prefix" then
		
		if type(val)~="string" or not val:gsub(".0/24",""):match("[0-255].[0-255].[0-255]") then
			return false
		end
		
		uci.set("confine", "node", "priv_ipv4_prefix24", val:gsub(".0/24","") )
		
	elseif opt == "direct_ifaces" and type(val) == "table" then
		
		local devices = lsys.net.devices()
		
		local k,v
		for k,v in pairs(val) do
			if type(v)~="string" or not (v:match("^eth[%d]+$") or v:match("^wlan[%d]+$")) then
				dbg("set_system_conf() opt=%s val=%s Invalid interface prefix!", opt, tostring(v))
				return false
			end
			
			if not tools.get_table_by_key_val(devices,v) then
				dbg("set_system_conf() opt=%s val=%s Interface does NOT exist on system!",opt,tostring(v))
				return false
			end
		end
		
		uci.set("confine", "node", "rd_if_iso_parents", table.concat( val, " ") )
		
	elseif opt == "sliver_mac_prefix" and type(val) == "string" then
		
		local dec = tonumber(val,16) or 0
		local msb = math.modf(dec / 256)
		local lsb = dec - (msb*256)
		
		if msb > 0 and msb <= 255 and lsb >= 0 and lsb <= 255 then
			local mac = "%.2x:%.2x"%{msb,lsb}
			uci.set("confine","node","mac_prefix16", mac)
		else
			return false
		end

	else
		
		assert(false, "set_system_conf(): Invalid opt=%s val=%s", opt, tostring(val))
	end
	
	get_system_conf()
	return true
end


local function get_local_node_state ( cached_node )
	
	if sys_conf.sys_state == "started" and cached_node.state ~= STATE.failure then
		return STATE.safe
	end
	
	return STATE.failure
end


local function get_local_node_sliver_pub_ipv4 ()
--	dbg("get_node_conf_node_sliver_pub_ipv4....." )
--	util.dumptable(tools.str2table(sys_conf.lxc_if_keys,"[%a%d]+"))
--	util.dumptable(sys_conf.uci.slivers)

	local sliver_pub_ipv4 = sys_conf.sliver_pub_ipv4
	local sliver_pub_ipv4_range = ""
	local sliver_pub_ipv4_avail = sys_conf.sl_pub_ipv4_total
	
	if sys_conf.sliver_pub_ipv4 == "static" and type(sys_conf.sl_pub_ipv4_addrs) == "string" then
		
		sliver_pub_ipv4_range = tools.str2table(sys_conf.sl_pub_ipv4_addrs,
							"[0-255].[0-255].[0-255].[0-255]")[1].."+"..sys_conf.sl_public_ipv4_avail
	end
	
	local slk,slv
	for slk,slv in pairs(sys_conf.uci.slivers) do
		local ifk,ifv
		for ifk,ifv in pairs( tools.str2table(sys_conf.lxc_if_keys,"[%a%d]+") ) do
				
			local itk = "if"..ifv.."_type"
			local itv = sys_conf.uci.slivers[slk][itk] or ""
						
			if itv == "public" then
--				dbg("slk="..slk.." ifk="..ifk.." ifv="..ifv.." "..itk.."="..itv)
				sliver_pub_ipv4_avail = (sliver_pub_ipv4_avail > 0) and (sliver_pub_ipv4_avail - 1) or 0
			end
		end
	end

--	dbg("get_node_conf_node_sliver_pub_ipv4: "..sliver_pub_ipv4.." "..sliver_pub_ipv4_range.." "..sliver_pub_ipv4_avail)
	
	return sliver_pub_ipv4, sliver_pub_ipv4_avail, sliver_pub_ipv4_range
end


local function get_local_node( cached_node )

	--local cached_node = data.file_get( node_cache_file ) or {}

	dbg("------ getting current node ----")
--	assert((uci.get("confine", "node", "state") == "started"), "Node not in 'started' state")
	
	cached_node  = cached_node or {} 
	
	local node = cached_node
	
	node.uri                   = sys_conf.node_base_uri.."/node"
	node.id                    = sys_conf.id
	node.uuid                  = sys_conf.uuid
	node.pubkey                = tools.subfind(nixio.fs.readfile(sys_conf.node_pubkey_file),RSA_HEADER,RSA_TRAILER)
	node.cert                  = "" -- http://wiki.openwrt.org/doc/howto/certificates.overview  http://man.cx/req
	node.arch                  = sys_conf.arch
	node.soft_version          = sys_conf.soft_version
	node.local_iface           = sys_conf.local_iface
	
	node.priv_ipv4_prefix      = sys_conf.priv_ipv4_prefix
	node.sliver_mac_prefix     = sys_conf.sliver_mac_prefix
	node.sliver_pub_ipv6       = "none"
	node.sliver_pub_ipv4,
	node.sliver_pub_ipv4_avail,
	node.sliver_pub_ipv4_range = get_local_node_sliver_pub_ipv4()
	node.boot_sn               = sys_conf.boot_sn
	node.set_state             = cached_node.set_state
	node.state                 = get_local_node_state( cached_node )
	
	node.dbg_iteration         = (cached_node.dbg_iteration or 0) + 1


	node.cn                    = cached_node.cn or {}
	
	node.description           = cached_node.description or ""

	node.direct_ifaces         = sys_conf.direct_ifaces
	
	node.properties            = cached_node.properties or {}
	
	node.tinc		   = tinc.get(sys_conf, cached_node.tinc)
	
	node.group                 = cached_node.group  or {}
	node.local_group           = cached_node.local_group  or {}
	
	node.slivers               = cached_node.slivers  or {}
	node.local_slivers	   = cached_node.local_slivers  or {}
	
	return node
end


local function get_local_base( node )
	local base = {}
	base.uri                   = sys_conf.node_base_uri.."/"
	base.node_uri              = node.uri
	base.slivers_uri           = sys_conf.node_base_uri.."/slivers"
	base.templates_uri         = sys_conf.node_base_uri.."/templates"

	return base	
end


local function get_local_templates( node )

	local templates = {}
	local k,v
	if node.local_slivers then
		for k,v in pairs(node.local_slivers) do
	
			if not templates.k then
				templates.k = v
			end
		end
	end
	return templates
end




local function get_local_group(obj, cert_file, cache)

	if obj.group and obj.group.uri then
		
		obj.local_group = data.http_get(obj.group.uri, sys_conf.server_base_uri, cert_file, cache)
		assert(obj.local_group, "Unable to retrieve node.group.uri=%s" %obj.group.uri)


		if obj.local_group and obj.local_group.user_roles then
			
			obj.local_group.local_user_roles = {}
		
			local user_idx, user_uri
			for user_idx, user_uri in pairs(obj.local_group.user_roles) do
	--			dbg("calling http_get uri=%s", user_uri.uri)
				local user_obj,user_id = data.http_get(user_uri.user.uri, sys_conf.server_base_uri, cert_file, cache)
				assert(user_obj and user_id, "Unable to retrieve referenced user_url=%s" %user_uri.uri)
	
				obj.local_group.local_user_roles[user_id] = user_obj
			end
		end
	end
end


local function get_server_node()

	dbg("------ retrieving new node ------")

	local cache = {}
	local cert_file = sys_conf.server_cert_file
	
	if require_server_cert and not cert_file then
		return nil
	end
	
	local node = data.http_get("/nodes/%d" % sys_conf.id, sys_conf.server_base_uri ,cert_file, cache)
	assert(node, "Unable to retrieve node.id=%s" %sys_conf.id)
	
	get_local_group(node, cert_file, cache)
			
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

		if sliver_obj.template and sliver_obj.template.uri then
			
			local template_obj = data.http_get(sliver_obj.template.uri, sys_conf.server_base_uri, cert_file, cache)
			assert(template_obj, "Unable to retrieve referenced template_url=%s" %sliver_obj.template.uri)

			sliver_obj.local_template = template_obj
			
		elseif slice_obj.template and slice_obj.template.uri then
			
			local template_obj = data.http_get(slice_obj.template.uri, sys_conf.server_base_uri, cert_file, cache)
			assert(template_obj, "Unable to retrieve referenced template_url=%s" %slice_obj.template.uri)

			sliver_obj.local_template = template_obj
		end
		
		get_local_group(slice_obj, cert_file, cache)
		
	end
	
	luci.util.dumptable(node)
		
	return node
end




local function upd_node_rest_conf( node )
	

	data.file_put(tree.filter(node_rules, node), "index.html", node_rest_node_dir)	
	
	pcall(nixio.fs.remover, node_rest_templates_dir)
	data.file_put(get_local_templates(node), nil, node_rest_templates_dir)
	

	pcall(nixio.fs.remover, node_rest_slivers_dir)
	data.file_put(tree.filter(filter_slivers_out_rules, node.local_slivers), nil, node_rest_slivers_dir)
	
	
	local base = get_local_base( node )
	data.file_put(base, "index.html", node_rest_base_dir)

end




local function set_node_state( node, val)

	if (not STATE[val]) then
		node.state = STATE.failure
		
	elseif (val == STATE.setup) then
		if (node.state ~= STATE.failure) then
			node.state = val
		end
		
	elseif (val == STATE.safe or val == STATE.production) then
		if (node.state == STATE.safe or node.state == STATE.production) then
			node.state = val
		end
	else
		node.state = STATE.failure
		return false
	end
	
	return node.state
end




local function cb(sys_conf, action, task, cb_tasks, out_node, path, key, oldval, newval )

	local finval ="???"

	dbg("%s %-22s %-40s %s => %s", action, task, path..key,
	(oldval and tostring(oldval) or ""):gsub("\n",""):sub(1,30),
	(newval and tostring(newval) or ""):gsub("\n",""):sub(1,30))

	if cb_tasks[task] then
		
		finval = cb_tasks[task](sys_conf, action, out_node, path, key, oldval, newval)
		
		if task ~= "CB_NOP" and task ~= "CB_COPY" then			
			dbg("%s %-22s %-40s   ===> %s", action, task, path..key,
			    (finval and tostring(finval) or "ERROR"):gsub("\n",""):sub(1,30))
		end
		
	else
		dbg("cb() undefined cb_task=%s", task)
	end
	
	if not finval then
		set_node_state( out_node, STATE.setup )
	end

	
	
--	assert(sliver_obj.local_template.local_arch == own_node_arch,
--       "Sliver_arch=%q does not match local_arch=%q!"
--	   %{ sliver_obj.local_template.arch, own_node_arch })

end



local dflt_cb_tasks = {
	["CB_NOP"] 	      	= function( sys_conf, action, out_node, path, key, oldval, newval )
					return oldval or ""
				end,
	["CB_FAILURE"] 	      	= function( sys_conf, action, out_node, path, key, oldval, newval )
					set_node_state( out_node, STATE.failure )
					return oldval
				end,
	["CB_SETUP"] 	      	= function( sys_conf, action, out_node, path, key, oldval, newval )
					set_node_state( out_node, STATE.setup )
					return oldval
				end,
	["CB_SET_STATE"]      	= function( sys_conf, action, out_node, path, key, oldval, newval )
					return set_node_state( out_node, out_node.set_state )
				end,
	["CB_COPY"] 	      	= function( sys_conf, action, out_node, path, key, oldval, newval )
					return tree.set_path_val( action, out_node, path, key, oldval, newval)
				end,
	["CB_BOOT_SN"] 	      	= function( sys_conf, action, out_node, path, key, oldval, newval )
					if key == "boot_sn" and set_system_conf( key, newval) then
						dbg("rebooting...")
						sleep(2)
						os.execute("reboot")
						nixio.kill(nixio.getpid(),sig.SIGKILL)
					else
						set_node_state( out_node, STATE.safe )
					end
				end,
				
	["CB_RECONF_TINC"]    	= function( sys_conf, action, out_node, path, key, oldval, newval )
					return tinc.cb_reconf_tinc( sys_conf, action, out_node, path, key, oldval, newval )
				end,
				
	["CB_SET_SYS+REBOOT"]	= function( sys_conf, action, out_node, path, key, oldval, newval )
					if action == "CHG" and set_system_conf( key, newval ) then
						set_system_conf( "sys_state", "prepared" )
						out_node.boot_sn = -1
						return tree.set_path_val( action, out_node, path, key, oldval, newval)
					end
				end,
	["CB_SET_SYS+SLIVERS"]	= function( sys_conf, action, out_node, path, key, oldval, newval )
					if action == "CHG" and set_system_conf( key, newval ) then
						sliver.cb_remove_slivers( sys_conf, action, out_node, path, key, oldval, newval)
						return tree.set_path_val( action, out_node, path, key, oldval, newval)
					end
				end

	
}






math.randomseed( os.time() )

--for k in pairs(sig) do print(k) end
sig.signal(sig.SIGINT,  handler)
sig.signal(sig.SIGTERM, handler)

os.remove( node_cache_file )

tools.mkdirr( node_rest_confine_dir)
nixio.fs.symlink( node_rest_confine_dir, node_www_dir )

local local_node

while true do
	dbg("get_system_conf...")
	get_system_conf()
	
	if sys_conf then
		dbg("updating...")	
	
		local_node = get_local_node(local_node)

		--local se,server_node= pcall(get_server_node)		
		--if se then
		local server_node= get_server_node()
		if server_node then
			--util.dumptable(server_node)
			--dbg("tree fingerprint is %08x", lmo.hash(util.serialize_data(server_node)))
		
			dbg("comparing states...")
			tree.process(cb, sys_conf, dflt_cb_tasks, local_node, node_rules, local_node, server_node )
		else
			dbg("ERROR: "..tostring(server_node))
		end
		
		
		
		
		upd_node_rest_conf( local_node )
		data.file_put( local_node, node_cache_file )
	end
	
	if count == 1 then
		break
	elseif count > 1 then
		count = count - 1
	end
	
	sleep(5)
	if stop then break end

	dbg("next iteration=%d...",local_node.dbg_iteration + 1)
end	

dbg("goodbye")
