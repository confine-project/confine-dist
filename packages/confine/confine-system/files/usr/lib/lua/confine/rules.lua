--[[



]]--


--- CONFINE processing rules.
module( "confine.rules", package.seeall )


local tree    = require "confine.tree"
local tools   = require "confine.tools"
local sliver  = require "confine.sliver"
local ssh     = require "confine.ssh"
local tinc    = require "confine.tinc"
local node    = require "confine.node"
local system  = require "confine.system"


local tmp_rules

node_in_rules = {}
tmp_rules = node_in_rules
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
	table.insert(tmp_rules, {["/tinc/connect_to/[^/]+"]		= "CB_RECONF_TINC"})
	table.insert(tmp_rules, {["/tinc/connect_to/[^/]+/ip_addr"] 	= "CB_NOP"})
	table.insert(tmp_rules, {["/tinc/connect_to/[^/]+/port"] 	= "CB_NOP"})
	table.insert(tmp_rules, {["/tinc/connect_to/[^/]+/pubkey"] 	= "CB_NOP"})
	table.insert(tmp_rules, {["/tinc/connect_to/[^/]+/name"] 	= "CB_NOP"})

	table.insert(tmp_rules, {["/priv_ipv4_prefix"]			= "CB_SET_SYS+REBOOT"})
	table.insert(tmp_rules, {["/direct_ifaces/[^/]+"]		= "CB_NOP"})
	table.insert(tmp_rules, {["/direct_ifaces"]			= "CB_SET_SYS+SLIVERS"})
	table.insert(tmp_rules, {["/sliver_mac_prefix"]			= "CB_SET_SYS+SLIVERS"})	
	
	
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
--	table.insert(tmp_rules, {["/soft_version"]			= "CB_NOP"})
	
	table.insert(tmp_rules, {["/slivers"]				= "CB_NOP"})
	table.insert(tmp_rules, {["/slivers/[^/]+"]			= "CB_NOP"})
	table.insert(tmp_rules, {["/slivers/[^/]+/uri"]			= "CB_NOP"})

	table.insert(tmp_rules, {["/sliver_pub_ipv4_avail"]		= "CB_NOP"})



node_out_filter = {}
tmp_rules = node_out_filter
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
	table.insert(tmp_rules, {["/tinc/connect_to/[^/]+"]		= "CB_RECONF_TINC"})
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



slivers_out_rules = {
----	["/"] = {"[%d]+[-][%d]+"},
--	["/[%d]+[-][%d]+"] = {
--	  "uri", "slice", "node", "description", "instance_sn",
--	  "template", "exp_data_uri", "exp_data_sha256", "nr", "state", "errors",
--	  "interfaces", "properties" }
}





dflt_cb_tasks = {
	["CB_NOP"] 	      	= function( sys_conf, action, out_node, path, key, oldval, newval )
					return oldval or null
				end,
	["CB_FAILURE"] 	      	= function( sys_conf, action, out_node, path, key, oldval, newval )
					node.set_node_state( sys_conf, out_node, node.STATE.failure )
					return oldval
				end,
	["CB_SETUP"] 	      	= function( sys_conf, action, out_node, path, key, oldval, newval )
					node.set_node_state( sys_conf, out_node, node.STATE.setup )
					return oldval
				end,
	["CB_SET_STATE"]      	= function( sys_conf, action, out_node, path, key, oldval, newval )
					return node.set_node_state( sys_conf, out_node, out_node.set_state )
				end,
	["CB_COPY"] 	      	= function( sys_conf, action, out_node, path, key, oldval, newval )
					return tree.set_path_val( action, out_node, path, key, oldval, newval)
				end,
	["CB_SET_BOOT_SN"]     	= function( sys_conf, action, out_node, path, key, oldval, newval )
					if path=="/" and key=="boot_sn" and system.set_system_conf( sys_conf, key, newval) then
						system.reboot()
					end
				end,
	["CB_SET_UUID"]     	= function( sys_conf, action, out_node, path, key, oldval, newval )
					if path=="/" and key=="uuid" and system.set_system_conf( sys_conf, key, newval) then
						return tree.set_path_val( action, out_node, path, key, oldval, newval)
					end
				end,
				
	["CB_RECONF_TINC"]    	= function( sys_conf, action, out_node, path, key, oldval, newval )
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
						return tree.set_path_val( action, out_node, path, key, oldval, newval)
					else
						out_node.group = null
						return out_node.group
					end
				end,
				
	["CB_SET_SYS+REBOOT"]	= function( sys_conf, action, out_node, path, key, oldval, newval )
					if action == "CHG" and system.set_system_conf( sys_conf, key, newval ) then
						system.set_system_conf( sys_conf, "sys_state", "prepared" )
						out_node.boot_sn = -1
						return tree.set_path_val( action, out_node, path, key, oldval, newval)
					end
				end,
	["CB_SET_SYS+SLIVERS"]	= function( sys_conf, action, out_node, path, key, oldval, newval )
					if action == "CHG" and system.set_system_conf( sys_conf, key, newval ) then
						sliver.cb_remove_slivers( sys_conf, action, out_node, path, key, oldval, newval)
						return tree.set_path_val( action, out_node, path, key, oldval, newval)
					end
				end

	
}
