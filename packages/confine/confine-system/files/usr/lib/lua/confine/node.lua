--[[



]]--


--- CONFINE node library.
module( "confine.node", package.seeall )


local data    = require "confine.data"
local tools   = require "confine.tools"
local ctree    = require "confine.tree"
local ssh     = require "confine.ssh"
local ssl     = require "confine.ssl"
local tinc    = require "confine.tinc"
local sliver  = require "confine.sliver"
local crules   = require "confine.rules"
local system  = require "confine.system"

local dbg     = tools.dbg
local val2string = data.val2string

local null    = data.null


STATE = {
	["debug"]  	= "debug",
	["failure"] 	= "failure",
	["safe"] 	= "safe",
	["production"]  = "production"
}

local tmp_rules









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


function set_node_state( sys_conf, node, val, path)

	dbg("old=%s new=%s %s" %{node.state, val, (path or "")})
	
	assert( STATE[val], "set_node_state(): Illegal node state=%s" %{tostring(val)})

	if (val == STATE.failure or node.state == STATE.failure) then
		sliver.remove_slivers( sys_conf, nil )
		node.state = val
		system.set_system_conf(sys_conf, "sys_state", "failure")
		system.stop()
	end
	
	
	if (val == STATE.debug) then
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
	
	if sys_conf.sliver_pub_ipv4 == "dhcp" then
		
		sliver_pub_ipv4_range = "#"..(sys_conf.sl_pub_ipv4_total)
		
	elseif sys_conf.sliver_pub_ipv4 == "static" and type(sys_conf.sl_pub_ipv4_addrs) == "string" then
		
		sliver_pub_ipv4_range = tools.str2table(sys_conf.sl_pub_ipv4_addrs,"[0-255].[0-255].[0-255].[0-255]")[1].."#"..(sys_conf.sl_pub_ipv4_total)
	end
	
	local slk,slv
	for slk,slv in pairs(sys_conf.uci_slivers) do
		local ifk,ifv
		for ifk,ifv in pairs( tools.str2table(sys_conf.lxc_if_keys,"[%a%d]+") ) do
				
			local itk = "if"..ifv.."_type"
			local itv = sys_conf.uci_slivers[slk][itk] or ""
						
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

	dbg("------ getting current node ----")
--	assert((uci.get("confine", "node", "state") == "started"), "Node not in 'started' state")
	
	cached_node  = cached_node or {} 
	
	local node = cached_node
	
	node.errors                = nil
	
	node.uri                   = sys_conf.node_base_uri.."/node"
	node.id                    = sys_conf.id
	node.uuid                  = sys_conf.uuid
--	node.pubkey                = tools.subfind(nixio.fs.readfile(sys_conf.node_pubkey_file),ssl.RSA_HEADER,ssl.RSA_TRAILER)
	node.cert                  = tools.subfind(nixio.fs.readfile(sys_conf.node_cert_file),ssl.CERT_HEADER,ssl.CERT_TRAILER)
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
	
	node.cn                    = cached_node.cn --or {}
	
	node.description           = cached_node.description --or ""

	node.direct_ifaces         = sys_conf.direct_ifaces
	
	node.properties            = cached_node.properties --or {}
	
--	node.tinc		   = tinc.get(sys_conf, cached_node.tinc)
	node.mgmt_net		   = tinc.get_node_mgmt_net(sys_conf)
	node.local_server          = tinc.get_lserver(sys_conf)
	node.local_gateways        = tinc.get_lgateways(sys_conf)
	
	node.local_group           = ssh.get_node_local_group(sys_conf)
	node.group                 = cached_node.group or null --ssh.get_node_group(sys_conf, node.local_group)
	
	node.local_slivers	   = sliver.sys_get_lsliver( sys_conf, cached_node )
	node.slivers               = {} --always recreated based on local_slivers
	
	return node
end




function cb2_set_sys_key_and_reboot( rules, sys_conf, otree, ntree, path )
	if not rules then return "cb2_set_sys_key_and_reboot" end

	local old = ctree.get_path_val(otree,path)
	local new = ctree.get_path_val(ntree,path)
	local key = ctree.get_path_leaf(path)
	local is_table = type(old)=="table" or type(new)=="table"

	if old ~= new and not is_table and system.set_system_conf( sys_conf, key, new) then
		if sys_conf[key]~=old then
			dbg( "path=%s sys=%s old=%s new=%s", path, val2string(sys_conf[key]), val2string(old), val2string(new))
			system.reboot()
		end
	elseif old ~= new then
		assert(false, "ERR_SETUP...")
	end
end

function cb2_set_sys_key_and_reboot_prepared( rules, sys_conf, otree, ntree, path )
	if not rules then return "cb2_set_sys_key_and_reboot_prepared" end

	local old = ctree.get_path_val(otree,path)
	local new = ctree.get_path_val(ntree,path)
	local key = ctree.get_path_leaf(path)
	local is_table = type(old)=="table" or type(new)=="table"

	if old ~= new and not is_table and system.set_system_conf( sys_conf, key, new ) then
		
		if sys_conf[key]~=old then
			dbg( "path=%s sys=%s old=%s new=%s", path, val2string(sys_conf[key]), val2string(old), val2string(new))
			system.set_system_conf( sys_conf, "sys_state", "prepared" )
			system.reboot()
		end
		
	elseif old ~= new then
		assert(false, "ERR_SETUP...")
	end
end

function cb2_set_sys_and_remove_slivers( rules, sys_conf, otree, ntree, path, begin, changed )
	if not rules then return "cb2_set_sys_key_and_remove_slivers" end

	local old = ctree.get_path_val(otree,path)
	local new = ctree.get_path_val(ntree,path)
	local key = ctree.get_path_leaf(path)
	local is_table = type(old)=="table" or type(new)=="table"
	
	--dbg( "path=%s old=%s new=%s", path,
	--    (type(old)=="table" and ctree.as_string(old):gsub("\n","") or tostring(old)),
	--    (type(new)=="table" and ctree.as_string(new):gsub("\n","") or tostring(new)))

	if is_table and begin and ((not old or old==null) and new) then

		ctree.set_path_val(otree,path,{})
		
	elseif is_table and not begin and changed and system.set_system_conf( sys_conf, key, new ) then

		sliver.remove_slivers( sys_conf, nil )
		ctree.set_path_val(otree,path,sys_conf[key])
		
	elseif not is_table and old ~= new and system.set_system_conf( sys_conf, key, new ) then
		
		sliver.remove_slivers( sys_conf, nil )
		ctree.set_path_val(otree,path,sys_conf[key])
		
	elseif not is_table and old ~= new then
		
		assert(false, "ERR_SETUP...")
	end
	
end

function cb2_set_setup( rules, sys_conf, otree, ntree, path )
	if not rules then return "cb2_setup" end

	local old = ctree.get_path_val(otree,path)
	local new = ctree.get_path_val(ntree,path)

	if old ~= new then
		dbg( crules.add_error(otree, path, "Invalid Value", new) )
		set_node_state( sys_conf, otree, STATE.debug, path )
		return true
	end
end

function cb2_set_state( rules, sys_conf, otree, ntree, path )
	if not rules then return "cb2_set_state" end
	set_node_state( sys_conf, otree, otree.set_state, path )
end

function cb2_set_uuid( rules, sys_conf, otree, ntree, path )
	if not rules then return "cb2_set_uuid" end

	local old = ctree.get_path_val(otree,path)
	local new = ctree.get_path_val(ntree,path)
	
	if old == new then
		return
	elseif old == null and path=="/uuid/" and system.set_system_conf( sys_conf, "uuid", new) then
		ctree.set_path_val( otree, path, new)
	else
		set_node_state( sys_conf, otree, STATE.debug, path )
		return true
	end
end




in_rules2 = {}
tmp_rules = in_rules2
	table.insert(tmp_rules, {"/description",			crules.cb2_set})
	table.insert(tmp_rules, {"/properties",				crules.cb2_set})
	table.insert(tmp_rules, {"/properties/*",			crules.cb2_set})
	table.insert(tmp_rules, {"/properties/*/*",			crules.cb2_set})
	table.insert(tmp_rules, {"/cn",					crules.cb2_set})
	table.insert(tmp_rules, {"/cn/app_url",				crules.cb2_set})
	table.insert(tmp_rules, {"/cn/cndb_uri",			crules.cb2_set})
	table.insert(tmp_rules, {"/cn/cndb_cached_on",			crules.cb2_set})

	table.insert(tmp_rules, {"/uri",				crules.cb2_nop}) --redefined by node
	table.insert(tmp_rules, {"/id", 				cb2_set_setup}) --conflict
	table.insert(tmp_rules, {"/cert", 				cb2_set_setup})
	table.insert(tmp_rules, {"/arch",				cb2_set_setup})
	table.insert(tmp_rules, {"/local_iface",			cb2_set_setup})
	table.insert(tmp_rules, {"/sliver_pub_ipv6",			cb2_set_setup})
	table.insert(tmp_rules, {"/sliver_pub_ipv4",			cb2_set_setup})
	table.insert(tmp_rules, {"/sliver_pub_ipv4_range",		cb2_set_setup})

	table.insert(tmp_rules, {"/mgmt_net",				crules.cb2_nop})
	table.insert(tmp_rules, {"/mgmt_net/addr",			crules.cb2_nop})
	table.insert(tmp_rules, {"/mgmt_net/backend",			crules.cb2_nop})
	table.insert(tmp_rules, {"/mgmt_net/native",			crules.cb2_nop})
	table.insert(tmp_rules, {"/mgmt_net/tinc_server",		crules.cb2_nop})
	table.insert(tmp_rules, {"/mgmt_net/tinc_client",		crules.cb2_nop})
	table.insert(tmp_rules, {"/mgmt_net/tinc_client/name",		crules.cb2_nop})
	table.insert(tmp_rules, {"/mgmt_net/tinc_client/pubkey",	crules.cb2_nop})
	table.insert(tmp_rules, {"/mgmt_net/tinc_client/is_active",	crules.cb2_nop})
	table.insert(tmp_rules, {"/mgmt_net/tinc_client/island",	crules.cb2_set})
	table.insert(tmp_rules, {"/mgmt_net/tinc_client/island/uri",	crules.cb2_set})


	table.insert(tmp_rules, {"/local_server",			crules.cb2_nop})  --must exist
	table.insert(tmp_rules, {"/local_server/uri",			crules.cb2_set})
	table.insert(tmp_rules, {"/local_server/cn",			crules.cb2_set})
	table.insert(tmp_rules, {"/local_server/cn/app_url",		crules.cb2_set})
	table.insert(tmp_rules, {"/local_server/cn/cndb_uri",		crules.cb2_set})
	table.insert(tmp_rules, {"/local_server/cn/cndb_cached_on",	crules.cb2_set})
	table.insert(tmp_rules, {"/local_server/description",		crules.cb2_set})
	table.insert(tmp_rules, {"/local_server/mgmt_net",		tinc.cb2_set_mgmt_net})
	table.insert(tmp_rules, {"/local_server/mgmt_net/addr",		crules.cb2_nop})
	table.insert(tmp_rules, {"/local_server/mgmt_net/backend",	crules.cb2_nop})
	table.insert(tmp_rules, {"/local_server/mgmt_net/native",	crules.cb2_nop})
	table.insert(tmp_rules, {"/local_server/mgmt_net/tinc_server",			crules.cb2_nop})
	table.insert(tmp_rules, {"/local_server/mgmt_net/tinc_server/name",		crules.cb2_nop})
	table.insert(tmp_rules, {"/local_server/mgmt_net/tinc_server/addresses",		crules.cb2_nop})
	table.insert(tmp_rules, {"/local_server/mgmt_net/tinc_server/addresses/*",		crules.cb2_nop})
	table.insert(tmp_rules, {"/local_server/mgmt_net/tinc_server/addresses/*/addr",		crules.cb2_nop})
	table.insert(tmp_rules, {"/local_server/mgmt_net/tinc_server/addresses/*/port",		crules.cb2_nop})
	table.insert(tmp_rules, {"/local_server/mgmt_net/tinc_server/addresses/*/island",	crules.cb2_nop})
	table.insert(tmp_rules, {"/local_server/mgmt_net/tinc_server/addresses/*/island/uri",	crules.cb2_nop})
	table.insert(tmp_rules, {"/local_server/mgmt_net/tinc_server/pubkey",		crules.cb2_nop})
	table.insert(tmp_rules, {"/local_server/mgmt_net/tinc_server/is_active",	crules.cb2_nop})


	table.insert(tmp_rules, {"/local_gateways",			crules.cb2_set})  --must exist
	table.insert(tmp_rules, {"/local_gateways/*",			crules.cb2_set})
	table.insert(tmp_rules, {"/local_gateways/*/uri",		crules.cb2_set})
	table.insert(tmp_rules, {"/local_gateways/*/cn",		crules.cb2_set})
	table.insert(tmp_rules, {"/local_gateways/*/cn/app_url",	crules.cb2_set})
	table.insert(tmp_rules, {"/local_gateways/*/cn/cndb_uri",	crules.cb2_set})
	table.insert(tmp_rules, {"/local_gateways/*/cn/cndb_cached_on",	crules.cb2_set})
	table.insert(tmp_rules, {"/local_gateways/*/description",	crules.cb2_set})
	table.insert(tmp_rules, {"/local_gateways/*/mgmt_net",		tinc.cb2_set_mgmt_net})
	table.insert(tmp_rules, {"/local_gateways/*/mgmt_net/addr",	crules.cb2_nop})
	table.insert(tmp_rules, {"/local_gateways/*/mgmt_net/backend",	crules.cb2_nop})
	table.insert(tmp_rules, {"/local_gateways/*/mgmt_net/native",	crules.cb2_nop})
	table.insert(tmp_rules, {"/local_gateways/*/mgmt_net/tinc_server",		crules.cb2_nop})
	table.insert(tmp_rules, {"/local_gateways/*/mgmt_net/tinc_server/name",		crules.cb2_nop})
	table.insert(tmp_rules, {"/local_gateways/*/mgmt_net/tinc_server/addresses",		crules.cb2_nop})
	table.insert(tmp_rules, {"/local_gateways/*/mgmt_net/tinc_server/addresses/*",		crules.cb2_nop})
	table.insert(tmp_rules, {"/local_gateways/*/mgmt_net/tinc_server/addresses/*/addr",	crules.cb2_nop})
	table.insert(tmp_rules, {"/local_gateways/*/mgmt_net/tinc_server/addresses/*/port",	crules.cb2_nop})
	table.insert(tmp_rules, {"/local_gateways/*/mgmt_net/tinc_server/addresses/*/island",	crules.cb2_nop})
	table.insert(tmp_rules, {"/local_gateways/*/mgmt_net/tinc_server/addresses/*/island/uri",crules.cb2_nop})
	table.insert(tmp_rules, {"/local_gateways/*/mgmt_net/tinc_server/pubkey",	crules.cb2_nop})
	table.insert(tmp_rules, {"/local_gateways/*/mgmt_net/tinc_server/is_active",	crules.cb2_nop})
	


--FIXME	table.insert(tmp_rules, {"/priv_ipv4_prefix",			cb2_set_sys_key_and_reboot_prepared})
	table.insert(tmp_rules, {"/direct_ifaces",			cb2_set_sys_and_remove_slivers})
	table.insert(tmp_rules, {"/direct_ifaces/*",			crules.cb2_nop})  --handled by direct_ifaces
--FIXME	table.insert(tmp_rules, {"/sliver_mac_prefix",			cb2_set_sys_and_remove_slivers})	
	
	table.insert(tmp_rules, {"/local_group",						ssh.cb2_set_lgroup}) --"CB_GET_LOCAL_GROUP"})
	table.insert(tmp_rules, {"/local_group/uri",						crules.cb2_set})
	table.insert(tmp_rules, {"/local_group/user_roles",					crules.cb2_nop}) --must exist
	table.insert(tmp_rules, {"/local_group/user_roles/*",		 			ssh.cb2_set_lgroup_role})
	table.insert(tmp_rules, {"/local_group/user_roles/*/is_technician",			crules.cb2_nop}) --handled by set_local_group_role
	table.insert(tmp_rules, {"/local_group/user_roles/*/is_admin",				crules.cb2_nop}) --handled by set_local_group_role
	table.insert(tmp_rules, {"/local_group/user_roles/*/local_user", 	   		crules.cb2_nop}) --handled by set_local_group_role
	table.insert(tmp_rules, {"/local_group/user_roles/*/local_user/is_active",		crules.cb2_nop}) --handled by set_local_group_role
	table.insert(tmp_rules, {"/local_group/user_roles/*/local_user/auth_tokens",		crules.cb2_nop}) --handled by set_local_group_role
	table.insert(tmp_rules, {"/local_group/user_roles/*/local_user/auth_tokens/*",		crules.cb2_nop}) --handled by set_local_group_role
--	
	table.insert(tmp_rules, {"/group",				crules.cb2_nop}) --handled by ssh.cb2_set_lgroup
	table.insert(tmp_rules, {"/group/uri",				crules.cb2_nop}) --handled by ssh.cb2_set_lgroup
--	
	table.insert(tmp_rules, {"/boot_sn", 				cb2_set_sys_key_and_reboot})
	table.insert(tmp_rules, {"/set_state",				crules.cb2_set})
	table.insert(tmp_rules, {"/state",				cb2_set_state})
--
	table.insert(tmp_rules, {"/local_slivers",			crules.cb2_nop}) --must exist
	table.insert(tmp_rules, {"/local_slivers/*",			sliver.cb2_set_lsliver})
	
	table.insert(tmp_rules, {"/slivers",				sliver.cb2_set_slivers}) --point to local_slivers
--
--	table.insert(tmp_rules, {["/sliver_pub_ipv4_avail"]		= "CB_NOP"})



out_filter = {}
tmp_rules = out_filter
	table.insert(tmp_rules, {"/description"})
	table.insert(tmp_rules, {"/properties"})
	table.insert(tmp_rules, {"/properties/*"})
	table.insert(tmp_rules, {"/properties/*/*"})
	table.insert(tmp_rules, {"/cn"})
	table.insert(tmp_rules, {"/cn/app_url"})
	table.insert(tmp_rules, {"/cn/cndb_uri"})
	table.insert(tmp_rules, {"/cn/cndb_cached_on"})

	table.insert(tmp_rules, {"/uri"})
	table.insert(tmp_rules, {"/id"})
--	table.insert(tmp_rules, {"/uuid"})
	table.insert(tmp_rules, {"/pubkey"})
	table.insert(tmp_rules, {"/cert"})
	table.insert(tmp_rules, {"/arch"})
	table.insert(tmp_rules, {"/local_iface"})
	table.insert(tmp_rules, {"/sliver_pub_ipv6"})
	table.insert(tmp_rules, {"/sliver_pub_ipv4"})
	table.insert(tmp_rules, {"/sliver_pub_ipv4_range"})

	table.insert(tmp_rules, {"/mgmt_net"})
	table.insert(tmp_rules, {"/mgmt_net/addr"})
	table.insert(tmp_rules, {"/mgmt_net/backend"})
	table.insert(tmp_rules, {"/mgmt_net/tinc_server"})
	table.insert(tmp_rules, {"/mgmt_net/tinc_client"})
	table.insert(tmp_rules, {"/mgmt_net/tinc_client/name"})
	table.insert(tmp_rules, {"/mgmt_net/tinc_client/addresses"})
	table.insert(tmp_rules, {"/mgmt_net/tinc_client/addresses/*"})
	table.insert(tmp_rules, {"/mgmt_net/tinc_client/addresses/*/addr"})
	table.insert(tmp_rules, {"/mgmt_net/tinc_client/addresses/*/port"})
	table.insert(tmp_rules, {"/mgmt_net/tinc_client/addresses/*/island"})
	table.insert(tmp_rules, {"/mgmt_net/tinc_client/addresses/*/island/uri"})
	table.insert(tmp_rules, {"/mgmt_net/tinc_client/pubkey"})
	table.insert(tmp_rules, {"/mgmt_net/tinc_client/is_active"})

	table.insert(tmp_rules, {"/priv_ipv4_prefix"})
	table.insert(tmp_rules, {"/direct_ifaces/*"})
	table.insert(tmp_rules, {"/direct_ifaces"})
	table.insert(tmp_rules, {"/sliver_mac_prefix"})	
	
	table.insert(tmp_rules, {"/group"})
	table.insert(tmp_rules, {"/group/uri"})
	
	table.insert(tmp_rules, {"/boot_sn"})
	table.insert(tmp_rules, {"/set_state"})
	table.insert(tmp_rules, {"/state"})
	table.insert(tmp_rules, {"/soft_version"})
	
	table.insert(tmp_rules, {"/slivers"})
	table.insert(tmp_rules, {"/slivers/*"})
	table.insert(tmp_rules, {"/slivers/*/uri"})

	table.insert(tmp_rules, {"/sliver_pub_ipv4_avail"})

	table.insert(tmp_rules, {"/message"})
	table.insert(tmp_rules, {"/errors"})
	table.insert(tmp_rules, {"/errors/*"})
	table.insert(tmp_rules, {"/errors/*/member"})
	table.insert(tmp_rules, {"/errors/*/message"})
