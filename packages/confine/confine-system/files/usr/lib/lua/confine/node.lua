--[[



]]--


--- CONFINE node library.
module( "confine.node", package.seeall )


local data    = require "confine.data"
local tools   = require "confine.tools"
local ctree    = require "confine.tree"
local ssh     = require "confine.ssh"
local tinc    = require "confine.tinc"
local sliver  = require "confine.sliver"
local rules   = require "confine.rules"
local system  = require "confine.system"

local dbg     = tools.dbg

local null    = data.null


STATE = {
	["setup"]  	= "setup",
	["failure"] 	= "failure",
	["safe"] 	= "safe",
	["production"]  = "production"
}

local tmp_rules

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





out_filter = {}
tmp_rules = out_filter
	table.insert(tmp_rules, {["/description"]			= "CB_COPY"})
	table.insert(tmp_rules, {["/properties"]			= "CB_NOP"})
	table.insert(tmp_rules, {["/properties/[^/]+"]			= "CB_COPY"})
--	table.insert(tmp_rules, {["/properties/[^/]+/[^/]+"]		= "CB_COPY"})
	table.insert(tmp_rules, {["/cn"]				= "CB_NOP"})
	table.insert(tmp_rules, {["/cn/app_url"]			= "CB_COPY"})
	table.insert(tmp_rules, {["/cn/cndb_uri"]			= "CB_COPY"})
	table.insert(tmp_rules, {["/cn/cndb_cached_on"]			= "CB_COPY"})

	table.insert(tmp_rules, {["/uri"]				= "CB_NOP"})
	table.insert(tmp_rules, {["/id"] 				= "CB_SETUP"})
	table.insert(tmp_rules, {["/uuid"]				= "CB_SETUP"})
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
	
	table.insert(tmp_rules, {["/group"]				= "CB_NOP"})
	table.insert(tmp_rules, {["/group/uri"]				= "CB_SET_GROUP"})
	
	table.insert(tmp_rules, {["/boot_sn"] 				= "CB_BOOT_SN"})
	table.insert(tmp_rules, {["/set_state"]				= "CB_COPY"})
	table.insert(tmp_rules, {["/state"]				= "CB_SET_STATE"})
	table.insert(tmp_rules, {["/soft_version"]			= "CB_NOP"})
	
	table.insert(tmp_rules, {["/slivers"]				= "CB_NOP"})
	table.insert(tmp_rules, {["/slivers/[^/]+"]			= "CB_NOP"})
	table.insert(tmp_rules, {["/slivers/[^/]+/uri"]			= "CB_NOP"})

	table.insert(tmp_rules, {["/sliver_pub_ipv4_avail"]		= "CB_NOP"})

	table.insert(tmp_rules, {["/message"]				= "CB_NOP"})
	table.insert(tmp_rules, {["/errors"]				= "CB_NOP"})




local function get_node_state ( sys_conf, cached_node )
	
	assert( not cached_node.state or STATE[cached_node.state], "get_node_state(): Illegal node state=%s" %{tostring(val)})
	
	if sys_conf.sys_state == "started" then
		
		if cached_node.state then
			return cached_node.state
		else
			return STATE.safe
		end
	end
	
	return STATE.failure
end


function set_node_state( sys_conf, node, val)


	--dbg("set_node_state: old=%s new=%s" %{node.state, val})
	assert( STATE[val], "set_node_state(): Illegal node state=%s" %{tostring(val)})

	if (val == STATE.failure or node.state == STATE.failure) then
		sliver.remove_slivers( sys_conf, nil )
		node.state = val
		system.set_system_conf(sys_conf, "sys_state", "failure")
		system.stop()
	end
	
	
	if (val == STATE.setup) then
		node.state = val
		sliver.remove_slivers( sys_conf, nil )
		
	elseif (val == STATE.safe) then
		if (node.state == STATE.production) then
			node.state = val
			sliver.stop_slivers( sys_conf, nil )
		end

	elseif (val == STATE.production) then
		if (node.state == STATE.safe) then
			node.state = val
		--	sliver.start_slivers( sys_conf, nil )
		end
	end
	
	return node.state
end



local function get_local_node_sliver_pub_ipv4 (sys_conf)
--	dbg("get_node_conf_node_sliver_pub_ipv4....." )
--	util.dumptable(tools.str2table(sys_conf.lxc_if_keys,"[%a%d]+"))
--	util.dumptable(sys_conf.uci.slivers)

	local sliver_pub_ipv4 = sys_conf.sliver_pub_ipv4
	local sliver_pub_ipv4_range = null
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


function get_local_node( sys_conf, cached_node )

	--local cached_node = data.file_get( node_cache_file ) or {}

	dbg("------ getting current node ----")
--	assert((uci.get("confine", "node", "state") == "started"), "Node not in 'started' state")
	
	cached_node  = cached_node or {} 
	
	local node = cached_node
	
	node.uri                   = sys_conf.node_base_uri.."/node"
	node.id                    = sys_conf.id
	node.uuid                  = sys_conf.uuid
	node.pubkey                = tools.subfind(nixio.fs.readfile(sys_conf.node_pubkey_file),ssh.RSA_HEADER,ssh.RSA_TRAILER)
	node.cert                  = sys_conf.cert
	node.arch                  = sys_conf.arch
	node.soft_version          = sys_conf.soft_version
	node.local_iface           = sys_conf.local_iface
	
	node.priv_ipv4_prefix      = sys_conf.priv_ipv4_prefix
	node.sliver_mac_prefix     = sys_conf.sliver_mac_prefix
	node.sliver_pub_ipv6       = "none"
	node.sliver_pub_ipv4,
	node.sliver_pub_ipv4_avail,
	node.sliver_pub_ipv4_range = get_local_node_sliver_pub_ipv4(sys_conf)
	node.boot_sn               = sys_conf.boot_sn
	node.set_state             = cached_node.set_state
	node.state                 = get_node_state( sys_conf, cached_node )
	
	node.cn                    = cached_node.cn or {}
	
	node.description           = cached_node.description or ""

	node.direct_ifaces         = sys_conf.direct_ifaces
	
	node.properties            = cached_node.properties or {}
	
	node.tinc		   = tinc.get(sys_conf, cached_node.tinc)
	
	node.local_group           = ssh.get_node_local_group(sys_conf)
	node.group                 = cached_node.group or null --ssh.get_node_group(sys_conf, node.local_group)
	
	node.local_slivers	   = cached_node.local_slivers  or {}
	node.slivers               = {} --always recreated based on local_slivers
	
	return node
end





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
