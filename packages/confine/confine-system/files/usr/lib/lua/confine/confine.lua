#!/usr/bin/lua
-- System variables and defaults
-- SERVER_URI=nil eg:"https://controller.confine-project.eu/api"
-- COUNT=0

local nixio   = require "nixio"
local sig     = require "signal"
--local lsys    = require "luci.sys"
--local lmo     = require "lmo"
--local util    = require "luci.util"


local ctree   = require "confine.tree"
local cdata   = require "confine.data"
local tools   = require "confine.tools"
local rules   = require "confine.rules"
local cnode   = require "confine.node"
local server  = require "confine.server"
local system  = require "confine.system"
local sliver  = require "confine.sliver"

local dbg     = tools.dbg

local null    = cdata.null



--table.foreach(sig, print)


local require_server_cert = false
local require_node_cert   = false



local RSA_HEADER               = "%-%-%-%-%-BEGIN RSA PUBLIC KEY%-%-%-%-%-"
local RSA_TRAILER              = "%-%-%-%-%-END RSA PUBLIC KEY%-%-%-%-%-"


--local count = tonumber(lsys.getenv("COUNT")) or 0



local function get_local_base( sys_conf, node )
	local base = {}
	base.uri                   = sys_conf.node_base_uri.."/"
	base.node_uri              = node.uri
	base.slivers_uri           = sys_conf.node_base_uri.."/slivers"
	base.templates_uri         = sys_conf.node_base_uri.."/templates"

	return base	
end

local function get_local_templates( node )

	local templates = {}
	local k,v
	if node.local_slivers then
		for k,v in pairs(node.local_slivers) do
	
		end
	end
	return templates
end

local function upd_node_rest_conf( sys_conf, node )

	local base = get_local_base( sys_conf, node )
	cdata.file_put(base, "index.html", system.rest_base_dir)

	pcall(nixio.fs.remover, system.rest_templates_dir)
	cdata.file_put(get_local_templates(node), nil, system.rest_templates_dir)

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
		
		
		dbg("\ngetting server node...")
		local server_node
		if sys_conf.debug  then
			server_node = server.get_server_node(sys_conf)
		else
			success,server_node = pcall( server.get_server_node, sys_conf )
			err_msg = (not success) and "ERR_RETRY "..server_node or nil
		end
		--util.dumptable(server_node)
		--dbg("tree fingerprint is %08x", lmo.hash(util.serialize_data(server_node)))
	
		dbg("\nprocessing input")
		if success then
			if( sys_conf.debug ) then
				ctree.iterate( rules.cb2, cnode.in_rules2, sys_conf, local_node, server_node, "/" )
--				ctree.process( rules.cb, sys_conf, cnode.cb_tasks, local_node, cnode.in_rules, local_node, server_node, "/" )
			else
				success,err_msg = pcall(
				ctree.iterate, rules.cb2, cnode.in_rules2, sys_conf, local_node, server_node, "/" )
--				ctree.process, rules.cb, sys_conf, cnode.cb_tasks, local_node, cnode.in_rules, local_node, server_node, "/" )
			end
		end
		
		assert(success or err_msg:sub(1,9)=="ERR_RETRY" or err_msg:sub(1,9)=="ERR_SETUP", err_msg)

		
		dbg("\nupdating node RestAPI")
		
		if success then
			upd_node_rest_conf( sys_conf, local_node )
			cdata.file_put( local_node, system.cache_file )
			err_cnt = 0
			
		elseif err_msg:sub(1,9)=="ERR_RETRY" and sys_conf.retry_limit==0 or sys_conf.retry_limit > err_cnt then
			
			err_cnt = err_cnt + 1
			dbg("IGNORING ERROR (".."err_cnt="..err_cnt.." retry_limit="..sys_conf.retry_limit.."): "..err_msg)
		else
			
			--local msg = "ERROR: "..((type(err_msg)=="string" and err_msg) or (type(err_msg)=="table" and ctree.as_string(err_msg)) or tostring(err_msg) )
			dbg("ERROR: "..err_msg)
			
			cnode.set_node_state(sys_conf, local_node, cnode.STATE.setup)
			upd_node_rest_conf( sys_conf, { message = err_msg, errors = null } )
			cdata.file_put( local_node, system.cache_file )
		end
			
		if sys_conf.count==0 or sys_conf.count > iteration then
			
			dbg("count=%d i=%d" %{sys_conf.count, iteration})
			iteration = iteration + 1
			tools.sleep(sys_conf.interval)
			if tools.stop then break end
			dbg("next iteration=%d...",iteration)
		else
			break
		end
		
	end	
end





math.randomseed( os.time() )

--for k in pairs(sig) do print(k) end
sig.signal(sig.SIGINT,  tools.handler)
sig.signal(sig.SIGTERM, tools.handler)

os.remove( system.cache_file )

tools.mkdirr( system.rest_confine_dir)
nixio.fs.symlink( system.rest_confine_dir, system.www_dir )




--local k,o
--for k,o in ipairs(arg) do
--	dbg(k..": ".. o)
--end

main_loop()

dbg("goodbye")

--local k,j
--for  k,j in pairs({{null},{false},{nil},{0},{""}}) do
--	local v = j[1]
--	print("type=%-8s val=%-20s NOTval=%-8s equalNil=%-8s unequalNil=%-8s"
--	      %{ type(v), tostring(v), tostring(not v), tostring(v==nil), tostring(v~=nil) })
--end


