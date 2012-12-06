--[[



]]--


--- CONFINE node library.
module( "confine.node", package.seeall )


local data    = require "confine.data"
local tools   = require "confine.tools"
local ssh     = require "confine.ssh"
local tinc    = require "confine.tinc"

local dbg     = tools.dbg

local null    = data.null


STATE = {
	["setup"]  	= "setup",
	["failure"] 	= "failure",
	["safe"] 	= "safe",
	["production"]  = "production"
}



local function get_node_state ( sys_conf, cached_node )
	
	if sys_conf.sys_state == "started" and cached_node.state ~= STATE.failure then
		return STATE.safe
	end
	
	return STATE.failure
end


function set_node_state( sys_conf, node, val)


	assert( STATE[val], "Illegal node state=%s" %val)

	if (val == STATE.failure) then
		node.state = val
		system.set_system_conf(sys_conf, "sys_state", "failure")
		system.stop()
	end
	
	
	if node.state ~= STATE.failure then
	
		if (val == STATE.setup) then
			node.state = val
			
		elseif (val == STATE.safe or val == STATE.production) then
			if (node.state == STATE.safe or node.state == STATE.production) then
				node.state = val
			end
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

