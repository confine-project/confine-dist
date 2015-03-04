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









local function get_new_cycle_lnode_state ( sys_conf, cached_node )
	
	assert( not cached_node.state or STATE[cached_node.state], "get_new_cycle_lnode_state(): Illegal node state=%s" %{tostring(val)})
	
	if sys_conf.sys_state == "started" then
		
		if not cached_node.state or cached_node.state==STATE.debug then
			return STATE.safe
		else
			return cached_node.state
		end
	end
	
	return STATE.failure
end


function set_node_state( sys_conf, node, val, path)

	dbg("old=%s new=%s path=%s" %{node.state, val, (path or "")})
	
	assert( STATE[val], "set_node_state(): Illegal node state=%s" %{tostring(val)})

	if (val == STATE.failure or node.state == STATE.failure) then
		sliver.remove_slivers( sys_conf, node, nil )
		node.state = val
		system.set_system_conf(sys_conf, "sys_state", "failure")
		system.stop()
	end
	
	
	if (val == STATE.debug) then
		node.state = val
		sliver.remove_slivers( sys_conf, node, nil )
		
	elseif (val == STATE.safe) then
		if (node.state == STATE.production) then
			node.state = val
			sliver.remove_slivers( sys_conf, node, nil )
		end

	elseif (val == STATE.production) then
		if (node.state == STATE.safe) then
			node.state = val
		--	sliver.start_slivers( sys_conf, nil )
		end
	end
	
	return node.state
end



local function get_lnode_sliver_pub_ipv4 (sys_conf)

	local sliver_pub_ipv4_proto = "none"
	local sliver_pub_ipv4_range = null
	
	if sys_conf.sl_pub_ipv4_proto == "dhcp" then
		
		sliver_pub_ipv4_proto = "dhcp"
		sliver_pub_ipv4_range = "#"..(sys_conf.sl_pub_ipv4_total)
		
	elseif sys_conf.sl_pub_ipv4_proto == "static" and type(sys_conf.sl_pub_ipv4_addrs) == "string" then
		
		sliver_pub_ipv4_proto = "range"
		sliver_pub_ipv4_range = tools.str2table(sys_conf.sl_pub_ipv4_addrs,"[0-255].[0-255].[0-255].[0-255]")[1].."#"..(sys_conf.sl_pub_ipv4_total)

	end
	
	return sliver_pub_ipv4_proto, sliver_pub_ipv4_range
end

function get_node_mgmt_net(sys_conf)
	
	if type(sys_conf.tinc_gateway) == "string" then
		return tinc.get_tinc_mgmt_net(sys_conf)
	else
		
		return {addr=sys_conf.addrs.mgmt, backend="native"}, null
	end
end



function get_new_cycle_lnode( sys_conf, cached_node )

	dbg("------ getting current node ----")
--	assert((uci.get("confine", "node", "state") == "started"), "Node not in 'started' state")
	
	cached_node  = cached_node or {} 
	
	local node = cached_node
	
	node.errors                = {}
	
	node.uri                   = sys_conf.node_base_uri.."/node/"
	node.id                    = sys_conf.id
	node.uuid                  = sys_conf.uuid
	node.cert                  = tools.subfind(nixio.fs.readfile(sys_conf.node_cert_file) or "",ssl.CERT_HEADER,ssl.CERT_TRAILER) or null
	node.api                   = { type="node", base_uri=sys_conf.node_base_uri.."/", cert=node.cert }
	node.arch                  = sys_conf.arch
	node.soft_version          = sys_conf.soft_version
	
	node.sliver_pub_ipv6       = "none"
	node.sliver_pub_ipv4,
	node.sliver_pub_ipv4_range = get_lnode_sliver_pub_ipv4(sys_conf)
	
	node.addrs                 = sys_conf.addrs
	
--	node.disk_max_per_sliver   = sys_conf.disk_max_per_sliver
--	node.disk_dflt_per_sliver  = sys_conf.disk_dflt_per_sliver
	
	node.boot_sn               = sys_conf.boot_sn
	node.set_state             = cached_node.set_state
	node.state                 = get_new_cycle_lnode_state( sys_conf, cached_node )
	
	node.cn                    = cached_node.cn --or {}
	
	node.description           = cached_node.description --or ""

	node.direct_ifaces         = sys_conf.direct_ifaces
	
	node.properties            = cached_node.properties --or {}
----	

	node.mgmt_net,node.tinc    = get_node_mgmt_net(sys_conf)
--	node.mgmt_net		   = get_tinc_net(sys_conf, "node_" .. sys_conf.id)
	
--	node.local_group           = ssh.sys_get__lgroup(sys_conf.ssh_node_auth_file, true)
	node.group                 = cached_node.group or null --ssh.get_node_group(sys_conf, node.local_group)
	
	node.local_slivers	   = sliver.sys_get_lslivers( sys_conf, cached_node )
	node.slivers               = {} --always recreated based on local_slivers
	
	return node
end


function cb2_get_disk_avail( rules, sys_conf, otree, ntree, path )
	if not rules then return "cb2_get_disk_avail" end

	sliver.purge_templates( sys_conf, otree )
	
	ctree.set_path_val( otree, path, sys_conf.disk_avail )
end

function set_sys_key_and_more( sys_conf, otree, ntree, path, sys_state, reboot )

	local old = ctree.get_path_val(otree,path)
	local new = ctree.get_path_val(ntree,path)
	local key = ctree.get_path_leaf(path)
	local is_table = type(old)=="table" or type(new)=="table"

	if new and old ~= new and not is_table and system.set_system_conf( sys_conf, key, new ) then
		
		if sys_conf[key]~=old then
			dbg( "path=%s sys=%s old=%s new=%s", path, val2string(sys_conf[key]), val2string(old), val2string(new))
			if sys_state then
				system.set_system_conf( sys_conf, "sys_state", sys_state )
			end
			if reboot then
				system.reboot()
			end
		end
		
	elseif new and old ~= new then
		assert(false, "ERR_SETUP...")
	end
end

function cb2_set_sys_key( rules, sys_conf, otree, ntree, path )
	if not rules then return "cb2_set_sys_key" end
	
	set_sys_key_and_more( sys_conf, otree, ntree, path, nil, nil )
end

function cb2_set_sys_key_and_reboot( rules, sys_conf, otree, ntree, path )
	if not rules then return "cb2_set_sys_key_and_reboot" end
	
	set_sys_key_and_more( sys_conf, otree, ntree, path, nil, true )
end

function cb2_set_sys_key_and_reboot_prepared( rules, sys_conf, otree, ntree, path )
	if not rules then return "cb2_set_sys_key_and_reboot_prepared" end
	
	set_sys_key_and_more( sys_conf, otree, ntree, path, "prepared", true )
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

		sliver.remove_slivers( sys_conf, otree, nil )
		ctree.set_path_val(otree,path,sys_conf[key])
		
	elseif not is_table and old ~= new and system.set_system_conf( sys_conf, key, new ) then
		
		sliver.remove_slivers( sys_conf, otree, nil )
		ctree.set_path_val(otree,path,sys_conf[key])
		
	elseif not is_table and old ~= new then
		
		assert(false, "ERR_SETUP...")
	end
	
end

function cb2_set_resources( rules, sys_conf, otree, ntree, path, begin, changed, error_msg)
	if not rules then return "cb2_set_resources" end

	local new = ctree.get_path_val(ntree,path)

	if begin then
		
		local resources = {
			disk = {name="disk", unit="MiB", max_req=sys_conf.disk_max_per_sliver, dflt_req=sys_conf.disk_dflt_per_sliver, avail=0},
			pub_ipv6 = {name="pub_ipv6", unit="addrs", max_req=0, dflt_req=0, avail=0},
			pub_ipv4 = {name="pub_ipv4", unit="addrs", max_req=(sys_conf.sl_pub_ipv4_total>=1 and 1 or 0), dflt_req=0, avail=0}
		}
		
		ctree.set_path_val(otree, path, resources)
		
	elseif not begin then
		
		local failure = false
		
		if new then
			failure = not crules.chk_or_err( crules.add_error, otree, ntree, path, "table") or failure
		end
		
		if new and new.disk then
			failure = not crules.chk_or_err( crules.add_error, otree, ntree, path.."disk", "table") or failure
			failure = not crules.set_or_err( crules.add_error, otree, ntree, path.."disk/name", "string", {"^disk$"} ) or failure
			failure = not crules.set_or_err( crules.add_error, otree, ntree, path.."disk/unit", "string", {"^MiB$"} ) or failure
			failure = not crules.set_or_err( crules.add_error, otree, ntree, path.."disk/max_req", "number", {10000}, false, "Must be integer <= 10000 !") or failure
			failure = not crules.set_or_err( crules.add_error, otree, ntree, path.."disk/dflt_req", "number", {otree.resources.disk.max_req}, false, "Must be integer <= "..otree.resources.disk.max_req.." !") or failure
		end
		
		if new and new.pub_ipv4 then
			failure = not crules.chk_or_err( crules.add_error, otree, ntree, path.."pub_ipv4", "table") or failure
			failure = not crules.set_or_err( crules.add_error, otree, ntree, path.."pub_ipv4/name", "string", {"^pub_ipv4$"} ) or failure
			failure = not crules.set_or_err( crules.add_error, otree, ntree, path.."pub_ipv4/unit", "string", {"^addrs$"} ) or failure
			failure = not crules.set_or_err( crules.add_error, otree, ntree, path.."pub_ipv4/max_req", "number", {(sys_conf.sl_pub_ipv4_total>=1 and 1 or 0)}) or failure
			failure = not crules.set_or_err( crules.add_error, otree, ntree, path.."pub_ipv4/dflt_req", "number", {0}) or failure
		end

		if new and new.pub_ipv6 then
			failure = not crules.chk_or_err( crules.add_error, otree, ntree, path.."pub_ipv6", "table") or failure
			failure = not crules.set_or_err( crules.add_error, otree, ntree, path.."pub_ipv6/name", "string", {"^pub_ipv6$"} ) or failure
			failure = not crules.set_or_err( crules.add_error, otree, ntree, path.."pub_ipv6/unit", "string", {"^addrs$"} ) or failure
			failure = not crules.set_or_err( crules.add_error, otree, ntree, path.."pub_ipv6/max_req", "number", {0}) or failure
			failure = not crules.set_or_err( crules.add_error, otree, ntree, path.."pub_ipv6/dflt_req", "number", {0}) or failure
		end
		
		if not failure then
			if otree.resources.disk.max_req ~= sys_conf.disk_max_per_sliver then
				system.set_system_conf(sys_conf, "disk_max_per_sliver", otree.resources.disk.max_req)
			end
			if otree.resources.disk.dflt_req ~= sys_conf.disk_dflt_per_sliver then
				system.set_system_conf(sys_conf, "disk_dflt_per_sliver", otree.resources.disk.dflt_req)
			end
		end
	end
	
end

function cb2_set_direct_ifaces( rules, sys_conf, otree, ntree, path, begin, changed, error_msg)
	if not rules then return "cb2_set_direct_ifaces" end

	local old = ctree.get_path_val(otree,path)
	local new = ctree.get_path_val(ntree,path)
	local key = ctree.get_path_leaf(path)
	assert (type(old)=="table" or type(new)=="table")
	
	if begin and ((not old or old==null) and new) then

		ctree.set_path_val(otree,path,{})
		
	elseif not begin and changed then
		
		if system.check_direct_ifaces( new, true ) then
		
			system.set_system_conf( sys_conf, key, new )
			sliver.remove_slivers( sys_conf, otree, nil )
			ctree.set_path_val(otree,path,sys_conf[key])
			
		else
			
			dbg( crules.add_error(otree, path, "contains invalid or non-existing interface name(s)", new) )
			set_node_state( sys_conf, otree, STATE.debug, path )
			return true
		end
		
	end
end

function cb2_set_setup( rules, sys_conf, otree, ntree, path, begin, changed, error_msg)
	if not rules then return "cb2_setup" end

	local old = ctree.get_path_val(otree,path)
	local new = ctree.get_path_val(ntree,path)

	if old ~= new then
		dbg( crules.add_error(otree, path, "%s"%{type(error_msg)=="string" and error_msg or "Invalid "}, new) )
		set_node_state( sys_conf, otree, STATE.debug, path )
		return true
	end
end

function cb2_set_state( rules, sys_conf, otree, ntree, path )
	if not rules then return "cb2_set_state" end
	
	assert(not otree.errors or type(otree.errors)=="table")
	
	if otree.errors and tools.get_table_items(otree.errors)>0 then
		
		sys_conf.err_cnt = sys_conf.err_cnt + 1
		
		local k,v
		for k,v in pairs( otree.errors ) do
			
			if v.message:sub(1,9)=="ERR_RETRY" and (sys_conf.retry_limit==0 or sys_conf.retry_limit >= sys_conf.err_cnt) then
				v.message:gsub("ERR_RETRY","ERR_RETRY (%d/%d)"%{sys_conf.err_cnt, sys_conf.retry_limit})
			else
				set_node_state(sys_conf, otree, STATE.debug, path)
				return
			end
		end
	else
		sys_conf.err_cnt = 0
	end
		
		
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



function cb2_lnode_lgroup_role( rules, sys_conf, otree, ntree, path, begin, changed )
	if not rules then return "cb2_lnode_lgroup_role" end
	
	return ssh.sys_set__lgroup_role( sys_conf.ssh_node_auth_file, sys_conf.sync_node_admins, true, otree, ntree, path, begin, changed )
end


in_rules2 = {}
tmp_rules = in_rules2
	table.insert(tmp_rules, {"/description",			crules.cb2_set})
	table.insert(tmp_rules, {"/name",				crules.cb2_set})
	table.insert(tmp_rules, {"/properties",				crules.cb2_set})
	table.insert(tmp_rules, {"/properties/*",			crules.cb2_set})
	table.insert(tmp_rules, {"/properties/*/*",			crules.cb2_set})
	table.insert(tmp_rules, {"/cn",					crules.cb2_set})
	table.insert(tmp_rules, {"/cn/app_url",				crules.cb2_set})
	table.insert(tmp_rules, {"/cn/cndb_uri",			crules.cb2_set})
	table.insert(tmp_rules, {"/island",				crules.cb2_set})
	table.insert(tmp_rules, {"/island/uri",				crules.cb2_set})
	table.insert(tmp_rules, {"/island/id",				crules.cb2_set})

	table.insert(tmp_rules, {"/uri",				crules.cb2_nop}) --redefined by node
	table.insert(tmp_rules, {"/id", 				cb2_set_setup, "can only be changed manually (during customization or by installing pre-customized images)!"}) --conflict
	table.insert(tmp_rules, {"/api", 				crules.cb2_nop})
	table.insert(tmp_rules, {"/api/type", 				crules.cb2_nop})
	table.insert(tmp_rules, {"/api/base_uri",			crules.cb2_nop})
	table.insert(tmp_rules, {"/api/cert", 				crules.cb2_nop})

	table.insert(tmp_rules, {"/arch",				cb2_set_setup, "differs from predefined RD hardware!"})

	table.insert(tmp_rules, {"/mgmt_net",				crules.cb2_nop})
	table.insert(tmp_rules, {"/mgmt_net/addr",			crules.cb2_nop})
	table.insert(tmp_rules, {"/mgmt_net/backend",			crules.cb2_nop})

	table.insert(tmp_rules, {"/tinc",				crules.cb2_nop})
	table.insert(tmp_rules, {"/tinc/name",				crules.cb2_nop})
	table.insert(tmp_rules, {"/tinc/pubkey",			crules.cb2_nop})
	table.insert(tmp_rules, {"/tinc/addresses",			crules.cb2_nop})
	table.insert(tmp_rules, {"/tinc/addresses/*",			crules.cb2_nop})
	table.insert(tmp_rules, {"/tinc/addresses/*/*",			crules.cb2_nop})

--[[
	table.insert(tmp_rules, {"/local_gateways",						crules.cb2_set})  --must exist
	table.insert(tmp_rules, {"/local_gateways/*",						crules.cb2_set})
	table.insert(tmp_rules, {"/local_gateways/*/uri",					crules.cb2_set})
	table.insert(tmp_rules, {"/local_gateways/*/cn",					crules.cb2_set})
	table.insert(tmp_rules, {"/local_gateways/*/cn/app_url",				crules.cb2_set})
	table.insert(tmp_rules, {"/local_gateways/*/cn/cndb_uri",				crules.cb2_set})
	table.insert(tmp_rules, {"/local_gateways/*/description",				crules.cb2_set})
	table.insert(tmp_rules, {"/local_gateways/*/mgmt_net",					tinc.cb2_mgmt_net})
	table.insert(tmp_rules, {"/local_gateways/*/mgmt_net/addr",				crules.cb2_set})
	table.insert(tmp_rules, {"/local_gateways/*/mgmt_net/backend",				crules.cb2_set})
	table.insert(tmp_rules, {"/local_gateways/*/mgmt_net/native",				crules.cb2_set})
	table.insert(tmp_rules, {"/local_gateways/*/mgmt_net/tinc_server",			crules.cb2_set})
	table.insert(tmp_rules, {"/local_gateways/*/mgmt_net/tinc_server/name",			crules.cb2_set})
	table.insert(tmp_rules, {"/local_gateways/*/mgmt_net/tinc_server/addresses",		crules.cb2_set})
	table.insert(tmp_rules, {"/local_gateways/*/mgmt_net/tinc_server/addresses/*",		crules.cb2_set})
	table.insert(tmp_rules, {"/local_gateways/*/mgmt_net/tinc_server/addresses/*/addr",	crules.cb2_set})
	table.insert(tmp_rules, {"/local_gateways/*/mgmt_net/tinc_server/addresses/*/port",	crules.cb2_set})
	table.insert(tmp_rules, {"/local_gateways/*/mgmt_net/tinc_server/addresses/*/island",	crules.cb2_set})
	table.insert(tmp_rules, {"/local_gateways/*/mgmt_net/tinc_server/addresses/*/island/uri",crules.cb2_set})
	table.insert(tmp_rules, {"/local_gateways/*/mgmt_net/tinc_server/pubkey",		crules.cb2_set})
	table.insert(tmp_rules, {"/local_gateways/*/mgmt_net/tinc_server/is_active",		crules.cb2_set})
]]--


	table.insert(tmp_rules, {"/direct_ifaces",			cb2_set_direct_ifaces})
	table.insert(tmp_rules, {"/direct_ifaces/*",			crules.cb2_nop})  --handled by direct_ifaces
	
	table.insert(tmp_rules, {"/local_group",						crules.cb2_set}) --must exist
	table.insert(tmp_rules, {"/local_group/uri",						crules.cb2_set})
	table.insert(tmp_rules, {"/local_group/user_roles",					crules.cb2_set}) --must exist
	table.insert(tmp_rules, {"/local_group/user_roles/*",		 			cb2_lnode_lgroup_role})
	table.insert(tmp_rules, {"/local_group/user_roles/*/is_node_admin",			crules.cb2_set}) --handled by set_local_group_role
	table.insert(tmp_rules, {"/local_group/user_roles/*/is_group_admin",			crules.cb2_set}) --handled by set_local_group_role
	table.insert(tmp_rules, {"/local_group/user_roles/*/local_user", 	   		crules.cb2_set}) --handled by set_local_group_role
	table.insert(tmp_rules, {"/local_group/user_roles/*/local_user/is_active",		crules.cb2_set}) --handled by set_local_group_role
	table.insert(tmp_rules, {"/local_group/user_roles/*/local_user/auth_tokens",		crules.cb2_set}) --handled by set_local_group_role
	table.insert(tmp_rules, {"/local_group/user_roles/*/local_user/auth_tokens/*",		crules.cb2_set}) --handled by set_local_group_role
--	
	table.insert(tmp_rules, {"/group",				crules.cb2_set})
	table.insert(tmp_rules, {"/group/uri",				crules.cb2_set})
	table.insert(tmp_rules, {"/group/id",				crules.cb2_set})
	
--	
	table.insert(tmp_rules, {"/boot_sn", 				cb2_set_sys_key_and_reboot})
	table.insert(tmp_rules, {"/set_state",				crules.cb2_set})
	table.insert(tmp_rules, {"/state",				cb2_set_state})
	
	table.insert(tmp_rules, {"/resources",				cb2_set_resources})
	
--
	table.insert(tmp_rules, {"/local_slivers",			crules.cb2_nop}) --must exist
	table.insert(tmp_rules, {"/local_slivers/*",			sliver.cb2_set_lsliver})
	
	table.insert(tmp_rules, {"/slivers",				sliver.cb2_set_slivers}) --point to local_slivers
--
	table.insert(tmp_rules, {"/resources",				crules.cb2_nop})
	table.insert(tmp_rules, {"/resources/pub_ipv4",			crules.cb2_nop})
	table.insert(tmp_rules, {"/resources/pub_ipv4/avail",		sliver.cb2_lnode_sliver_pub_ipv4_avail})
	table.insert(tmp_rules, {"/resources/disk",			crules.cb2_nop})
	table.insert(tmp_rules, {"/resources/disk/avail",		cb2_get_disk_avail})
	


out_filter = {}
tmp_rules = out_filter
	table.insert(tmp_rules, {"/description"})
	table.insert(tmp_rules, {"/name"})
	table.insert(tmp_rules, {"/properties"})
	table.insert(tmp_rules, {"/properties/*"})
	table.insert(tmp_rules, {"/properties/*/*"})
	table.insert(tmp_rules, {"/cn"})
	table.insert(tmp_rules, {"/cn/app_url"})
	table.insert(tmp_rules, {"/cn/cndb_uri"})
	table.insert(tmp_rules, {"/island"})
	table.insert(tmp_rules, {"/island/uri"})
	table.insert(tmp_rules, {"/island/id"})

	table.insert(tmp_rules, {"/uri"})
	table.insert(tmp_rules, {"/id"})
--	table.insert(tmp_rules, {"/uuid"})
	table.insert(tmp_rules, {"/pubkey"})
--	table.insert(tmp_rules, {"/cert"})
	table.insert(tmp_rules, {"/api"})
	table.insert(tmp_rules, {"/api/type"})
	table.insert(tmp_rules, {"/api/base_uri"})
	table.insert(tmp_rules, {"/api/cert"})

	table.insert(tmp_rules, {"/arch"})

	table.insert(tmp_rules, {"/addrs"})
	table.insert(tmp_rules, {"/addrs/mgmt"})
	table.insert(tmp_rules, {"/addrs/mgmt_host"})
	table.insert(tmp_rules, {"/addrs/debug"})
	table.insert(tmp_rules, {"/addrs/local_mac"})
	table.insert(tmp_rules, {"/addrs/local_ipv4"})
	table.insert(tmp_rules, {"/addrs/local_ipv6"})
	table.insert(tmp_rules, {"/addrs/internal_ipv4"})
	table.insert(tmp_rules, {"/addrs/internal_ipv6"})
	table.insert(tmp_rules, {"/addrs/recovery_ipv4"})
	table.insert(tmp_rules, {"/addrs/recovery_ipv6"})
	table.insert(tmp_rules, {"/addrs/recovery_unique"})

	table.insert(tmp_rules, {"/mgmt_net"})
	table.insert(tmp_rules, {"/mgmt_net/addr"})
	table.insert(tmp_rules, {"/mgmt_net/backend"})

	table.insert(tmp_rules, {"/tinc"})
	table.insert(tmp_rules, {"/tinc/name"})
	table.insert(tmp_rules, {"/tinc/pubkey"})
	table.insert(tmp_rules, {"/tinc/addresses"})
	table.insert(tmp_rules, {"/tinc/addresses/*"})
	table.insert(tmp_rules, {"/tinc/addresses/*/*"})

	table.insert(tmp_rules, {"/direct_ifaces/*", "number"})
	table.insert(tmp_rules, {"/direct_ifaces"})
	
	table.insert(tmp_rules, {"/group"})
	table.insert(tmp_rules, {"/group/uri"})
	table.insert(tmp_rules, {"/group/id"})
	
	table.insert(tmp_rules, {"/boot_sn"})
	table.insert(tmp_rules, {"/set_state"})
	table.insert(tmp_rules, {"/state"})
	table.insert(tmp_rules, {"/soft_version"})
	
	table.insert(tmp_rules, {"/slivers"})
	table.insert(tmp_rules, {"/slivers/*", "iterate"})
	table.insert(tmp_rules, {"/slivers/*/uri"})
	table.insert(tmp_rules, {"/slivers/*/id"})

	table.insert(tmp_rules, {"/resources"})
	table.insert(tmp_rules, {"/resources/disk", "iterate"})
	table.insert(tmp_rules, {"/resources/pub_ipv4", "iterate"})
	table.insert(tmp_rules, {"/resources/pub_ipv6", "iterate"})
	table.insert(tmp_rules, {"/resources/*/name"})
	table.insert(tmp_rules, {"/resources/*/unit"})
	table.insert(tmp_rules, {"/resources/*/dflt_req"})
	table.insert(tmp_rules, {"/resources/*/max_req"})
	table.insert(tmp_rules, {"/resources/*/avail"})

	table.insert(tmp_rules, {"/message"})
	table.insert(tmp_rules, {"/errors"})
	table.insert(tmp_rules, {"/errors/*", "iterate"})
	table.insert(tmp_rules, {"/errors/*/member"})
	table.insert(tmp_rules, {"/errors/*/message"})
