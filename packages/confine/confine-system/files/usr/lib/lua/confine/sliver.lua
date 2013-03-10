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
local ssl    = require "confine.ssl"
local dbg    = tools.dbg

NODE = {
	["registered"] 	 = "registered",
	["allocating"]   = "allocating",
	["fail_alloc"]   = "fail_alloc",
	["allocated"]	 = "allocated",
	["deploying"]    = "deploying",
	["fail_deploy"]  = "fail_deploy",
	["deployed"]	 = "deployed",
	["starting"]     = "starting",
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


local register_rules = {}
local alloc_rules = {}
local dealloc_rules = {}
local deploy_rules = {}
local undeploy_rules = {}
local start_rules = {}
local stop_rules = {}


function stop_slivers( sys_conf, sliver )
	dbg("sliver=%s... (TBD)" %tostring(sliver))
end

function remove_slivers( sys_conf, sliver)
--	assert(false)
	dbg("sliver=%s... (TBD)" %tostring(sliver))
	stop_slivers( sys_conf, sliver )
end

function start_slivers( sys_conf, sliver)
	dbg("sliver=%s... (TBD)" %tostring(sliver))
end




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

	if oslv.state==NODE.registered then
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
	
	if oslv.state==NODE.registered and nval then
		
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
		
	elseif oslv.state==NODE.allocating then
		
		if not oval then
			dbg( add_lslv_err(otree, path, "missing uri or sha", nil) )
			return
		end

		tools.mkdirr( TEMPLATE_DIR_RD )
		
--FIXME		local uri = oval.image_uri
		local uri = "http://images.confine-project.eu/misc/CONFINE-sliver-openwrt-x86-generic-rootfs-070812_1023.tar.gz"
		local sha = oval.image_sha256
		local dst = TEMPLATE_DIR_RD..sha
		
		if nixio.fs.stat(dst) then
			if ssl.dgst_sha256(dst) ~= sha then
				dbg( "file=%s does not match given sha256 digest!", dst)
				nixio.fs.remover( dst )
			end
		end
		
		if not nixio.fs.stat(dst) then
			--TODO: check for TEMPLATE_DIR_RD size limit and remove unused files
			if cdata.http_get_raw(uri, dst) then
				if ssl.dgst_sha256(dst) ~= sha then
					nixio.fs.remover( dst )
					dbg( add_lslv_err(otree, path, "Incorrect sha256=%s for uri=%s" %{sha,uri}, nil) )
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
	
	if oslv.state==NODE.registered then
		
		if key=="exp_data_uri" then
			crules.set_or_err( add_lslv_err, otree, ntree, path, "string", {"^https?://.*%.tgz$", "^https?://.*%.tar%.gz$"} )
		end
		
		if key=="exp_data_sha256" then
			crules.set_or_err( add_lslv_err, otree, ntree, path, "string", {"^[%x]+$"})
		end
		
	elseif oslv.state==NODE.allocating then
		
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



local function sys_set_lsliver_state( otree, key, state )
	
	assert( type(otree)=="table" )
	assert( type(tonumber(key))=="number" )
	assert( type(NODE[state])=="string" or not state )
	
	if state then
		otree.local_slivers[key].state = state
	else
		otree.local_slivers[key] = nil
	end
end


local slv_iterate_args

local function slv_iterate( rules, start_state, success_state, error_state )

	assert( type(rules)=="table" or not rules )
	assert( type(NODE[  start_state])=="string" or not start_state   )
	assert( type(NODE[success_state])=="string" or not success_state )
	assert( type(NODE[  error_state])=="string" or not error_state   )
	
	local a = slv_iterate_args

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
	
	if start_state then
		sys_set_lsliver_state( a.otree, key, start_state )
	end
	
	if rules then
		ctree.iterate( a.cb, rules, a.sys_conf, a.otree, a.ntree, a.path )
	end
	
	assert( oslv==oslvs[key])
	assert( nslv==nslvs[key])
	assert( not oslv.errors or not success_state or error_state)
	
	if not success_state then
		sys_set_lsliver_state( a.otree, key, nil )
	elseif oslv.errors then
		sys_set_lsliver_state( a.otree, key, error_state )
	else
		sys_set_lsliver_state( a.otree, key, success_state )
	end
	
end





function cb2_set_lsliver( rules, sys_conf, otree, ntree, path, begin, changed )
	if not rules then return "cb2_set_lsliver" end
	if begin then return dbg("------------------------") or true end

	local key = ctree.get_path_leaf(path)
	
	slv_iterate_args = { cb=crules.cb2, sys_conf=sys_conf, otree=otree, ntree=ntree, path=path }
	
	if otree.state ~= cnode.STATE.production then
		ntree.local_slivers[key] = nil
	end
	
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
					slv_iterate( register_rules, NODE.registered, NODE.registered, NODE.registered)
				end
				
				if not oslv.errors and nslv and (nslv.set_state==SERVER.deploy or nslv.set_state==SERVER.start) then
					
					slv_iterate( nil, nil, NODE.allocating, NODE.fail_alloc )
					
				elseif not nslv then
					
					slv_iterate( nil, nil, nil, nil )
					break
				else
					break
				end
	
	
	
			elseif (oslv.state==NODE.allocating) then
				
				assert( not oslv.errors )
	
				slv_iterate( alloc_rules, NODE.allocating, NODE.allocated, NODE.fail_alloc)
				
				if oslv.errors then
					slv_iterate( dealloc_rules, NODE.fail_alloc, NODE.fail_alloc, NODE.fail_alloc)
				end
	
			elseif (oslv.state==NODE.allocated or (oslv.state==NODE.fail_deploy and i==1)) and 
				(not nslv or
				 nslv.instance_sn > oslv.instance_sn or nslv.set_state==SERVER.register) then
				
				slv_iterate( dealloc_rules, NODE.allocated, NODE.registered, nil)
				
	
			elseif (oslv.state==NODE.allocated or (oslv.state==NODE.fail_deploy and i==1)) and
				(nslv.set_state==SERVER.deploy or nslv.set_state==SERVER.start) then
				
				slv_iterate( nil, nil, NODE.deploying, NODE.fail_deploy)
	
	
	
			elseif (oslv.state==NODE.deploying) then
				
				assert( not oslv.errors)
				
				slv_iterate( deploy_rules, NODE.deploying, NODE.deployed, NODE.fail_deploy)
				
				if oslv.errors then
					slv_iterate( undeploy_rules, NODE.fail_deploy, NODE.fail_deploy, NODE.fail_deploy)
				end
	
			elseif (oslv.state==NODE.deployed or (oslv.state==NODE.fail_start and i==1)) and
				(not nslv or
				 nslv.instance_sn ~= oslv.instance_sn or nslv.local_slice.instance_sn ~= oslv.local_slice.instance_sn or
				 nslv.set_state==SERVER.register) then
				
				slv_iterate( undeploy_rules, NODE.deployed, NODE.allocated, nil)
				
			elseif (oslv.state==NODE.deployed or (oslv.state==NODE.fail_start and i==1)) and
				(nslv.set_state==SERVER.start) then
				
				slv_iterate( nil, nil, NODE.starting, NODE.fail_start )
	
	
	
			elseif (oslv.state==NODE.starting) then
				
				assert( not oslv.errors)
				
				slv_iterate(start_rules, NODE.starting, NODE.started, NODE.fail_start)
				
				if oslv.errors then
					slv_iterate(stop_rules, NODE.fail_start, NODE.fail_start, NODE.fail_start)
					break
				end
				
			elseif (oslv.state==NODE.started) and
				(not nslv or
				 nslv.instance_sn ~= oslv.instance_sn or nslv.local_slice.instance_sn ~= oslv.local_slice.instance_sn or
				 nslv.set_state==SERVER.register or nslv.set_state==SERVER.deploy) then
				
				slv_iterate( stop_rules, NODE.started, NODE.deployed, nil)
				
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
