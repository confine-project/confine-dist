--[[



]]--

--- CONFINE sliver library.
module( "confine.sliver", package.seeall )


local util   = require "luci.util"
local tools  = require "confine.tools"
local ctree   = require "confine.tree"
local crules   = require "confine.rules"
local cnode   = require "confine.node"
local dbg    = tools.dbg

STATE = {
	["register"] 	  = "register",
	["do_alloc"]      = "do_alloc",
	["fail_alloc"]    = "fail_alloc",
	["allocate"]	  = "allocate",
	["do_deploy"]     = "do_deploy",
	["fail_deploy"]   = "fail_deploy",
	["instantiate"]	  = "instantiate",
	["do_start"]      = "do_start",
	["fail_start"]    = "fail_start",
	["activate"]      = "activate"
}


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




function cb2_set_state( sys_conf, otree, ntree, path, begin, changed )
	if not sys_conf then return "cb2_set_state" end

	local oval = ctree.get_path_val(otree,path)
	local nval = ctree.get_path_val(ntree,path)
	local oslv = ctree.get_path_val(otree,path:match("^/local_slivers/[^/]+/"))
	local nslv = ctree.get_path_val(ntree,path:match("^/local_slivers/[^/]+/"))
	local key  = ctree.get_path_leaf(path)
	local is_table = type(oval)=="table" or type(nval)=="table"
	
	if nval and STATE[nval] and (STATE[nval]==STATE.register or STATE[nval]==STATE.instantiate or STATE[nval]==STATE.activate) then
		ctree.set_path_val(otree, path, nval)
	else
		dbg("Illegal value path=%s val=%s", path, nval)
		oslv.ctx.failure = true
	end
	
	dbg( "oslv=%s nslv=%s", tostring(oslv), tostring(nslv))
end

function cb2_set_sliver_uri( sys_conf, otree, ntree, path, begin, changed )
	if not sys_conf then return "cb2_set_sliver_uri" end

	local nval = ctree.get_path_val(ntree,path)
	local nslv = ctree.get_path_val(ntree,path:match("^/local_slivers/[^/]+/"))
	local oslv = ctree.get_path_val(otree,path:match("^/local_slivers/[^/]+/"))
	local slv_key = ctree.get_path_leaf(path:match("^/local_slivers/[^/]+/"))
	
	if nval and nslv and slv_key==sys_conf.id.."-"..nslv.local_slice.id and nval==sys_conf.server_base_uri.."/slivers/"..slv_key then
		ctree.set_path_val(otree, path, sys_conf.node_base_uri.."/slivers/"..slv_key)
	else
		dbg("Illegal value path=%s val=%s", path, nval)
		oslv.ctx.failure = true
	end
end

function cb2_set_instance_sn( sys_conf, otree, ntree, path, begin, changed )
	if not sys_conf then return "cb2_set_sliver_uri" end

	local nval = ctree.get_path_val(ntree,path)
	local oval = ctree.get_path_val(otree,path)
	
	if nval and tonumber(nval) and (not oval or tonumber(nval) >= tonumber(oval)) then
		ctree.set_path_val(otree, path, nval)
	else
		dbg("Illegal value path=%s val=%s", path, nval)
		oslv.ctx.failure = true
	end
end


local tmp_rules

local register_rules = {}
tmp_rules = register_rules
	table.insert(tmp_rules, {"/local_slivers/*/set_state",				cb2_set_state})
	table.insert(tmp_rules, {"/local_slivers/*/uri",				cb2_set_sliver_uri})
	table.insert(tmp_rules, {"/local_slivers/*/instance_sn",			cb2_set_instance_sn})
	table.insert(tmp_rules, {"/local_slivers/*/exp_data_uri",			crules.cb2_nop})
	table.insert(tmp_rules, {"/local_slivers/*/interfaces",				crules.cb2_nop})
	table.insert(tmp_rules, {"/local_slivers/*/local_template",			crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/local_template/arch",		crules.cb2_nop})
	table.insert(tmp_rules, {"/local_slivers/*/local_template/image_uri",		crules.cb2_nop})
	table.insert(tmp_rules, {"/local_slivers/*/local_template/type",		crules.cb2_nop})
	table.insert(tmp_rules, {"/local_slivers/*/local_slice",			crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/local_slice/instance_sn",		cb2_set_instance_sn})
	table.insert(tmp_rules, {"/local_slivers/*/local_slice/local_group",						crules.cb2_set})
--	table.insert(tmp_rules, {"/local_slivers/*/local_slice/local_group/uri",					rules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/local_slice/local_group/user_roles",					crules.cb2_set})
--	table.insert(tmp_rules, {"/local_slivers/*/local_slice/local_group/user_roles/*",	 			ssh.cb2_set_lgroup_role})
--	table.insert(tmp_rules, {"/local_slivers/*/local_slice/local_group/user_roles/*/is_researcher",			rules.cb2_nop}) --handled by set_local_group_role
--	table.insert(tmp_rules, {"/local_slivers/*/local_slice/local_group/user_roles/*/local_user", 	   		rules.cb2_nop}) --handled by set_local_group_role
--	table.insert(tmp_rules, {"/local_slivers/*/local_slice/local_group/user_roles/*/local_user/is_active",		rules.cb2_nop}) --handled by set_local_group_role
--	table.insert(tmp_rules, {"/local_slivers/*/local_slice/local_group/user_roles/*/local_user/auth_tokens",	rules.cb2_nop}) --handled by set_local_group_role
--	table.insert(tmp_rules, {"/local_slivers/*/local_slice/local_group/user_roles/*/local_user/auth_tokens/*",	rules.cb2_nop}) --handled by set_local_group_role
----


local alloc_rules = {}
tmp_rules = alloc_rules

local dealloc_rules = {}
tmp_rules = dealloc_rules

local deploy_rules = {}
tmp_rules = deploy_rules

local undeploy_rules = {}
tmp_rules = undeploy_rules

local start_rules = {}
tmp_rules = start_rules

local stop_rules = {}
tmp_rules = stop_rules

function cb2_set_lsliver( sys_conf, otree, ntree, path, begin, changed )
	if not sys_conf then return "cb2_set_lsliver" end
	if begin then return dbg("------------------------") or true end

	local nslvs = ntree.local_slivers
	local oslvs = otree.local_slivers
	local key = ctree.get_path_leaf(path)	
	
	if otree.state ~= cnode.STATE.production then
		nslvs[key] = nil
	end
		
	local i,imax = 1,3
	local prev_state
	
	while (nslvs[key] or oslvs[key]) and (i==1 or (oslvs[key] and oslvs[key].state ~= prev_state)) do

		local nslv = nslvs[key]
		local oslv = oslvs[key] or ctree.set_path_val(otree,path,{state=STATE.register --[[, local_template={}, local_slice={ local_group={ user_roles={}}} --]] })
		prev_state = oslv.state
		
		dbg("processing i=%s sliver=%s (%s) node_state=%s sliver_state=%s",
			i, key, tostring(oslv), otree.state, tostring((oslv or {}).state) )
		assert( i <= imax )
		
		if (oslv.state==STATE.register or (oslv.state==STATE.fail_alloc and i==1)) then
			
			oslv.ctx={failure=false, objective=STATE.register}
			ctree.iterate( crules.cb2, register_rules, sys_conf, otree, ntree, path )
			
			if oslv==oslvs[key] then
				
				if not oslv.ctx.failure and (oslv.set_state==STATE.instantiate or oslv.set_state==activate) then
					
					oslv.state = STATE.do_alloc
					
				elseif not nslv then
					
					oslvs[key] = nil
				else
					oslv.state = STATE.register
				end
			else
				assert(not oslvs[keys])
			end

		elseif (oslv.state==STATE.do_allocate) then
			
			oslv.ctx={failure=false, objective=STATE.allocate}
			ctree.iterate( crules.cb2, alloc_rules, sys_conf, otree, ntree, path )
			
			assert( oslv==oslvs[key] )
			if oslv.ctx.failure then
				oslv.state = STATE.fail_alloc
			else
				oslv.state = STATE.allocate
			end
			

		elseif (oslv.state==STATE.allocate or (oslv.state==STATE.fail_deploy and i==1)) and 
			(not nslv or
			 nslv.instance_sn > oslv.instance_sn or nslv.set_state==STATE.register) then
			
			oslv.ctx={failure=false, objective=STATE.register}
			ctree.iterate( crules.cb2, dealloc_rules, sys_conf, otree, ntree, path )
			
			assert( oslv==oslvs[key] and not oslv.ctx.failure)
			oslv.state = STATE.register

		elseif (oslv.state==STATE.allocate or (oslv.state==STATE.fail_deploy and i==1)) and
			(nslv.set_state==STATE.instantiate or nslv.set_state==STATE.activate) then
			
			oslv.ctx={failure=false, objective=STATE.instantiate}
			ctree.iterate( crules.cb2, deploy_rules, sys_conf, otree, ntree, path )
			
			assert( oslv==oslvs[key] )
			if oslv.ctx.failure then
				oslv.state = STATE.fail_deploy
			else
				oslv.state = STATE.instantiate
			end

			
			
		elseif (oslv.state==STATE.instantiate or (oslv.state==STATE.fail_start and i==1)) and
			(not nslv or
			 nslv.instance_sn > oslv.instance_sn or nslv.local_slice.instance_sn > oslv.local_slice.instance_sn or
			 nslv.set_state==STATE.register) then
			
			oslv.ctx={failure=false, objective=STATE.allocate}
			ctree.iterate( crules.cb2, undeploy_rules, sys_conf, otree, ntree, path )
			
			assert( oslv==oslvs[key] and not oslv.ctx.failure)
			oslv.state = STATE.allocate

		elseif oslv.state==STATE.instantiate or (oslv.state==STATE.fail_start or i==1) and
			(nslv.set_state==STATE.activate) then
			
			oslv.ctx={failure=false, objective=STATE.activate}
			ctree.iterate( crules.cb2, start_rules, sys_conf, otree, ntree, path )
			
			assert( oslv==oslvs[key] )
			if oslv.ctx.failure then
				oslv.state = STATE.fail_start
			else
				oslv.state = STATE.activate
			end

			
		elseif (oslv.state==STATE.activate) and
			(not nslv or
			 nslv.instance_sn > oslv.instance_sn or nslv.local_slice.instance_sn > oslv.local_slice.instance_sn or
			 nslv.set_state==STATE.register or nslv.set_state==STATE.instantiate) then
			
			oslv.ctx={failure=false, objective=STATE.instantiate}
			ctree.iterate( crules.cb2, stop_rules, sys_conf, otree, ntree, path )
			
			assert( oslv==oslvs[key] and not oslv.ctx.failure)
			oslv.state = STATE.instantiate

		end
		
		
		i = i + 1
	end
	

	return true	
end












out_filter = {}
tmp_rules = out_filter
	table.insert(tmp_rules, {"/local_slivers"})
	table.insert(tmp_rules, {"/local_slivers/*"})
	table.insert(tmp_rules, {"/local_slivers/*/uri"})
	table.insert(tmp_rules, {"/local_slivers/*/slice"})
	table.insert(tmp_rules, {"/local_slivers/*/slice/uri"})	
	table.insert(tmp_rules, {"/local_slivers/*/node"})
	table.insert(tmp_rules, {"/local_slivers/*/node/uri"})
	table.insert(tmp_rules, {"/local_slivers/*/description"})
	table.insert(tmp_rules, {"/local_slivers/*/instance_sn"})
	table.insert(tmp_rules, {"/local_slivers/*/template"})
	table.insert(tmp_rules, {"/local_slivers/*/template/uri"})
	table.insert(tmp_rules, {"/local_slivers/*/local_template"})
	table.insert(tmp_rules, {"/local_slivers/*/exp_data_uri"})
	table.insert(tmp_rules, {"/local_slivers/*/exp_data_sha256"})
	table.insert(tmp_rules, {"/local_slivers/*/interfaces"})
	table.insert(tmp_rules, {"/local_slivers/*/interfaces/*"})
	table.insert(tmp_rules, {"/local_slivers/*/interfaces/*/nr"})
	table.insert(tmp_rules, {"/local_slivers/*/interfaces/*/name"})
	table.insert(tmp_rules, {"/local_slivers/*/interfaces/*/type"})
	table.insert(tmp_rules, {"/local_slivers/*/interfaces/*/parent_name"})
	table.insert(tmp_rules, {"/local_slivers/*/interfaces/*/mac_addr"})
	table.insert(tmp_rules, {"/local_slivers/*/interfaces/*/ipv4_addr"})
	table.insert(tmp_rules, {"/local_slivers/*/interfaces/*/ipv6_addr"})
	table.insert(tmp_rules, {"/local_slivers/*/properties"})
	table.insert(tmp_rules, {"/local_slivers/*/properties/*"})
	table.insert(tmp_rules, {"/local_slivers/*/nr"})
	table.insert(tmp_rules, {"/local_slivers/*/state"})
	table.insert(tmp_rules, {"/local_slivers/*/errors"})
	table.insert(tmp_rules, {"/local_slivers/*/errors/*"})
	table.insert(tmp_rules, {"/local_slivers/*/errors/*/member"})
	table.insert(tmp_rules, {"/local_slivers/*/errors/*/message"})

