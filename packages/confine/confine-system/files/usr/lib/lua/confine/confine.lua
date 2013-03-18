#!/usr/bin/lua
-- System variables and defaults
-- SERVER_URI=nil eg:"https://controller.confine-project.eu/api"

local nixio   = require "nixio"
local sig     = require "signal"


local ctree   = require "confine.tree"
local cdata   = require "confine.data"
local tools   = require "confine.tools"
local crules   = require "confine.rules"
local cnode   = require "confine.node"
local server  = require "confine.server"
local system  = require "confine.system"
local sliver  = require "confine.sliver"

local dbg     = tools.dbg

local null    = cdata.null


local require_server_cert = false
local require_node_cert   = false





local function get_local_base( sys_conf, node )
	local base = {}

	base.uri		= sys_conf.node_base_uri.."/"

	base.confine_params	= {
		debug_ipv6_prefix	= sys_conf.debug_ipv6_prefix,
		priv_ipv6_prefix	= sys_conf.priv_ipv6_prefix
		}
	base.testbed_params	= {
		mgmt_ipv6_prefix	= sys_conf.mgmt_ipv6_prefix,
		priv_ipv4_prefix_dflt 	= sys_conf.priv_ipv4_prefix,
		sliver_mac_prefix_dflt	= sys_conf.sliver_mac_prefix
		}

	base.node_uri		= node.uri
	base.slivers_uri	= sys_conf.node_base_uri.."/slivers"
	base.templates_uri	= sys_conf.node_base_uri.."/templates"

	return base	
end


local function upd_node_rest_conf( sys_conf, node )

	local base = get_local_base( sys_conf, node )
	cdata.file_put(base, "index.html", system.rest_base_dir)

	pcall(nixio.fs.remover, system.rest_templates_dir)
	cdata.file_put(ctree.filter(sliver.template_out_filter, sliver.get_templates(node)), nil, system.rest_templates_dir)

	cdata.file_put(ctree.filter(cnode.out_filter, node), "index.html", system.rest_node_dir)	
	
	pcall(nixio.fs.remover, system.rest_slivers_dir)
	if node.local_slivers then
		cdata.file_put(ctree.filter(sliver.out_filter, node.local_slivers), nil, system.rest_slivers_dir)
	end

end








function main_loop( sys_conf )
	local local_node
	local err_cnt = 0
	local iteration = 1
	
	while true do
		local success = true
		local err_msg = nil

--		dbg("updating...")

--		dbg("getting system conf...")
		if not system.get_system_conf( sys_conf ) then break end
		
		dbg("getting local node...")
		local_node = cnode.get_local_node(sys_conf, local_node)
		assert(local_node)
		cdata.file_put( local_node, system.node_state_file )
		
		
		dbg("getting server node...")
		local server_node
		if sys_conf.debug  then
			server_node = server.get_server_node(sys_conf)
		else
			success,server_node = pcall( server.get_server_node, sys_conf )
			if not success then
				dbg( crules.add_error(local_node, "/", "ERR_RETRY "..server_node, nil) )
			end
		end
		cdata.file_put( server_node, system.server_state_file)

		--util.dumptable(server_node)
		--dbg("tree fingerprint is %08x", lmo.hash(util.serialize_data(server_node)))
	
		dbg("processing input")
		if not local_node.errors then
			if( sys_conf.debug ) then
				ctree.iterate( crules.cb2, cnode.in_rules2, sys_conf, local_node, server_node, "/" )
			else
				success,err_msg = pcall(
				ctree.iterate, crules.cb2, cnode.in_rules2, sys_conf, local_node, server_node, "/" )
				
				if not success then
					dbg( crules.add_error(local_node, "/", "ERR_SETUP "..err_msg, nil) )
					cnode.set_node_state(sys_conf, local_node, cnode.STATE.debug)
				end
					
			end
		end
		
		if local_node.errors then
			
			err_cnt = err_cnt + 1
			
			local k,v
			for k,v in pairs( local_node.errors ) do
				
				if v.message:sub(1,9)=="ERR_RETRY" then
					v.message:gsub("ERR_RETRY","ERR_RETRY (%d/%d)"%{err_cnt, sys_conf.retry_limit})
				end
					
				if v.message:sub(1,9)~="ERR_RETRY" or (sys_conf.retry_limit~=0 and sys_conf.retry_limit < err_cnt) then
					cnode.set_node_state(sys_conf, local_node, cnode.STATE.debug)
				end
			end
		else
			err_cnt = 0
		end
		
		cdata.file_put( local_node, system.node_state_file )
		upd_node_rest_conf( sys_conf, local_node )


			
		if sys_conf.count==0 or sys_conf.count > iteration then
			
			if tools.stop then break end
			dbg("count=%d i=%d" %{sys_conf.count, iteration})
			iteration = iteration + 1
			
			if sys_conf.interactive then
				tools.dbg_(false, false, "main_loop", "Press enter for next iteration:")
				io.read()
			else
				tools.sleep(sys_conf.interval)
			end

			if tools.stop then break end
			dbg("next iteration=%d...",iteration)
		else
			break
		end
		
	end	
end


if system.check_pid() then
	
	math.randomseed( os.time() )
	
	sig.signal(sig.SIGINT,  tools.handler)
	sig.signal(sig.SIGTERM, tools.handler)
	
	local sys_conf = system.get_system_conf( nil, arg )
	
	pcall(nixio.fs.remover, system.rest_confine_dir)
	tools.mkdirr(system.rest_confine_dir)
	
	pcall(nixio.fs.remover, "/www"..(sys_conf.node_base_path:match("^/.+/")))
	tools.mkdirr( "/www"..(sys_conf.node_base_path:match("^/.+/")) )
	nixio.fs.symlink( system.rest_confine_dir, "/www"..sys_conf.node_base_path )
	
	main_loop( sys_conf )
	
	system.stop()
	
end

