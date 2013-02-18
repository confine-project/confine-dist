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
	base.uri                   = sys_conf.node_base_uri.."/"
	base.node_uri              = node.uri
	base.slivers_uri           = sys_conf.node_base_uri.."/slivers"
	base.templates_uri         = sys_conf.node_base_uri.."/templates"

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








function main_loop( )
	local sys_conf
	local local_node
	local err_cnt = 0
	local iteration = 1
	
	while true do
		local success = true
		local err_msg = nil

		dbg("updating...")

		dbg("getting system conf...")
		sys_conf = system.get_system_conf( sys_conf, arg )
		assert(sys_conf)
		
		dbg("getting local node...")
		local_node = cnode.get_local_node(sys_conf, local_node)
		assert(local_node)
		
		
		dbg("getting server node...")
		local server_node
		if sys_conf.debug  then
			server_node = server.get_server_node(sys_conf)
		else
			success,server_node = pcall( server.get_server_node, sys_conf )
			err_msg = (not success) and "ERR_RETRY "..server_node or nil
		end
		--util.dumptable(server_node)
		--dbg("tree fingerprint is %08x", lmo.hash(util.serialize_data(server_node)))
	
		dbg("processing input")
		if success then
			if( sys_conf.debug ) then
				ctree.iterate( crules.cb2, cnode.in_rules2, sys_conf, local_node, server_node, "/" )
			else
				success,err_msg = pcall(
				ctree.iterate, crules.cb2, cnode.in_rules2, sys_conf, local_node, server_node, "/" )
			end
		end
		
		assert(success or err_msg:sub(1,9)=="ERR_RETRY" or err_msg:sub(1,9)=="ERR_SETUP", err_msg)

		
		dbg("updating node RestAPI")
		
		if success then
			upd_node_rest_conf( sys_conf, local_node )
--			cdata.file_put( local_node, system.node_state_file )
			err_cnt = 0
			
		elseif err_msg:sub(1,9)=="ERR_RETRY" and sys_conf.retry_limit==0 or sys_conf.retry_limit > err_cnt then
			
			err_cnt = err_cnt + 1
			dbg("IGNORING ERROR (".."err_cnt="..err_cnt.." retry_limit="..sys_conf.retry_limit.."): "..err_msg)
		else
			
			--local msg = "ERROR: "..((type(err_msg)=="string" and err_msg) or (type(err_msg)=="table" and ctree.as_string(err_msg)) or tostring(err_msg) )
			dbg("ERROR: "..err_msg)
			
			cnode.set_node_state(sys_conf, local_node, cnode.STATE.setup)
			upd_node_rest_conf( sys_conf, { message = err_msg, errors = null } )
--			cdata.file_put( local_node, system.node_state_file )
		end

		cdata.file_put( local_node, system.node_state_file )
		cdata.file_put( server_node, system.server_state_file)
			
		if sys_conf.count==0 or sys_conf.count > iteration then
			
			dbg("count=%d i=%d" %{sys_conf.count, iteration})
			iteration = iteration + 1
			
			if sys_conf.interactive then
				tools.dbg_(false, "Press enter for next iteration:")
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
	
	tools.mkdirr( system.rest_confine_dir)
	nixio.fs.symlink( system.rest_confine_dir, system.www_dir )
	
	main_loop()
	
	dbg("goodbye")

end
