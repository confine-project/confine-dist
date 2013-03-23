--[[



]]--

--- CONFINE sliver library.
module( "confine.sliver", package.seeall )

local nixio  = require "nixio"
local luci   = require "luci"

local tools  = require "confine.tools"
local cdata  = require "confine.data"
local ctree  = require "confine.tree"
local crules = require "confine.rules"
local cnode  = require "confine.node"
local csystem= require "confine.system"
local ssl    = require "confine.ssl"
local dbg    = tools.dbg
local err    = tools.err

NODE = {
	["registered"] 	 = "registered",
	["fail_alloc"]   = "fail_alloc",
	["allocated"]	 = "allocated",
	["fail_deploy"]  = "fail_deploy",
	["deployed"]	 = "deployed",
	["fail_start"]   = "fail_start",
	["started"]      = "started"
}

SERVER = {
	["register"] 	 = "register",
	["deploy"]	 = "deploy",
	["start"]        = "start"
}

local EXP_DATA_DIR_RD      = "/confine/exp_data/"
local TEMPLATE_DIR_RD      = "/confine/templates/"

local SLV_ALLOCATE_BIN = "/usr/sbin/confine_sliver_allocate"
local SLV_DEPLOY_BIN   = "/usr/sbin/confine_sliver_deploy"
local SLV_START_BIN    = "/usr/sbin/confine_sliver_start"
local SLV_STOP_BIN     = "/usr/sbin/confine_sliver_stop"
local SLV_UNDEPLOY_BIN = "/usr/sbin/confine_sliver_undeploy"
local SLV_REMOVE_BIN   = "/usr/sbin/confine_sliver_remove"

local UCI_SLIVER_MATCH = "^[%x][%x][%x][%x][%x][%x][%x][%x][%x][%x][%x][%x]$"


local register_rules = {}
local alloc_rules = {}
local dealloc_rules = {}
local deploy_rules = {}
local undeploy_rules = {}
local start_rules = {}
local stop_rules = {}








local function add_lslv_err( tree, path, msg, val )
	assert(tree and path and msg)

	local oslv = ctree.get_path_val(tree, path:match("^/local_slivers/[^/]+/"))

	oslv.errors = oslv.errors or {}

	local slv_key = ctree.get_path_leaf(path:match("^/local_slivers/[^/]+/"))
	local sub_path = path:gsub("^/local_slivers/"..slv_key.."/","/slivers/"..slv_key.."/")
	
	table.insert(oslv.errors, { member=sub_path, message=tostring(msg).." value="..tostring(val) })
	return "Error path=%s msg=%s val=%s" ,path, tostring(msg), tostring(val)
end


function cb2_set_state( rules, sys_conf, otree, ntree, path, begin, changed )
	if not rules then return "cb2_set_state" end

	local oval = ctree.get_path_val(otree,path)
	local nval = ctree.get_path_val(ntree,path)
	local oslv = ctree.get_path_val(otree,path:match("^/local_slivers/[^/]+/"))
	local nslv = ctree.get_path_val(ntree,path:match("^/local_slivers/[^/]+/"))
	local key  = ctree.get_path_leaf(path)
	local is_table = type(oval)=="table" or type(nval)=="table"
	
	
	if not nval or SERVER[nval] then
		if nval and nval ~= oval then
			ctree.set_path_val(otree, path, nval)
		end
		
		
		
		
		--if not (oslv.state==NODE.registered or oslv.state==NODE.allocating) then
		--	dbg( add_lslv_err(otree, path, "yet unsupported transition from state="..oslv.state, nval))
		--end
		
		
		
	else
		dbg( add_lslv_err(otree, path, "Illegal", nval))
	end
end


function cb2_set_sliver_uri( rules, sys_conf, otree, ntree, path, begin, changed )
	if not rules then return "cb2_set_sliver_uri" end

	local slv_key = ctree.get_path_leaf(path:match("^/local_slivers/[^/]+/"))
	
	ctree.set_path_val(otree, path, sys_conf.node_base_uri.."/slivers/"..slv_key)
end

function cb2_set_node_uri( rules, sys_conf, otree, ntree, path, begin, changed )
	if not rules then return "cb2_set_node_uri" end

	ctree.set_path_val(otree, path, sys_conf.node_base_uri.."/node")
end


function cb2_set_instance_sn( rules, sys_conf, otree, ntree, path, begin, changed )
	if not rules then return "cb2_set_instance_sn" end

	local nval = ctree.get_path_val(ntree,path)
	local oval = ctree.get_path_val(otree,path)
	
	if nval and type(nval)=="number" then
		if nval~=oval then
			ctree.set_path_val(otree, path, nval)
		end
	else
		dbg( add_lslv_err(otree, path, "Illegal "..type(nval), nval))
	end
end


function cb2_set_template_uri( rules, sys_conf, otree, ntree, path, begin, changed )
	if not rules then return "cb2_set_template_uri" end

	if begin then
		dbg( "begin")
		return
	end
	
	dbg ("end start")
	
	local oslv = ctree.get_path_val(otree,path:match("^/local_slivers/[^/]+/"))

	if oslv.state==NODE.registered and rules==register_rules then
		if oslv.local_template and oslv.local_template.uri then
			ctree.set_path_val( otree, path, { uri = oslv.local_template.uri } )
		else
			dbg( add_lslv_err( otree, path, "Invalid server template", nil))
			ctree.set_path_val( otree, path, cdata.null )
		end
	end
	
	dbg ("end end")

end


SLIVER_TYPES = {
	["debian6"] = "debian6",
	["openwrt-backfire"] = "openwrt-backfire",
	["openwrt-attitude-adjustment"] = "openwrt-attitude-adjustment"
}

function cb2_get_template( rules, sys_conf, otree, ntree, path, begin, changed )
	if not rules then return "cb2_get_template" end
	if not begin then return end
	
	local oslv = ctree.get_path_val(otree,path:match("^/local_slivers/[^/]+/"))
	local nslv = ctree.get_path_val(ntree,path:match("^/local_slivers/[^/]+/"))
	local nval = ctree.get_path_val(ntree,path)
	local oval = ctree.get_path_val(otree,path)
	
	if rules==register_rules and nval then
		
		if not oval then ctree.set_path_val(otree,path,{}) end
		
		local failure = false
		failure = not crules.set_or_err( add_lslv_err, otree, ntree, path.."name/",        "string" ) or failure
		failure = not crules.set_or_err( add_lslv_err, otree, ntree, path.."description/", "string" )
		failure = not crules.set_or_err( add_lslv_err, otree, ntree, path.."type/",        "string", SLIVER_TYPES ) or failure
		failure = not crules.set_or_err( add_lslv_err, otree, ntree, path.."is_active/",   "boolean", {true} ) or failure
		failure = not crules.set_or_err( add_lslv_err, otree, ntree, path.."image_uri/",   "string", {"^https?://.*%.tgz$", "^https?://.*%.tar%.gz$"} ) or failure
		failure = not crules.set_or_err( add_lslv_err, otree, ntree, path.."image_sha256/","string", {"^[%x]+$"} ) or failure

--		failure = not crules.set_or_err( add_lslv_err, otree, ntree, path.."uri/",         "string", {"^https?://.*/[%d]+$"} ) or failure
		if type(nval.uri)=="string" and nval.uri:match("^https?://.*/[%d]+$") then
			local id = tonumber(((nval.uri:match("/[%d]+$")):gsub("/","")))
			ctree.set_path_val( otree, path.."uri/", sys_conf.node_base_uri.."/templates/"..id  )
			ctree.set_path_val( otree, path.."id/", id )
		else
			dbg( add_lslv_err( otree, path.."uri/", "Invalid", nval.uri) )
			failure = true
		end
		
--		failure = not crules.set_or_err( add_lslv_err, otree, ntree, path.."node_archs/",  "table" ) or failure
		if type(nval.node_archs)=="table" and tools.get_table_by_key_val(nval.node_archs, sys_conf.arch) then
			ctree.set_path_val(otree, path.."node_archs/", nval.node_archs)
		else
			dbg( add_lslv_err( otree, path.."node_archs/", "Missing arch=%s"%sys_conf.arch, nil) )
			failure = true
		end
		
		if failure then
			ctree.set_path_val( otree, path, nil )
		end
		
	elseif rules==alloc_rules then
		
		if not oval then
			dbg( add_lslv_err(otree, path, "missing uri or sha", nil) )
			return
		end

		tools.mkdirr( TEMPLATE_DIR_RD )
		
		local uri = oval.image_uri
--TESTME:	local uri = "http://images.confine-project.eu/misc/CONFINE-sliver-openwrt-x86-generic-rootfs-070812_1023.tar.gz"
		local sha = oval.image_sha256
		local dst = TEMPLATE_DIR_RD..sha
		
		if nixio.fs.stat(dst) then
			if ssl.dgst_sha256(dst) ~= sha then
				dbg( "file=%s does not match given sha256 digest!", dst)
				nixio.fs.remover( dst )
			else
				nixio.fs.symlink( dst, dst..".tgz" )
			end
		end
		
		if not nixio.fs.stat(dst) then
			--TODO: check for TEMPLATE_DIR_RD size limit and remove unused files and links
			if cdata.http_get_raw(uri, dst) then
				if ssl.dgst_sha256(dst) ~= sha then
					nixio.fs.remover( dst )
					dbg( add_lslv_err(otree, path, "Incorrect sha256=%s for uri=%s" %{sha,uri}, nil) )
				else
					nixio.fs.symlink( dst, dst..".tgz" )
				end
			else
				nixio.fs.remover( dst )
				dbg( add_lslv_err(otree, path, "Inaccessible uri=%s" %{uri}, nil) )
			end
		end
	end	
end

function cb2_get_exp_data( rules, sys_conf, otree, ntree, path, begin, changed )
	if not rules then return "cb2_get_exp_data" end
	

	local oslv = ctree.get_path_val(otree,path:match("^/local_slivers/[^/]+/"))
	local nslv = ctree.get_path_val(ntree,path:match("^/local_slivers/[^/]+/"))
	local nval = ctree.get_path_val(ntree,path)
	local oval = ctree.get_path_val(otree,path)
	local key  = ctree.get_path_leaf(path)
	
	if rules==register_rules then
		
		if key=="exp_data_uri" then
			crules.set_or_err( add_lslv_err, otree, ntree, path, "string", {"^https?://.*%.tgz$", "^https?://.*%.tar%.gz$"} )
		end
		
		if key=="exp_data_sha256" then
			crules.set_or_err( add_lslv_err, otree, ntree, path, "string", {"^[%x]+$"})
		end
		
	elseif rules==alloc_rules then
		
		local uri = oslv and oslv.exp_data_uri
		local sha = oslv and oslv.exp_data_sha256
		local dst = EXP_DATA_DIR_RD..sha
		
		if not uri or not sha then
			dbg( add_lslv_err(otree, path, "missing uri or sha", oval) )
			return
		end
				
		tools.mkdirr( EXP_DATA_DIR_RD )
		
		if nixio.fs.stat(dst) then
			if ssl.dgst_sha256(dst) ~= sha then
				dbg( "file=%s does not match given sha256 digest!", dst)
				nixio.fs.remover( dst )
			end
		end
		
		if not nixio.fs.stat(dst) then
			--TODO: check for EXP_DATA_DIR_RD size limit and remove unused files
			if cdata.http_get_raw(uri, dst) then
				if ssl.dgst_sha256(dst) ~= sha then
					nixio.fs.remover( dst )
					dbg( add_lslv_err(otree, path, "Incorrect sha256=%s for uri=%s" %{sha,uri}, nval) )
				end
			else
				dbg( add_lslv_err(otree, path, "Inaccessible uri=%s" %{uri}, nval) )
			end
		end
	end
end

local tmp_rules


tmp_rules = register_rules
	table.insert(tmp_rules, {"/local_slivers/*/set_state",				cb2_set_state})
	table.insert(tmp_rules, {"/local_slivers/*/uri",				cb2_set_sliver_uri})
	table.insert(tmp_rules, {"/local_slivers/*/instance_sn",			cb2_set_instance_sn})
	table.insert(tmp_rules, {"/local_slivers/*/node",				crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/node/uri",				cb2_set_node_uri})
	table.insert(tmp_rules, {"/local_slivers/*/description",			crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/properties",				crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/properties/*",			crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/properties/*/*",			crules.cb2_set})
	
	table.insert(tmp_rules, {"/local_slivers/*/interfaces",				crules.cb2_nop})
	table.insert(tmp_rules, {"/local_slivers/*/local_template",			cb2_get_template})
	table.insert(tmp_rules, {"/local_slivers/*/local_template/uri",			crules.cb2_log}) --handled by cb2_get_template
	table.insert(tmp_rules, {"/local_slivers/*/local_template/name",		crules.cb2_log}) --handled by cb2_get_template
	table.insert(tmp_rules, {"/local_slivers/*/local_template/description",		crules.cb2_log}) --handled by cb2_get_template
	table.insert(tmp_rules, {"/local_slivers/*/local_template/type",		crules.cb2_log}) --handled by cb2_get_template
	table.insert(tmp_rules, {"/local_slivers/*/local_template/node_archs",		crules.cb2_log}) --handled by cb2_get_template
	table.insert(tmp_rules, {"/local_slivers/*/local_template/node_archs/*",	crules.cb2_log}) --handled by cb2_get_template
	table.insert(tmp_rules, {"/local_slivers/*/local_template/is_active",		crules.cb2_log}) --handled by cb2_get_template
	table.insert(tmp_rules, {"/local_slivers/*/local_template/image_uri",		crules.cb2_log}) --handled by cb2_get_template
	table.insert(tmp_rules, {"/local_slivers/*/local_template/image_sha256",	crules.cb2_log}) --handled by cb2_get_template
	table.insert(tmp_rules, {"/local_slivers/*/template",				cb2_set_template_uri})
	table.insert(tmp_rules, {"/local_slivers/*/template/uri",			crules.cb2_nop}) --handled by cb2_set_template_uri
--FIXME	table.insert(tmp_rules, {"/local_slivers/*/exp_data_uri",			cb2_get_exp_data})
--FIXME	table.insert(tmp_rules, {"/local_slivers/*/exp_data_sha256",			cb2_get_exp_data})
	table.insert(tmp_rules, {"/local_slivers/*/slice",				crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/slice/uri",				crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/local_slice",			crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/local_slice/instance_sn",		cb2_set_instance_sn})
	table.insert(tmp_rules, {"/local_slivers/*/local_slice/name",			crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/local_slice/description",		crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/local_slice/vlan_nr",		crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/local_slice/local_group",						crules.cb2_set})
--	table.insert(tmp_rules, {"/local_slivers/*/local_slice/local_group/uri",					rules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/local_slice/local_group/user_roles",					crules.cb2_set})
--	table.insert(tmp_rules, {"/local_slivers/*/local_slice/local_group/user_roles/*",	 			ssh.cb2_set_lgroup_role})
--	table.insert(tmp_rules, {"/local_slivers/*/local_slice/local_group/user_roles/*/is_researcher",			crules.cb2_nop}) --handled by set_local_group_role
--	table.insert(tmp_rules, {"/local_slivers/*/local_slice/local_group/user_roles/*/local_user", 	   		crules.cb2_nop}) --handled by set_local_group_role
--	table.insert(tmp_rules, {"/local_slivers/*/local_slice/local_group/user_roles/*/local_user/is_active",		crules.cb2_nop}) --handled by set_local_group_role
--	table.insert(tmp_rules, {"/local_slivers/*/local_slice/local_group/user_roles/*/local_user/auth_tokens",	crules.cb2_nop}) --handled by set_local_group_role
--	table.insert(tmp_rules, {"/local_slivers/*/local_slice/local_group/user_roles/*/local_user/auth_tokens/*",	crules.cb2_nop}) --handled by set_local_group_role
----



tmp_rules = alloc_rules
	table.insert(tmp_rules, {"/local_slivers/*/set_state",				cb2_set_state})
	table.insert(tmp_rules, {"/local_slivers/*/local_template",			cb2_get_template})
--FIXME	table.insert(tmp_rules, {"/local_slivers/*/exp_data_uri",			cb2_get_exp_data})

tmp_rules = dealloc_rules
	table.insert(tmp_rules, {"/local_slivers/*/set_state",				cb2_set_state})

tmp_rules = deploy_rules
	table.insert(tmp_rules, {"/local_slivers/*/set_state",				cb2_set_state})

tmp_rules = undeploy_rules
	table.insert(tmp_rules, {"/local_slivers/*/set_state",				cb2_set_state})

tmp_rules = start_rules
	table.insert(tmp_rules, {"/local_slivers/*/set_state",				cb2_set_state})

tmp_rules = stop_rules
	table.insert(tmp_rules, {"/local_slivers/*/set_state",				cb2_set_state})



local function sys_get_lsliver( sys_conf, otree, sk )

	local sv = sys_conf.uci_slivers[sk]
	
	ctree.dump(sys_conf.uci_slivers)
	
	assert(type(otree.local_slivers)=="table")
	
	if type(sk)=="string" and sk:match(UCI_SLIVER_MATCH) and type(sv)=="table" and sv[".type"]=="sliver" and sv.api=="confine" then
		
		if
			sv.exp_name and
			sv.state and
			sv.fs_template_url and
			sv.if00_type and
			sv.if00_name and
			sv.api_instance_sn and
			sv.api_slice_instance_sn and
			sv.api_tmpl_id and
			sv.api_tmpl_image_sha256 and
			sv.api_tmpl_image_uri and
			sv.api_tmpl_name and
			sv.api_tmpl_node_archs and
			sv.api_tmpl_type and
--				sv.api_set_state and
			sv.api_slice_uri and
			true then
			
			local id = tostring(tonumber(sk, 16))
			local slv = otree.local_slivers[id] or {}
			
			slv.instance_sn = tonumber(sv.api_instance_sn)
			slv.local_slice = slv.local_slice or {}
			slv.local_slice.name = sv.exp_name
			slv.local_slice.instance_sn = tonumber(sv.api_slice_instance_sn)
			slv.local_slice.local_group  = slv.local_slice.local_group or {}
			slv.local_template = slv.local_template or {}
			slv.local_template.id = sv.api_tmpl_id
			slv.local_template.image_sha256 = sv.api_tmpl_image_sha256
			slv.local_template.image_uri = sv.api_tmpl_image_uri
			slv.local_template.is_active = true
			slv.local_template.name = sv.api_tmpl_name
			slv.local_template.node_archs = tools.str2table(sv.api_tmpl_node_archs,"[^ ]+")
			slv.local_template.type = sv.api_tmpl_type
			slv.local_template.uri = sys_conf.node_base_uri.."/templates/"..sv.api_tmpl_id
			slv.node = { uri = sys_conf.node_base_uri.."/node" }
--				slv.set_state = sv.api_set_state
			slv.slice = { uri = sv.api_slice_uri }
			slv.state = sv.state
			slv.template = { uri = slv.local_template.uri}
			slv.uri = sys_conf.node_base_uri.."/slivers/"..id
			
			otree.local_slivers[id] = slv
		else
			dbg("WARNING: corrupted uci_sliver=%s",sk)
			assert((os.execute( SLV_REMOVE_BIN .. " " .. sk ) == 0), "Failed removing corrupted uci_sliver=%s %s",sk, ctree.as_string(sv) )
			sys_conf.uci_slivers[sk] = nil
		end
	else
		dbg("WARNING: confine RestAPI incompatible uci_sliver=%s",sk)
	end	
end


function sys_get_lslivers( sys_conf, otree )
	
	dbg("-------------------")
	ctree.dump( sys_conf.uci_slivers )
	dbg("-------------------")
	
	otree.local_slivers = otree.local_slivers or {}

	local sk
	for sk in pairs(sys_conf.uci_slivers) do
		sys_get_lsliver( sys_conf, otree, sk)
	end
	
	assert(type(otree.local_slivers)=="table")
	
	return otree.local_slivers
end



function remove_slivers( sys_conf, otree, slv_key, next_state)
--	assert(false)
	
	if slv_key then
		
		local uci_key = "%.12x" %tonumber(slv_key)
		assert((os.execute( SLV_REMOVE_BIN.." "..uci_key )==0), "Failed removing uci_sliver=%s", uci_key )
		sys_conf.uci_slivers[uci_key] = nil
		
		if next_state then
			dbg("only uci_sliver=%s" %tostring(slv_key))
			otree.local_slivers[slv_key].state = next_state
		else
			dbg("sliver=%s" %tostring(slv_key))
			otree.local_slivers[slv_key] = nil
		end
		
		csystem.get_system_conf( sys_conf )
		sys_get_lslivers( sys_conf, otree, uci_key )
		
	else
		
		dbg("removing all")
		assert((os.execute( SLV_REMOVE_BIN.." all" )==0), "Failed removing all slivers" )
		sys_conf.uci_slivers = {}
		otree.local_slivers = {}
		
		csystem.get_system_conf( sys_conf )
		sys_get_lslivers( sys_conf, otree )
	end
end



local function sys_set_lsliver_state( sys_conf, otree, slv_key, next_state )
	
	assert( type(otree)=="table" )
	assert( type(tonumber(slv_key))=="number" )
	assert( type(NODE[next_state])=="string" or not next_state )
	
	local uci_key = "%.12x" %tonumber(slv_key)
	assert( uci_key:match(UCI_SLIVER_MATCH), "Invalid slv_key=%s uci_key=%s" %{slv_key, uci_key})

	local uci_slv = (sys_conf.uci_slivers[uci_key] or {}).api=="confine" and sys_conf.uci_slivers[uci_key]
	local api_slv = otree.local_slivers[slv_key]
	
	local uci_state = (uci_slv or {}).state
	
	dbg( "sliver=%s next_state=%s api_state=%s uci_state=%s api_slv=%s",
	    slv_key, tostring(next_state), tostring(api_slv.state), tostring(uci_state), tostring(api_slv))


	if next_state==nil then
		
		remove_slivers( sys_conf, otree, slv_key, nil )
		dbg( "next_state=%s uci_state=%s lslivers=%s", tostring(next_state), tostring(uci_state), ctree.as_string(otree.local_slivers) )
		return true
		
	elseif next_state==NODE.registered then
		
		remove_slivers( sys_conf, otree, slv_key, next_state )
		dbg( "next_state=%s uci_state=%s lslivers=%s", tostring(next_state), tostring(uci_state), ctree.as_string(otree.local_slivers) )
		return true
	
	elseif next_state==NODE.allocated and uci_state==NODE.allocated then
		api_slv.state = next_state
		return true
	
	elseif next_state==NODE.allocated and uci_state==nil then
		
		local sliver_desc = "config sliver '%s'\n" %uci_key
		sliver_desc = sliver_desc.."	option fs_template_url 'file://%s%s'\n" %{TEMPLATE_DIR_RD,api_slv.local_template.image_sha256..".tgz"}
		sliver_desc = sliver_desc.."	option exp_name '%s'\n" %api_slv.local_slice.name:gsub("\n","")
		sliver_desc = sliver_desc.."	option if00_type '%s'\n" %"internal"
		sliver_desc = sliver_desc.."	option if00_name '%s'\n" %"priv"
		
		local cmd = SLV_ALLOCATE_BIN.." "..uci_key.." <<EOF\n "..(sliver_desc:gsub("EOF","")).."EOF\n"
		dbg(cmd)
		if os.execute( cmd )==0 then
		
			local sliver_opts = {
				api = "confine",
				api_instance_sn = api_slv.instance_sn,
				api_slice_instance_sn = api_slv.local_slice.instance_sn,
				api_slice_uri = api_slv.slice.uri,
				api_tmpl_id = api_slv.local_template.id,
				api_tmpl_image_sha256 = api_slv.local_template.image_sha256,
				api_tmpl_image_uri = api_slv.local_template.image_uri,
				api_tmpl_name = api_slv.local_template.name,
				api_tmpl_node_archs = tools.table2string(api_slv.local_template.node_archs, " "),
				api_tmpl_type = api_slv.local_template.type
			}
			csystem.set_system_conf( sys_conf, "uci_sliver", sliver_opts, uci_key)
			sys_get_lsliver( sys_conf, otree, uci_key )
			dbg( "next_state=%s uci_state=%s lslivers=%s", tostring(next_state), tostring(uci_state), ctree.as_string(otree.local_slivers) )
			return true
		end			
		
	elseif next_state==NODE.allocated and uci_state==NODE.deployed then
		
		if os.execute( SLV_UNDEPLOY_BIN.." "..uci_key )==0 then
			dbg("uci_slivers=%s", ctree.as_string( csystem.get_system_conf( sys_conf ).uci_slivers ) )
			sys_get_lsliver( sys_conf, otree, uci_key )
			dbg( "next_state=%s uci_state=%s lslivers=%s", tostring(next_state), tostring(uci_state), ctree.as_string(otree.local_slivers) )
			return true
		end
		
	elseif next_state==NODE.fail_alloc and uci_state==nil then
		api_slv.state = next_state
		return true
	
	
	elseif next_state==NODE.deployed and uci_state==NODE.deployed then
		api_slv.state = next_state
		return true
		
	elseif next_state==NODE.deployed and uci_state==NODE.allocated then
		
		local sliver_desc = "config sliver '%s_%.4x'\n" %{uci_key,sys_conf.id}
		local cmd = SLV_DEPLOY_BIN.." "..uci_key.." <<EOF\n "..(sliver_desc:gsub("EOF","")).."EOF\n"
		dbg(cmd)
		if os.execute( cmd )==0 then
			csystem.get_system_conf( sys_conf )
			sys_get_lsliver( sys_conf, otree, uci_key )
			dbg( "next_state=%s uci_state=%s lslivers=%s", tostring(next_state), tostring(uci_state), ctree.as_string(otree.local_slivers) )
			return true
		end
		
	elseif next_state==NODE.deployed and uci_state==NODE.started then
		
		if os.execute( SLV_STOP_BIN.." "..uci_key )==0 then
			csystem.get_system_conf( sys_conf )
			sys_get_lsliver( sys_conf, otree, uci_key )
			return true
		end
		
	elseif next_state==NODE.fail_deploy and uci_state==NODE.allocated then
		api_slv.state = next_state
		return true


	elseif next_state==NODE.started and uci_state==NODE.started then
		api_slv.state = next_state
		return true
		
	elseif next_state==NODE.started and uci_state==NODE.deployed then
		
		if os.execute( SLV_START_BIN.." "..uci_key )==0 then
			csystem.get_system_conf( sys_conf )
			sys_get_lsliver( sys_conf, otree, uci_key )
			return true
		end
		
	elseif next_state==NODE.fail_start and uci_state==NODE.deployed then
		api_slv.state = next_state
		return true
	end

	err( "next_state=%s api_state=%s uci_state=%s slivers=%s",
	    tostring(next_state), tostring(api_slv.state), tostring(uci_state), ctree.as_string(otree.local_slivers))
		
	return false
end



local function slv_iterate( iargs, rules, start_state, success_state, error_state )

	assert( type(rules)=="table" or not rules )
	assert( type(NODE[  start_state])=="string" or not start_state   )
	assert( type(NODE[success_state])=="string" or not success_state )
	assert( type(NODE[  error_state])=="string" or not error_state   )
	
	local a = iargs

	assert (type(a.cb)=="function")
	assert (type(a.sys_conf=="table"))
	assert (type(a.otree)=="table")
	assert (type(a.ntree)=="table")
	assert (type(a.path)=="string")

	local oslvs = a.otree.local_slivers
	local nslvs = a.ntree.local_slivers
	local key = ctree.get_path_leaf(a.path)
	local oslv = oslvs[key]
	local nslv = nslvs[key]
	
	dbg( "sliver=%s start_state=%s success_state=%s error_state=%s", key, tostring(start_state), tostring(success_state), tostring(error_state) )
	
	if start_state then
		if not sys_set_lsliver_state( a.sys_conf, a.otree, key, start_state ) then
			remove_slivers( a.sys_conf, a.otree, key)
			return false
		end
	end
	
	assert( oslv==oslvs[key])
	assert( nslv==nslvs[key])

	if rules then
		ctree.iterate( a.cb, rules, a.sys_conf, a.otree, a.ntree, a.path )
	end
	
	assert( oslv==oslvs[key])
	assert( nslv==nslvs[key])

	if not success_state then
		assert( sys_set_lsliver_state( a.sys_conf, a.otree, key, nil ) )
		return true

	elseif oslv.errors then
		assert( error_state )
		if not sys_set_lsliver_state( a.sys_conf, a.otree, key, error_state ) then
			remove_slivers( a.sys_conf, a.otree, key)
			return false
		end

	else
		if not sys_set_lsliver_state( a.sys_conf, a.otree, key, success_state ) then
			dbg( add_lslv_err(a.otree, a.path, "Failed state transition"))
			assert( error_state )
			if not sys_set_lsliver_state( a.sys_conf, a.otree, key, error_state ) then
				remove_slivers( a.sys_conf, a.otree, key)
				return false
			end
		end
	end
	
	assert( oslv==oslvs[key])
	assert( nslv==nslvs[key])
	
	return true
end


function cb2_set_lsliver( rules, sys_conf, otree, ntree, path, begin, changed )
	if not rules then return "cb2_set_lsliver" end
	if begin then return dbg("------------------------") or true end

	local key = ctree.get_path_leaf(path)
	
	local iargs = { cb=crules.cb2, sys_conf=sys_conf, otree=otree, ntree=ntree, path=path }
	
	if otree.state ~= cnode.STATE.production then
		ntree.local_slivers[key] = nil
	end
	
	ctree.dump(otree.local_slivers[key] or {})

	if ntree.local_slivers[key] or otree.local_slivers[key] then
	
		local i,imax = 1,10
		local prev_state = nil
		local nslv = ntree.local_slivers[key]
		local oslv = otree.local_slivers[key] or ctree.set_path_val(otree, "/local_slivers/"..key, {state=NODE.registered })
		oslv.errors = nil
			
		while (oslv.state~=prev_state) do
			
			dbg("processing i=%s sliver=%s node_state=%s server_sliver_state=%s node_sliver_state=%s err=%s",
				i, key, otree.state, tostring((nslv or {}).set_state), tostring(oslv.state), ctree.as_string(oslv.errors) )
			
			prev_state = oslv.state
			
			assert( (ntree.local_slivers[key] or otree.local_slivers[key]) and nslv==ntree.local_slivers[key] and oslv==otree.local_slivers[key] )
			assert( i <= imax )
	
			if (oslv.state==NODE.registered or (oslv.state==NODE.fail_alloc and i==1)) then
				
				if nslv then
					if not slv_iterate( iargs, register_rules, NODE.registered, NODE.registered, NODE.registered) then break end
				end
				
				if not oslv.errors and nslv and (nslv.set_state==SERVER.deploy or nslv.set_state==SERVER.start) then
					
					if not slv_iterate( iargs, alloc_rules, NODE.registered, NODE.allocated, NODE.fail_alloc) then break end
					
					if oslv.errors then
						if not slv_iterate( iargs, dealloc_rules, NODE.fail_alloc, NODE.fail_alloc, NODE.fail_alloc) then break end
					end
					
				elseif not nslv then
					
					if not slv_iterate( iargs, nil, nil, nil, nil ) then break end
					break
				else
					break
				end
	
	
	
			elseif (oslv.state==NODE.allocated or (oslv.state==NODE.fail_deploy and i==1)) and 
				(not nslv or
				 nslv.instance_sn > oslv.instance_sn or nslv.set_state==SERVER.register) then
				
				if not slv_iterate( iargs, dealloc_rules, NODE.allocated, NODE.registered, nil) then break end
				
	
			elseif (oslv.state==NODE.allocated or (oslv.state==NODE.fail_deploy and i==1)) and
				(nslv.set_state==SERVER.deploy or nslv.set_state==SERVER.start) then
				
				if not slv_iterate( iargs, deploy_rules, NODE.allocated, NODE.deployed, NODE.fail_deploy) then break end
				
				if oslv.errors then
					if not slv_iterate( iargs, undeploy_rules, NODE.fail_deploy, NODE.fail_deploy, NODE.fail_deploy) then break end
				end
	
	
	
			elseif (oslv.state==NODE.deployed or (oslv.state==NODE.fail_start and i==1)) and
				(not nslv or
				 nslv.instance_sn ~= oslv.instance_sn or nslv.local_slice.instance_sn ~= oslv.local_slice.instance_sn or
				 nslv.set_state==SERVER.register) then
				
				if not slv_iterate( iargs, undeploy_rules, NODE.deployed, NODE.allocated, nil) then break end
				
			elseif (oslv.state==NODE.deployed or (oslv.state==NODE.fail_start and i==1)) and
				(nslv.set_state==SERVER.start) then
				
				if not slv_iterate( iargs, start_rules, NODE.deployed, NODE.started, NODE.fail_start) then break end
				
				if oslv.errors then
					if not slv_iterate( iargs, stop_rules, NODE.fail_start, NODE.fail_start, NODE.fail_start) then break end
					break
				end
	

			elseif (oslv.state==NODE.started) and
				(not nslv or
				 nslv.instance_sn ~= oslv.instance_sn or nslv.local_slice.instance_sn ~= oslv.local_slice.instance_sn or
				 nslv.set_state==SERVER.register or nslv.set_state==SERVER.deploy) then
				
				if not slv_iterate( iargs, stop_rules, NODE.started, NODE.deployed, nil) then break end
				
			else
				break
			end
			
			
			i = i + 1
		end
		
		dbg("finished   i=%s sliver=%s node_state=%s server_sliver_state=%s node_sliver_state=%s err=%s",
			i, key, otree.state, tostring((ntree.local_slivers[key] or {}).set_state), tostring((otree.local_slivers[key] or {}).state), ctree.as_string((otree.local_slivers[key] or {}).errors) )

	end	

	return true	
end


function cb2_set_slivers( rules, sys_conf, otree, ntree, path, begin, changed )
	if not rules then return "cb2_set_slivers" end
	otree.slivers = otree.local_slivers
end


out_filter = {}
tmp_rules = out_filter
	table.insert(tmp_rules, {"/*"})
	table.insert(tmp_rules, {"/*/uri"})
	table.insert(tmp_rules, {"/*/slice"})
	table.insert(tmp_rules, {"/*/slice/uri"})	
	table.insert(tmp_rules, {"/*/node"})
	table.insert(tmp_rules, {"/*/node/uri"})
	table.insert(tmp_rules, {"/*/description"})
	table.insert(tmp_rules, {"/*/properties"})
	table.insert(tmp_rules, {"/*/properties/*"})
	table.insert(tmp_rules, {"/*/properties/*/*"})
	table.insert(tmp_rules, {"/*/instance_sn"})
	table.insert(tmp_rules, {"/*/template"})
	table.insert(tmp_rules, {"/*/template/uri"})
	table.insert(tmp_rules, {"/*/exp_data_uri"})
	table.insert(tmp_rules, {"/*/exp_data_sha256"})
	table.insert(tmp_rules, {"/*/interfaces"})
	table.insert(tmp_rules, {"/*/interfaces/*"})
	table.insert(tmp_rules, {"/*/interfaces/*/nr"})
	table.insert(tmp_rules, {"/*/interfaces/*/name"})
	table.insert(tmp_rules, {"/*/interfaces/*/type"})
	table.insert(tmp_rules, {"/*/interfaces/*/parent_name"})
	table.insert(tmp_rules, {"/*/interfaces/*/mac_addr"})
	table.insert(tmp_rules, {"/*/interfaces/*/ipv4_addr"})
	table.insert(tmp_rules, {"/*/interfaces/*/ipv6_addr"})
	table.insert(tmp_rules, {"/*/properties"})
	table.insert(tmp_rules, {"/*/properties/*"})
	table.insert(tmp_rules, {"/*/nr"})
	table.insert(tmp_rules, {"/*/state"})
	table.insert(tmp_rules, {"/*/errors"})
	table.insert(tmp_rules, {"/*/errors/*"})
	table.insert(tmp_rules, {"/*/errors/*/member"})
	table.insert(tmp_rules, {"/*/errors/*/message"})



function get_templates( otree )

	local templates = {}
	local k,v
	if otree.local_slivers then
		for k,lslv in pairs(otree.local_slivers) do
			local id = lslv.local_template and lslv.local_template.id
			if id then
				templates[id] = lslv.local_template
			end
		end
	end
	return templates
end

template_out_filter = {}
tmp_rules = template_out_filter
	table.insert(tmp_rules, {"/*"})
	table.insert(tmp_rules, {"/*/uri"})
	table.insert(tmp_rules, {"/*/name"})
	table.insert(tmp_rules, {"/*/description"})
	table.insert(tmp_rules, {"/*/type"})
	table.insert(tmp_rules, {"/*/node_archs"})
	table.insert(tmp_rules, {"/*/node_archs/*"})
	table.insert(tmp_rules, {"/*/is_active"})
	table.insert(tmp_rules, {"/*/image_uri"})
	table.insert(tmp_rules, {"/*/image_sha256"})
