--[[



]]--

--- CONFINE sliver library.
module( "confine.sliver", package.seeall )

local nixio  = require "nixio"

local util   = require "luci.util"
local tools  = require "confine.tools"
local ctree   = require "confine.tree"
local crules   = require "confine.rules"
local cnode   = require "confine.node"
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


local register_rules = {}
local alloc_rules = {}
local dealloc_rules = {}
local deploy_rules = {}
local undeploy_rules = {}
local start_rules = {}
local stop_rules = {}



function stop_slivers( sys_conf, sliver )
	dbg("stop_slivers() sliver=%s... (TBD)" %tostring(sliver))
end

function remove_slivers( sys_conf, sliver)
--	assert(false)
	dbg("remove_slivers() sliver=%s... (TBD)" %tostring(sliver))
	stop_slivers( sys_conf, sliver )
end

function start_slivers( sys_conf, sliver)
	dbg("start_slivers() sliver=%s... (TBD)" %tostring(sliver))
end



function add_lsliver_error( otree, path, msg, val )
	assert(otree, path, message)

	local oslv = ctree.get_path_val(otree,path:match("^/local_slivers/[^/]+/"))

	oslv.errors = oslv.errors or {}

	local slv_key = ctree.get_path_leaf(path:match("^/local_slivers/[^/]+/"))
	local sub_path = path:gsub("^/local_slivers/"..slv_key.."/","/")
	
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
		ctree.set_path_val(otree, path, nval)
		
		if not (oslv.state==NODE.registered or oslv.state==NODE.fail_alloc) then
			dbg( add_lsliver_error(otree, path, "yet unsupported transition from state="..oslv.state, nval))
		end
		
	else
		dbg( add_lsliver_error(otree, path, "Illegal", nval))
	end
	
	dbg( "oslv=%s nslv=%s", tostring(oslv), tostring(nslv))
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
		dbg( add_lsliver_error(otree, path, "Illegal "..type(nval), nval))
	end
end




function cb2_get_exp_data( rules, sys_conf, otree, ntree, path, begin, changed )
	if not rules then return "cb2_get_exp_data" end
	
	
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
	
	table.insert(tmp_rules, {"/local_slivers/*/exp_data_uri",			cb2_get_exp_data})
	table.insert(tmp_rules, {"/local_slivers/*/exp_data_sha256",			cb2_get_exp_data})
	table.insert(tmp_rules, {"/local_slivers/*/interfaces",				crules.cb2_nop})
	table.insert(tmp_rules, {"/local_slivers/*/local_template",			crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/local_template/arch",		crules.cb2_nop})
	table.insert(tmp_rules, {"/local_slivers/*/local_template/image_uri",		crules.cb2_nop})
	table.insert(tmp_rules, {"/local_slivers/*/local_template/type",		crules.cb2_nop})
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

tmp_rules = dealloc_rules

tmp_rules = deploy_rules
	table.insert(tmp_rules, {"/local_slivers/*/set_state",				cb2_set_state})

tmp_rules = undeploy_rules

tmp_rules = start_rules
	table.insert(tmp_rules, {"/local_slivers/*/set_state",				cb2_set_state})

tmp_rules = stop_rules


local slv_iterate_args

local function slv_iterate( rules, start_state, success_state, error_state )

	assert( type(rules)=="table")
	assert( type(NODE[  start_state])=="string")
	assert( type(NODE[success_state])=="string")
	assert( type(NODE[  error_state])=="string" or not error_state )
	
	local a = slv_iterate_args

	assert (type(a.cb)=="function")
	assert (type(a.sys_conf=="table"))
	assert (type(a.otree)=="table")
	assert (type(a.ntree)=="table")
	assert (type(a.path)=="string")

	local oslvs = a.otree.local_slivers
	local key = ctree.get_path_leaf(a.path)
	local oslv = oslvs[key]
	
	local ret = ctree.iterate( a.cb, rules, a.sys_conf, a.otree, a.ntree, a.path )
	
	assert( oslv==oslvs[key])
	assert( error_state or not oslv.errors )
	
	if oslv.errors then
		oslv.state = error_state
	else
		oslv.state = success_state
	end
	
	return ret
end


function cb2_set_lsliver( rules, sys_conf, otree, ntree, path, begin, changed )
	if not rules then return "cb2_set_lsliver" end
	if begin then return dbg("------------------------") or true end

	local nslvs = ntree.local_slivers
	local oslvs = otree.local_slivers
	local key = ctree.get_path_leaf(path)
	
	slv_iterate_args = { cb=crules.cb2, sys_conf=sys_conf, otree=otree, ntree=ntree, path=path }
	
	if otree.state ~= cnode.STATE.production then
		nslvs[key] = nil
	end
	
	if oslvs[key] then
		oslvs[key].errors = nil
	end
		
	local i,imax = 1,8
	local prev_state
	
	while (nslvs[key] or oslvs[key]) --[[and (i==1 or (oslvs[key] and oslvs[key].state ~= prev_state))--]] do

		local nslv = nslvs[key]
		local oslv = oslvs[key] or ctree.set_path_val(otree,path,{state=NODE.registered })
		
		--prev_state = oslv.state
		
		dbg("processing i=%s sliver=%s node_state=%s server_sliver_state=%s node_sliver_state=%s err=%s",
			i, key, otree.state, tostring((nslv or {}).set_state), tostring(oslv.state), ctree.as_string(oslv.errors) )
		
		assert( i <= imax )
		
		if (oslv.state==NODE.registered or (oslv.state==NODE.fail_alloc and i==1)) then
			
			slv_iterate( register_rules, NODE.registered, NODE.registered, NODE.registered)
			
			if not oslv.errors and (oslv.set_state==SERVER.deploy or oslv.set_state==SERVER.start) then
				
				oslv.state = NODE.allocating
						
			elseif not nslv then
				
				oslvs[key] = nil
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
			
			oslv.state = NODE.deploying



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
			
			oslv.state = NODE.starting



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
	

	return true	
end


function cb2_set_slivers( rules, sys_conf, otree, ntree, path, begin, changed )
	if not rules then return "cb2_set_slivers" end
	otree.slivers = otree.local_slivers
end










out_filter = {}
tmp_rules = out_filter
	table.insert(tmp_rules, {"/"})
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

