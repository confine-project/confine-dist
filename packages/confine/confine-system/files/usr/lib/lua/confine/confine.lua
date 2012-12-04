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


local node_cache_file          = "/tmp/confine.cache"
	
local node_www_dir             = "/www/confine"
local node_rest_confine_dir    = "/tmp/confine"
local node_rest_base_dir       = node_rest_confine_dir.."/api/"
local node_rest_node_dir       = node_rest_confine_dir.."/api/node/"
local node_rest_slivers_dir    = node_rest_confine_dir.."/api/slivers/"
local node_rest_templates_dir  = node_rest_confine_dir.."/api/templates/"

local RSA_HEADER               = "%-%-%-%-%-BEGIN RSA PUBLIC KEY%-%-%-%-%-"
local RSA_TRAILER              = "%-%-%-%-%-END RSA PUBLIC KEY%-%-%-%-%-"


local count = tonumber(lsys.getenv("COUNT")) or 0



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
	
			if not templates.k then
				templates.k = v
			end
		end
	end
	return templates
end

local function upd_node_rest_conf( sys_conf, node )

	data.file_put(tree.filter(rules.node_rules, node), "index.html", node_rest_node_dir)	
	
	pcall(nixio.fs.remover, node_rest_templates_dir)
	data.file_put(get_local_templates(sys_conf, node), nil, node_rest_templates_dir)

	pcall(nixio.fs.remover, node_rest_slivers_dir)
	data.file_put(tree.filter(rules.slivers_out_rules, node.local_slivers), nil, node_rest_slivers_dir)

	local base = get_local_base( sys_conf, node )

	data.file_put(base, "index.html", node_rest_base_dir)

end







local function cb(sys_conf, action, task, cb_tasks, out_node, path, key, oldval, newval )

	local finval ="???"

	dbg("%s %-22s %-40s %s => %s", action, task, path..key,
		data.val2string(oldval or null):gsub("\n",""):sub(1,30),
		data.val2string(newval or null):gsub("\n",""):sub(1,30))

	if cb_tasks[task] then
		
		finval = cb_tasks[task](sys_conf, action, out_node, path, key, oldval, newval)
		
		if task ~= "CB_NOP" and task ~= "CB_COPY" then			
			dbg("%s %-22s %-40s   ===> %s", action, task, path..key, data.val2string(finval):gsub("\n",""):sub(1,30))
		end
		
	else
		dbg("cb() undefined cb_task=%s", task)
	end
	
	if not finval then
		node.set_node_state( out_node, node.STATE.setup )
	end

	
	
--	assert(sliver_obj.local_template.local_arch == own_node_arch,
--       "Sliver_arch=%q does not match local_arch=%q!"
--	   %{ sliver_obj.local_template.arch, own_node_arch })

end









math.randomseed( os.time() )

--for k in pairs(sig) do print(k) end
sig.signal(sig.SIGINT,  tools.handler)
sig.signal(sig.SIGTERM, tools.handler)

os.remove( node_cache_file )

tools.mkdirr( node_rest_confine_dir)
nixio.fs.symlink( node_rest_confine_dir, node_www_dir )

local local_node

while true do
	dbg("get_system_conf...")
	local sys_conf = system.get_system_conf()
	
	if sys_conf then
		dbg("updating...")	
	
		local_node = node.get_local_node(sys_conf, local_node)

		--local se,server_node= pcall(server.get_server_node(sys_conf)		
		--if se then
		local server_node = server.get_server_node(sys_conf)
		if server_node then
			--util.dumptable(server_node)
			--dbg("tree fingerprint is %08x", lmo.hash(util.serialize_data(server_node)))
		
			dbg("comparing states...")
			tree.process(cb, sys_conf, rules.dflt_cb_tasks, local_node, rules.node_rules, local_node, server_node )
		else
			dbg("ERROR: "..tostring(server_node))
		end
		
		upd_node_rest_conf( sys_conf, local_node )
		data.file_put( local_node, node_cache_file )
	end
	
	if count == 1 then
		break
	elseif count > 1 then
		count = count - 1
	end
	
	tools.sleep(5)
	if tools.stop then break end

	dbg("next iteration=%d...",local_node.dbg_iteration + 1)
end	

dbg("goodbye")
