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
	["bad_conf"]  	  = "bad_conf",
	["register"] 	  = "register",
	["fail_alloc"]    = "fail_alloc",
	["allocate"]	  = "allocate",
	["fail_deploy"]   = "fail_deploy",
	["instantiate"]	  = "instantiate",
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


local tmp_rules

local configure_rules = {}
tmp_rules = configure_rules
	table.insert(tmp_rules, {"/local_slivers/*/uri",				crules.cb2_nop})
	table.insert(tmp_rules, {"/local_slivers/*/instance_sn",			crules.cb2_nop})
	table.insert(tmp_rules, {"/local_slivers/*/test",				crules.cb2_log})

local allocate_rules = {}
tmp_rules = allocate_rules

local deploy_rules = {}
tmp_rules = deploy_rules

local activate_rules = {}
tmp_rules = activate_rules

function cb2_process_lsliver( sys_conf, otree, ntree, path, begin, changed )
	if not sys_conf then return "cb2_process_lsliver" end

	local slvs = otree.local_slivers
	local key = ctree.get_path_leaf(path)
	
	if begin then return dbg("------------------------") or true end
	
	if otree.state ~= cnode.STATE.production then
		ntree.local_slivers[key] = nil
	end
	
	local i,imax = 1,3
	local prev_state
	
	while i==1 or prev_state ~= ((slvs[key] or {}).state) do
		
		local slv = slvs[key]
		prev_state = (slv or {}).state
		
		dbg("processing i=%s sliver=%s (%s) node_state=%s sliver_state=%s", i, key, tostring(slv), otree.state, tostring((slv or {}).state) )
		assert( i <= imax )
		
		local rules
		if not slv and i==1 then
			
			slv = ctree.set_path_val(otree,path,{})			
			rules = configure_rules

		elseif slv.state==STATE.bad_conf or slv.state==STATE.register or (slv.state==STATE.fail_alloc and i==1) then
			
			rules = configure_rules
			
		elseif slv.state==STATE.allocate or (slv.state==STATE.fail_deploy or i==1) then
			
			rules = allocate_rules
			
		elseif slv.state==STATE.instantiate or (slv.state==STATE.fail_start or i==1) then
			
			rules = deploy_rules
			
		elseif slv.state==STATE.activate then
			
			rules = activate_rules

		elseif slv.state==STATE.fail_alloc or slv.state==STATE.fail_deploy or slv.state==STATE.fail_start then
			
			rules = nil
			
		else
			assert( false, "Illegal state=%s" %tostring(slv.state))
		end
		
		if rules then
			ctree.iterate( crules.cb2, rules, sys_conf, otree, ntree, path )
		end
		
		i = i + 1
	end
	

	return true	
end











--register_rules = {}
--tmp_rules = register_rules
--	table.insert(tmp_rules, {["/local_slivers"]					= "CB_NOP"})
--	table.insert(tmp_rules, {["/local_slivers/[^/]+"]				= "CB_CONFIG_LSLIVER"})
----	table.insert(tmp_rules, {["/local_slivers/[^/]+/uri"]				= "CB_COPY"})
--	table.insert(tmp_rules, {["/local_slivers/[^/]+/instance_sn"]			= "CB_COPY"})
--
--	--table.insert(tmp_rules, {["/local_slivers/[^/]+/local_slice"]				= "CB_ADD_DEL_EMPTY_TABLE"})--"CB_SET_LSLIVER_LSLICE"})
--	--table.insert(tmp_rules, {["/local_slivers/[^/]+/local_slice/id"]			= "CB_COPY"})
--	--table.insert(tmp_rules, {["/local_slivers/[^/]+/local_slice/new_sliver_instance_sn"]	= "CB_COPY"})
--	--table.insert(tmp_rules, {["/local_slivers/[^/]+/local_slice/instance_sn"]		= "CB_COPY"})
--	--table.insert(tmp_rules, {["/local_slivers/[^/]+/local_slice/set_state"]			= "CB_COPY"})
--
--	table.insert(tmp_rules, {["/local_slivers/[^/]+/state"]				= "CB_NOP"})--"CB_SET_SLIVER_STATE"})




out_filter = {}
tmp_rules = out_filter
	table.insert(tmp_rules, {["/local_slivers"]					= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+"]				= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/uri"]				= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/slice"]				= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/slice/uri"]			= "CB_NOP"})	
	table.insert(tmp_rules, {["/local_slivers/[^/]+/node"]				= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/node/uri"]			= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/description"]			= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/instance_sn"]			= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/template"]			= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/template/uri"]			= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/local_template"]		= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/exp_data_uri"]			= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/exp_data_sha256"]		= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/interfaces"]			= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/interfaces/[^/]+"]		= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/interfaces/[^/]+/nr"]		= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/interfaces/[^/]+/name"]		= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/interfaces/[^/]+/type"]		= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/interfaces/[^/]+/parent_name"]	= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/interfaces/[^/]+/mac_addr"]	= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/interfaces/[^/]+/ipv4_addr"]	= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/interfaces/[^/]+/ipv6_addr"]	= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/properties"]			= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/properties/[^/]+"]		= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/nr"]				= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/state"]				= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/errors"]			= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/errors/[^/]+"]			= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/errors/[^/]+/member"]		= "CB_NOP"})
	table.insert(tmp_rules, {["/local_slivers/[^/]+/errors/[^/]+/message"]		= "CB_NOP"})


function config_local_sliver( sys_conf, action, out_node, path, key, oldslv, newslv )

	assert( not oldslv or oldslv.state )
	assert( not newslv or newslv.local_slice)

	if action == "ADD" then

		assert(oldslv == nil)
	
		local ret = ctree.copy_path_val( "ADD", out_node, path, key, nil, { ["state"] = STATE.bad_conf })
		
		return ret
	
	elseif action == "DEL" then -- the missing trigger
		
		
--		remove_slivers( sys_conf, oldslv )
		return ctree.copy_path_val( "DEL", out_node, path, key, oldslv, newslv)
	
	elseif action == "CHG" then
		
--		return ctree.copy_path_val( action, out_node, path, key, oldslv, newslv)
		return oldslv
	end
end


local sliver_cb_tasks = tools.join_tables( crules.dflt_cb_tasks, {
	
	["CB_CONFIG_LSLIVER"]	= function( sys_conf, action, out_node, path, key, oldslv, newslv )
				--	ctree.dump(newslv)
					return config_local_sliver( sys_conf, action, out_node, path, key, oldslv, newslv )
				end
	
} )


function process_local_slivers( sys_conf, action, out_node, path, key, oldval, newval )
	ctree.process( crules.cb, sys_conf, sliver_cb_tasks, out_node, register_rules, oldval, newval, path..key.."/" )
	return ctree.get_path_val(out_node, path..key.."/")
end


