#!/usr/bin/lua
-- System variables and defaults
-- SERVER_URI=nil eg:"https://controller.confine-project.eu/api"
-- COUNT=0

local nixio   = require "nixio"
local sig     = require "signal"
local lsys    = require "luci.sys"
--local lmo     = require "lmo"
--local util    = require "luci.util"


local tree    = require "confine.tree"
local data    = require "confine.data"
local tools   = require "confine.tools"
local rules   = require "confine.rules"
local node    = require "confine.node"
local server  = require "confine.server"
local system  = require "confine.system"

local dbg     = tools.dbg

local null    = data.null



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

local function get_local_templates( sys_conf, node )

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
	data.file_put(base, "index.html", system.rest_base_dir)

	pcall(nixio.fs.remover, system.rest_templates_dir)
	data.file_put(get_local_templates(sys_conf, node), nil, system.rest_templates_dir)

	data.file_put(tree.filter(rules.node_out_filter, node), "index.html", system.rest_node_dir)	
	
	pcall(nixio.fs.remover, system.rest_slivers_dir)
	data.file_put(tree.filter(rules.slivers_out_filter, node.local_slivers), nil, system.rest_slivers_dir)


end







local function cb(sys_conf, action, task, cb_tasks, out_node, path, key, oldval, newval )

	dbg("%s %-22s %-40s %s => %s", action, task, path..key,
		data.val2string(oldval or null):gsub("\n",""):sub(1,30),
		data.val2string(newval or null):gsub("\n",""):sub(1,30))

	if cb_tasks[task] then
		
		local finval = cb_tasks[task](sys_conf, action, out_node, path, key, oldval, newval)
		
		if task ~= "CB_NOP" and task ~= "CB_COPY" then			
			dbg("%s %-22s %-40s   ===> %s", action, task, path..key, data.val2string(finval):gsub("\n",""):sub(1,30))
		end

		if finval == nil then
			node.set_node_state( sys_conf, out_node, node.STATE.setup )
		end
		
	else
		dbg("cb() undefined cb_task=%s", task)
	end	
	
--	assert(sliver_obj.local_template.local_arch == own_node_arch,
--       "Sliver_arch=%q does not match local_arch=%q!"
--	   %{ sliver_obj.local_template.arch, own_node_arch })

end



function main_loop( )
	local sys_conf
	local local_node
	local iteration = 1
	
	while true do
		local success = true
		local err_msg = nil

		dbg("updating...")

		dbg("getting system conf...")
		sys_conf = system.get_system_conf(sys_conf, arg)
		assert(sys_conf)
		
		dbg("getting local node...")
		local_node = node.get_local_node(sys_conf, local_node)
		assert(local_node)

		dbg("getting server node...")
		local server_node
		if( sys_conf.debug ) then
			server_node = server.get_server_node(sys_conf)
		else
			success,server_node = pcall( server.get_server_node, sys_conf )
			err_msg = (not success) and server_node or nil
		end
	
	
		if success and server_node then
			--util.dumptable(server_node)
			--dbg("tree fingerprint is %08x", lmo.hash(util.serialize_data(server_node)))
		
			dbg("processing input")
			if( sys_conf.debug ) then
				tree.process( cb, sys_conf, rules.dflt_cb_tasks, local_node, rules.node_in_rules, local_node, server_node )
			else
				success,err_msg = pcall(
				tree.process, cb, sys_conf, rules.dflt_cb_tasks, local_node, rules.node_in_rules, local_node, server_node )
			end
		end
		
		if success then
			upd_node_rest_conf( sys_conf, local_node )
			data.file_put( local_node, system.cache_file )
		else 
			local msg = "ERROR: "..((type(err_msg)=="string" and err_msg) or (type(err_msg)=="table" and tree.as_string(err_msg)) or tostring(err_msg) )
			dbg(msg)
			
			node.set_node_state(sys_conf, local_node, node.STATE.setup)
			
			upd_node_rest_conf( sys_conf, { message = msg, errors = null } )
			data.file_put( local_node, system.cache_file )
			
		end
			
		
		dbg("count=%d i=%d" %{sys_conf.count, iteration})
		if sys_conf.count==0 or sys_conf.count > iteration then
			iteration = iteration + 1
		else
			break
		end
		
		tools.sleep(sys_conf.interval)
		if tools.stop then break end
		
		dbg("next iteration=%d...",iteration)
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


