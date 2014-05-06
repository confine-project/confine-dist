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
local ssh    = require "confine.ssh"
local ssl    = require "confine.ssl"
local dbg    = tools.dbg
local err    = tools.err

local null   = cdata.null

NODE = {
	["registered"] 	 = "registered",
	["fail_allocate"]= "fail_allocate",
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

SLIVER_TYPES = {
	["debian"] = "^debian$",
	["debian6"] = "^debian6$",
	["debian7"] = "^debian7$",
	["openwrt"] = "^openwrt$",
	["openwrt-backfire"] = "^openwrt%-backfire$",
	["openwrt-attitude-adjustment"] = "^openwrt%-attitude%-adjustment$"
}

SLIVER_AUTH_FILES = {
	["debian"] = "/rootfs/root/.ssh/authorized_keys",
	["debian6"] = "/rootfs/root/.ssh/authorized_keys",
	["debian7"] = "/rootfs/root/.ssh/authorized_keys",
	["openwrt"] = "/rootfs/etc/dropbear/authorized_keys",
	["openwrt-backfire"] = "/rootfs/etc/dropbear/authorized_keys",
	["openwrt-attitude-adjustment"] = "/rootfs/etc/dropbear/authorized_keys"
}


IF_TYPES = {
	["private"] = "^private$",
	["management"] = "^management$",
	["isolated"] = "^isolated$",
	["public4"] = "^public4$"
}



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
local deployed_rules = {}
local undeploy_rules = {}
local start_rules = {}
local stop_rules = {}








local function add_lslv_err( tree, path, msg, val )
	assert(tree and path and msg)

	local oslv = ctree.get_path_val(tree, path:match("^/local_slivers/[^/]+/"))

	oslv.errors = oslv.errors or {}

	local slv_key = ctree.get_path_leaf(path:match("^/local_slivers/[^/]+/"))
	local member = path
	member = member:gsub("/local_slivers/","/slivers/")
	member = member:gsub("/local_slice/","/slice/")
	member = member:gsub("/local_template/","/template/")
	member = member:gsub("/local_group/","/group/")
	
	table.insert(oslv.errors, { member=member, message=tostring(msg).." value="..cdata.val2string(val) })
	return "Error path=%s msg=%s val=%s" ,path, tostring(msg), cdata.val2string(val)
end


function cb2_set_state( rules, sys_conf, otree, ntree, path, begin, changed )
	if not rules then return "cb2_set_state" end

	local oval        = ctree.get_path_val(otree,path)
	local nval        = ctree.get_path_val(ntree,path)
	local oslv        = ctree.get_path_val(otree,path:match("^/local_slivers/[^/]+/"))
	local nslv        = ctree.get_path_val(ntree,path:match("^/local_slivers/[^/]+/"))
	
	if nval and (nval==null or SERVER[nval]) then
		
		if nval ~= oval then
			oslv.set_state = nval
		end
		
	elseif nval then
		dbg( add_lslv_err(otree, path, "Illegal", nval))
	end
end


function cb2_sliver_uri( rules, sys_conf, otree, ntree, path, begin, changed )
	if not rules then return "cb2_sliver_uri" end

	local oslv = ctree.get_path_val(otree,path:match("^/local_slivers/[^/]+/"))
	
	ctree.set_path_val(otree, path, sys_conf.node_base_uri.."/slivers/"..oslv.uri_id)
end

function cb2_node_uri( rules, sys_conf, otree, ntree, path, begin, changed )
	if not rules then return "cb2_node_uri" end

	ctree.set_path_val(otree, path, sys_conf.node_base_uri.."/node")
end


function cb2_instance_sn( rules, sys_conf, otree, ntree, path, begin, changed )
	if not rules then return "cb2_instance_sn" end

	local nval = ctree.get_path_val(ntree,path)
	local oval = ctree.get_path_val(otree,path)
	
	if nval and type(nval)=="number" then
		if nval~=oval then
			ctree.set_path_val(otree, path, nval)
		end
	elseif nval then
		dbg( add_lslv_err(otree, path, "Illegal "..type(nval), nval))
	end
end


--function cb2_template_uri( rules, sys_conf, otree, ntree, path, begin, changed )
--	if not rules then return "cb2_template_uri" end
--
--	if begin then
--		dbg( "begin")
--		return
--	end
--	
--	dbg ("end start")
--	
--	local oslv = ctree.get_path_val(otree,path:match("^/local_slivers/[^/]+/"))
--
--	if oslv.state==NODE.registered and rules==register_rules then
--		if oslv.local_template and oslv.local_template.uri then
--			ctree.set_path_val( otree, path, { uri = oslv.local_template.uri } )
--		else
--			dbg( add_lslv_err( otree, path, "Invalid server template", nil))
--			ctree.set_path_val( otree, path, null )
--		end
--	end
--	
--	dbg ("end end")
--
--end



function cb2_vlan_nr ( rules, sys_conf, otree, ntree, path, begin, changed )
	if not rules then return "cb2_vlan_nr" end
	
	local nval = ctree.get_path_val(ntree,path)
	local oval = ctree.get_path_val(otree,path)
	
	if nval==null or (type((tonumber(nval)))=="number" and tonumber(nval) > 0xFF and tonumber(nval) <= 0xFFF ) then
		if nval~=oval then
			ctree.set_path_val( otree, path, nval )
		end
	else
		dbg( add_lslv_err( otree, path, "Invalid", nval) )
		ctree.set_path_val( otree, path, null )
	end
end



function cb2_lnode_sliver_pub_ipv4_avail (rules, sys_conf, otree, ntree, path)
	if not rules then return "cb2_lnode_sliver_pub_ipv4_avail" end

	local sliver_pub_ipv4_avail = sys_conf.sl_pub_ipv4_total
		
	local slk,slv
	for slk,slv in pairs(sys_conf.uci_slivers) do
		local ifk,ifv
		for ifk,ifv in pairs( tools.str2table(sys_conf.lxc_if_keys,"[%a%d]+") ) do
				
			local itk = "if"..ifv.."_type"
			local itv = sys_conf.uci_slivers[slk][itk] or ""
						
			if itv == "public4" or itv == "public" then
				sliver_pub_ipv4_avail = sliver_pub_ipv4_avail - 1
			end
		end
	end

	if path then
		ctree.set_path_val( otree, path, sliver_pub_ipv4_avail)
	end

	return sliver_pub_ipv4_avail
end



function cb2_interface ( rules, sys_conf, otree, ntree, path, begin, changed )
	if not rules then return "cb2_interface" end
	if not begin then return end
	
	local oslv = ctree.get_path_val(otree,path:match("^/local_slivers/[^/]+/"))
	local nslv = ctree.get_path_val(ntree,path:match("^/local_slivers/[^/]+/"))
	local nval = ctree.get_path_val(ntree,path)
	local oval = ctree.get_path_val(otree,path)
	
	if (rules==register_rules or rules==alloc_rules) and nval then
		
		if nval then
			ctree.set_path_val(otree,path, {})
		else
			ctree.set_path_val(otree,path, nil)
		end
		
		local failure = false
		failure = not crules.chk_or_err( add_lslv_err, otree, ntree, path.."type/", "string", IF_TYPES ) or failure
		failure = not crules.set_or_err( add_lslv_err, otree, ntree, path.."nr/", "number" ) or failure
		
		
		if ( nval.type:match(IF_TYPES.private) or nval.type:match(IF_TYPES.management) or nval.type:match(IF_TYPES.public4) ) and
			(tools.get_table_by_key_val(oslv.interfaces, nval.type, "type") ) then
			
			failure = true
			add_lslv_err( otree, path.."type/", "Only one interface of this type supported", nval.type)
			
		elseif nval.type:match(IF_TYPES.public4) and rules==alloc_rules and cb2_lnode_sliver_pub_ipv4_avail(rules, sys_conf, otree) < 1 then
			
			failure = true
			add_lslv_err( otree, path.."type/", "No available public ipv4 address", nval.type)
			
		else
			ctree.set_path_val(otree,path.."type/", nval.type)
		end
		
		
		if type(nval.name)~="string" or not nval.name:match("^[%a]+[^%c%s]*$") then
			failure = true
			add_lslv_err( otree, path.."name/", "Invalid", nval.name)
		elseif tools.get_table_by_key_val(oslv.interfaces, nval.name, "name") then
			failure = true
			add_lslv_err( otree, path.."name/", "Already used for other interface", nval.name)
		else
			ctree.set_path_val(otree,path.."name/", nval.name)
		end
		
		
		if nval.parent_name==null and not nval.type:match(IF_TYPES.isolated) then
			
			ctree.set_path_val(otree,path.."parent_name/", nval.parent_name)
			
		elseif type(nval.parent_name)=="string" and nval.type:match(IF_TYPES.isolated) then
			
			if not tools.get_table_by_key_val(otree.direct_ifaces, nval.parent_name) then
				failure = true
				add_lslv_err( otree, path.."parent_name/", "Not included in direct_ifaces", nval.parent_name)
				
			elseif tools.get_table_by_key_val(oslv.interfaces, nval.parent_name, "parent_name") then
				failure = true
				add_lslv_err( otree, path.."parent_name/", "Already used for other isolated interface", nval.parent_name)
			end
			
			if type(oslv.local_slice.vlan_nr)~="number" and rules==alloc_rules then
				failure = true
				add_lslv_err( otree, path.."type/", "No vlan_nr defined", nval.type)
			end
			
			if not failure then
				ctree.set_path_val(otree,path.."parent_name/", nval.parent_name)
			end
		else
			failure = true
			add_lslv_err( otree, path.."parent_name/", "Invalid", nval.parent_name )
		end

		ctree.set_path_val(otree, path.."ipv4_addr/", nval.ipv4_addr or null)
		ctree.set_path_val(otree, path.."ipv6_addr/", nval.ipv6_addr or null)
		ctree.set_path_val(otree, path.."mac_addr/", nval.mac_addr or null)

		if failure then
			ctree.set_path_val( otree, path, nil )
		end		
	end
end


function purge_templates( sys_conf, otree )
	
	local disk_avail_old = sys_conf.disk_avail
	
	if sys_conf.disk_avail < sys_conf.disk_max_per_sliver then
		local k,file
		for k,file in pairs(luci.fs.dir(sys_conf.sliver_template_dir)) do
			if not file:match("^%.") then
				local hash = file:gsub("\.tgz$",""):gsub("\.dir$","")
				local found = tools.is_table_value( sys_conf.uci_slivers, hash ) or tools.is_table_value( otree, hash )
				if found then
					dbg("keeping used  data=%s path=%s", sys_conf.sliver_template_dir..file, found)
				else
					dbg("PURGING stale data=%s", sys_conf.sliver_template_dir..file)
					nixio.fs.remover( sys_conf.sliver_template_dir..file )
				end
			end
		end
	end
	
	csystem.get_system_conf( sys_conf )

	dbg("disk_max_per_sliver=%d disk_avail: %d -> %d ", sys_conf.disk_max_per_sliver, disk_avail_old, sys_conf.disk_avail)
end


function cb2_disk_mb ( rules, sys_conf, otree, ntree, path, begin, changed )
	if not rules then return "cb2_disk_mb" end
	
	local nval = ctree.get_path_val(ntree,path)
	local oval = ctree.get_path_val(otree,path)
	
	if nval==nil or nval==null then
		nval = ctree.get_path_val(ntree, (path:match("^/local_slivers/[^/]+/").."local_slice/disk") )
	end

	if nval==nil or nval==null then
		nval = sys_conf.disk_dflt_per_sliver
	end
	
	if type(nval)~="number" or nval < 1 or nval > sys_conf.disk_max_per_sliver  then
		
		dbg( add_lslv_err( otree, path, "Invalid", nval) )
		nval = sys_conf.disk_dflt_per_sliver
		
	elseif (rules==alloc_rules or rules==deploy_rules) and nval >= sys_conf.disk_avail then
		
		dbg( add_lslv_err( otree, path, "Exceeded available disk space for slivers", nval) )
	end
	
	if nval~=oval then
		ctree.set_path_val( otree, path, nval )
	end	
end


function cb2_template( rules, sys_conf, otree, ntree, path, begin, changed )
	if not rules then return "cb2_template" end
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
			local id = ((nval.uri:match("/[%d]+$")):gsub("/",""))
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

		tools.mkdirr( sys_conf.sliver_template_dir )
		
		local uri = oval.image_uri
		local sha = oval.image_sha256
		local dst = sys_conf.sliver_template_dir..sha
		
		if nixio.fs.stat(dst) then
			if ssl.dgst_sha256(dst) ~= sha then
				dbg( "file=%s does not match given sha256 digest!", dst)
				nixio.fs.remover( dst )
			else
				nixio.fs.symlink( dst, dst..".tgz" )
			end
		end
		
		if not nixio.fs.stat(dst) then
			--TODO: check for sys_conf.sliver_template_dir size limit and remove unused files and links
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

function cb2_sha_data( rules, sys_conf, otree, ntree, path, begin, changed )
	if not rules then return "cb2_sha_data" end
	if not begin then return end

	local nval = ctree.get_path_val(ntree,path)
	local oval = ctree.get_path_val(otree,path)
	
	if rules==register_rules and nval then
		
		if not oval then ctree.set_path_val(otree,path,{}) end
		
		local failure = false
		
		failure = not crules.set_or_err( add_lslv_err, otree, ntree, path.."uri/", nil, {null, "^https?://.*%.tgz$", "^https?://.*%.tar%.gz$"} ) or failure	
		failure = not crules.set_or_err( add_lslv_err, otree, ntree, path.."sha256/", nil, {null, "^[%x]+$"} ) or failure
		
		if failure then
			ctree.set_path_val( otree, path, nil )
		end		
		
	elseif rules==alloc_rules and oval then
		
		local uri = ctree.get_path_val(otree,path.."uri/")
		local sha = ctree.get_path_val(otree,path.."sha256/")
		
		if type(uri)~="string" or type(sha)~="string" then
			dbg( "missing path=%s uri=%s or sha256=%s", path, cdata.val2string(uri), cdata.val2string(sha) )
			return
		end

		local dst = sys_conf.sliver_template_dir..sha
		
		tools.mkdirr( sys_conf.sliver_template_dir )
		
		if nixio.fs.stat(dst) then
			if ssl.dgst_sha256(dst) ~= sha then
				dbg( "file=%s does not match given sha256 digest!", dst)
				nixio.fs.remover( dst )
			else
				nixio.fs.symlink( dst, dst..".tgz" )
			end
		end
		
		if not nixio.fs.stat(dst) then
			--TODO: check for sys_conf.sliver_template_dir size limit and remove unused files
			if cdata.http_get_raw(uri, dst) then
				if ssl.dgst_sha256(dst) ~= sha then
					nixio.fs.remover( dst )
					dbg( add_lslv_err(otree, path, "Incorrect sha256=%s for uri=%s" %{sha,uri}, uri) )
				else
					nixio.fs.symlink( dst, dst..".tgz" )
				end
			else
				dbg( add_lslv_err(otree, path, "Inaccessible uri=%s" %{uri}, uri) )
			end
		end
	end
end


function cb2_lsliver_lgroup_role( rules, sys_conf, otree, ntree, path, begin, changed )
	if not rules then return "cb2_lsliver_lgroup_role" end
	
	local oslv = ctree.get_path_val(otree,path:match("^/local_slivers/[^/]+/"))
	
	return ssh.sys_set__lgroup_role( sys_conf.sliver_system_dir..("%.2x"%{oslv.nr})..SLIVER_AUTH_FILES[oslv.local_template.type], false, otree, ntree, path, begin, changed )
end


local tmp_rules

tmp_rules = register_rules

	table.insert(tmp_rules, {"/local_slivers/*/set_state",				cb2_set_state})
	table.insert(tmp_rules, {"/local_slivers/*/uri_id",				crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/uri",				cb2_sliver_uri})
	table.insert(tmp_rules, {"/local_slivers/*/instance_sn",			cb2_instance_sn})
	table.insert(tmp_rules, {"/local_slivers/*/nr",					crules.cb2_set_null})
	table.insert(tmp_rules, {"/local_slivers/*/node",				crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/node/uri",				cb2_node_uri})
	table.insert(tmp_rules, {"/local_slivers/*/description",			crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/properties",				crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/properties/*",			crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/properties/*/*",			crules.cb2_set})

	table.insert(tmp_rules, {"/local_slivers/*/local_slice",			crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/local_slice/instance_sn",		cb2_instance_sn})
	table.insert(tmp_rules, {"/local_slivers/*/local_slice/name",			crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/local_slice/description",		crules.cb2_set})
	
	table.insert(tmp_rules, {"/local_slivers/*/disk",				cb2_disk_mb})
	
	table.insert(tmp_rules, {"/local_slivers/*/interfaces",				crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/interfaces/*",			cb2_interface})
	
	table.insert(tmp_rules, {"/local_slivers/*/local_template",			cb2_template})
--	table.insert(tmp_rules, {"/local_slivers/*/local_template/uri",			crules.cb2_log}) --handled by cb2_template
--	table.insert(tmp_rules, {"/local_slivers/*/local_template/name",		crules.cb2_log}) --handled by cb2_template
--	table.insert(tmp_rules, {"/local_slivers/*/local_template/description",		crules.cb2_log}) --handled by cb2_template
--	table.insert(tmp_rules, {"/local_slivers/*/local_template/type",		crules.cb2_log}) --handled by cb2_template
--	table.insert(tmp_rules, {"/local_slivers/*/local_template/node_archs",		crules.cb2_log}) --handled by cb2_template
--	table.insert(tmp_rules, {"/local_slivers/*/local_template/node_archs/*",	crules.cb2_log}) --handled by cb2_template
--	table.insert(tmp_rules, {"/local_slivers/*/local_template/is_active",		crules.cb2_log}) --handled by cb2_template
--	table.insert(tmp_rules, {"/local_slivers/*/local_template/image_uri",		crules.cb2_log}) --handled by cb2_template
--	table.insert(tmp_rules, {"/local_slivers/*/local_template/image_sha256",	crules.cb2_log}) --handled by cb2_template
	table.insert(tmp_rules, {"/local_slivers/*/template",				crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/template/uri",			crules.cb2_set})

	table.insert(tmp_rules, {"/local_slivers/*/exp_data_uri",			crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/exp_data_sha256",			crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/local_exp_data",			cb2_sha_data})

	table.insert(tmp_rules, {"/local_slivers/*/overlay_uri",			crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/overlay_sha256",			crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/local_overlay",			cb2_sha_data})

	table.insert(tmp_rules, {"/local_slivers/*/slice",				crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/slice/uri",				crules.cb2_set})


tmp_rules = alloc_rules
	table.insert(tmp_rules, {"/local_slivers/*/set_state",				cb2_set_state})
	table.insert(tmp_rules, {"/local_slivers/*/uri_id",				crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/uri",				cb2_sliver_uri})
	table.insert(tmp_rules, {"/local_slivers/*/nr",					crules.cb2_set_null})
	table.insert(tmp_rules, {"/local_slivers/*/description",			crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/properties",				crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/properties/*",			crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/properties/*/*",			crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/local_slice",			crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/local_slice/instance_sn",		cb2_instance_sn})
	table.insert(tmp_rules, {"/local_slivers/*/local_slice/vlan_nr",		cb2_vlan_nr})
	table.insert(tmp_rules, {"/local_slivers/*/disk",				cb2_disk_mb})
	table.insert(tmp_rules, {"/local_slivers/*/interfaces",				crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/interfaces/*",			cb2_interface})
	table.insert(tmp_rules, {"/local_slivers/*/local_template",			cb2_template})
	table.insert(tmp_rules, {"/local_slivers/*/local_exp_data",			cb2_sha_data})
	table.insert(tmp_rules, {"/local_slivers/*/local_overlay",			cb2_sha_data})

tmp_rules = dealloc_rules
	table.insert(tmp_rules, {"/local_slivers/*/set_state",				cb2_set_state})
--	table.insert(tmp_rules, {"/local_slivers/*/uri_id",				crules.cb2_set})
--	table.insert(tmp_rules, {"/local_slivers/*/uri",				cb2_sliver_uri})
	table.insert(tmp_rules, {"/local_slivers/*/nr",					crules.cb2_set_null})

tmp_rules = deploy_rules
	table.insert(tmp_rules, {"/local_slivers/*/set_state",				cb2_set_state})
	table.insert(tmp_rules, {"/local_slivers/*/uri_id",				crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/uri",				cb2_sliver_uri})
	table.insert(tmp_rules, {"/local_slivers/*/nr",					crules.cb2_nop})
	table.insert(tmp_rules, {"/local_slivers/*/description",			crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/properties",				crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/properties/*",			crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/properties/*/*",			crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/disk",				cb2_disk_mb})

tmp_rules = deployed_rules
	table.insert(tmp_rules, {"/local_slivers/*/set_state",				cb2_set_state})
	table.insert(tmp_rules, {"/local_slivers/*/uri_id",				crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/uri",				cb2_sliver_uri})
	table.insert(tmp_rules, {"/local_slivers/*/nr",					crules.cb2_nop})
	table.insert(tmp_rules, {"/local_slivers/*/description",			crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/properties",				crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/properties/*",			crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/properties/*/*",			crules.cb2_set})

tmp_rules = undeploy_rules
	table.insert(tmp_rules, {"/local_slivers/*/set_state",				cb2_set_state})
--	table.insert(tmp_rules, {"/local_slivers/*/uri_id",				crules.cb2_set})
--	table.insert(tmp_rules, {"/local_slivers/*/uri",				cb2_sliver_uri})
	table.insert(tmp_rules, {"/local_slivers/*/nr",					crules.cb2_nop})
	table.insert(tmp_rules, {"/local_slivers/*/local_slice",			crules.cb2_nop})
	table.insert(tmp_rules, {"/local_slivers/*/local_slice/instance_sn",		cb2_instance_sn})

tmp_rules = start_rules
	table.insert(tmp_rules, {"/local_slivers/*/set_state",				cb2_set_state})
	table.insert(tmp_rules, {"/local_slivers/*/uri_id",				crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/uri",				cb2_sliver_uri})
	table.insert(tmp_rules, {"/local_slivers/*/nr",					crules.cb2_nop})
	table.insert(tmp_rules, {"/local_slivers/*/description",			crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/properties",				crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/properties/*",			crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/properties/*/*",			crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/local_slice",			crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/local_slice/local_group",			crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/local_slice/local_group/user_roles",		crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/local_slice/local_group/user_roles/*",				cb2_lsliver_lgroup_role})
	table.insert(tmp_rules, {"/local_slivers/*/local_slice/local_group/user_roles/*/is_slice_admin",		crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/local_slice/local_group/user_roles/*/is_group_admin",		crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/local_slice/local_group/user_roles/*/local_user", 	   		crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/local_slice/local_group/user_roles/*/local_user/is_active",		crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/local_slice/local_group/user_roles/*/local_user/auth_tokens",	crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/local_slice/local_group/user_roles/*/local_user/auth_tokens/*",	crules.cb2_set})
	
	

tmp_rules = stop_rules
	table.insert(tmp_rules, {"/local_slivers/*/set_state",				cb2_set_state})
--	table.insert(tmp_rules, {"/local_slivers/*/uri_id",				crules.cb2_set})
--	table.insert(tmp_rules, {"/local_slivers/*/uri",				cb2_sliver_uri})
	table.insert(tmp_rules, {"/local_slivers/*/nr",					crules.cb2_nop})
	table.insert(tmp_rules, {"/local_slivers/*/local_slice",			crules.cb2_nop})
	table.insert(tmp_rules, {"/local_slivers/*/local_slice/local_group",		crules.cb2_set})
	table.insert(tmp_rules, {"/local_slivers/*/local_slice/local_group/user_roles",	crules.cb2_set_empty_table})	



local function sys_get_lsliver( sys_conf, otree, sk )

	local sv = sys_conf.uci_slivers[sk]
	
	--ctree.dump(sys_conf.uci_slivers)
	
	assert(type(otree.local_slivers)=="table")
	
	if type(sk)=="string" and sk:match(UCI_SLIVER_MATCH) and type(sv)=="table" and sv[".type"]=="sliver" and sv.api=="confine" then
		
		if
			sv.exp_name and
			sv.state and
			sv.fs_template_url and
			sv.fs_template_type and
			sv.sliver_nr and
			sv.if00_type=="private" and
			sv.if00_name and
			sv.api_instance_sn and
			sv.api_slice_instance_sn and
			sv.api_tmpl_id and
			sv.api_tmpl_image_sha256 and
			sv.api_tmpl_image_uri and
			sv.api_tmpl_name and
			sv.api_tmpl_node_archs and
			sv.api_slice_uri and
			true then
			
			local id = tostring(tonumber(sk, 16))
			local slv = otree.local_slivers[id] or {}
			
			slv.nr = tonumber(sv.sliver_nr, 16)
			slv.instance_sn = tonumber(sv.api_instance_sn)
			slv.disk = tonumber(sv.disk_mb) or sys_conf.disk_dflt_per_sliver
			
			slv.local_slice = slv.local_slice or {}
			slv.local_slice.name = sv.exp_name
			slv.local_slice.instance_sn = tonumber(sv.api_slice_instance_sn)
			slv.local_slice.vlan_nr = sv.vlan_nr and tonumber(sv.vlan_nr, 16) or null

			-- sys_get_lsliver_lslice_lgroup()
			-- slv.local_slice.local_group  = ssh.sys_get__lgroup( sys_conf.sliver_system_dir..sv.sliver_nr..SLIVER_AUTH_FILES[sv.fs_template_type], false)
			
			-- sys_get_lsliver_ltemplate()
			slv.local_template = slv.local_template or {}
			slv.local_template.id = sv.api_tmpl_id
			slv.local_template.image_sha256 = sv.api_tmpl_image_sha256
			slv.local_template.image_uri = sv.api_tmpl_image_uri
			slv.local_template.is_active = true
			slv.local_template.name = sv.api_tmpl_name
			slv.local_template.node_archs = ctree.copy_recursive_rebase_keys(tools.str2table(sv.api_tmpl_node_archs,"[^ ]+"), "node_archs" )
			slv.local_template.type = sv.fs_template_type
			slv.local_template.uri = sys_conf.node_base_uri.."/templates/"..sv.api_tmpl_id

			slv.local_exp_data = (sv.api_exp_data_uri and sv.api_exp_data_sha256) and
						{uri=sv.api_exp_data_uri, sha256=sv.api_exp_data_sha256} or
						{uri=null, sha256=null}
			
			slv.local_overlay = (sv.api_overlay_uri and sv.api_overlay_sha256) and
						{uri=sv.api_overlay_uri, sha256=sv.api_overlay_sha256} or
						{uri=null, sha256=null}
						
			-- sys_get_lsliver_interfaces()
			slv.interfaces = {}
			local ifk,ifv
			for ifk,ifv in pairs( tools.str2table(sys_conf.lxc_if_keys,"[%a%d]+") ) do
				if sv["if%s_type"%ifv] then
					slv.interfaces[tostring( (tonumber(ifv, 16)) )] = {
						nr          = tonumber(ifv, 16),
						type        = sv["if%s_type"%ifv],
						name        = sv["if%s_name"%ifv],
						parent_name = sv["if%s_parent"%ifv] or null,
						mac_addr    = sv["if%s_mac"%ifv],
						ipv4_addr   = sv["if%s_ipv4"%ifv] and sv["if%s_ipv4"%ifv]:gsub("/[%d]+$","") or null,
						ipv6_addr   = sv["if%s_ipv6"%ifv] and sv["if%s_ipv6"%ifv]:gsub("/[%d]+$","") or null
					}
				end
			end		
			
			
			slv.node = { uri = sys_conf.node_base_uri.."/node" }
			slv.slice = { uri = sv.api_slice_uri }
			slv.state = sv.state
			slv.template = { uri = slv.local_template.uri}
			
			otree.local_slivers[id] = slv
		else
			dbg("WARNING: corrupted uci_sliver=%s",sk)
			assert((tools.execute( SLV_REMOVE_BIN .. " " .. sk ) == 0), "Failed removing corrupted uci_sliver=%s %s",sk, ctree.as_string(sv) )
			sys_conf.uci_slivers[sk] = nil
		end
	else
		dbg("WARNING: confine RestAPI incompatible uci_sliver=%s",sk)
	end	
end


function sys_get_lslivers( sys_conf, otree )
	
	--dbg("-------------------")
	--ctree.dump( sys_conf.uci_slivers )
	--dbg("-------------------")
	
	otree.local_slivers = otree.local_slivers or {}

	local sk
	for sk in pairs(sys_conf.uci_slivers) do
		sys_get_lsliver( sys_conf, otree, sk)
	end
	
	assert(type(otree.local_slivers)=="table")
	
	return otree.local_slivers
end



function remove_slivers( sys_conf, otree, slv_key, next_state)
	
	assert(not next_state or next_state==NODE.registered)
	
	if slv_key then
		
		local uci_key = "%.12x" %tonumber(slv_key)
		assert((tools.execute( SLV_REMOVE_BIN.." "..uci_key )==0), "Failed removing uci_sliver=%s", uci_key )
		sys_conf.uci_slivers[uci_key] = nil
		
		if next_state then
			dbg("only uci_sliver=%s" %tostring(slv_key))
			--local k,v
			--for k,v in pairs(otree.local_slivers[slv_key]) do
			--	otree.local_slivers[slv_key][k] = nil
			--end
			otree.local_slivers[slv_key].state = next_state
		else
			dbg("sliver=%s" %tostring(slv_key))
			otree.local_slivers[slv_key] = nil
		end
		
		csystem.get_system_conf( sys_conf )
		sys_get_lslivers( sys_conf, otree, uci_key )
		
	else
		
		dbg("removing all")
		assert((tools.execute( SLV_REMOVE_BIN.." all" )==0), "Failed removing all slivers" )
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
		dbg( "next_state=%s lslivers=%s", tostring(next_state), ctree.as_string(otree.local_slivers) )
		return true
		
	elseif next_state==NODE.registered then
		
		remove_slivers( sys_conf, otree, slv_key, NODE.registered )
		dbg( "next_state=%s lslivers=%s", tostring(next_state), ctree.as_string(otree.local_slivers) )
		return true
	
	elseif next_state==NODE.allocated and uci_state==NODE.allocated then
		if tools.execute( SLV_UNDEPLOY_BIN.." "..uci_key )==0 then
			local sliver_opts = {
				api_slice_instance_sn = api_slv.local_slice.instance_sn,
			}
			csystem.set_system_conf( sys_conf, "uci_sliver", sliver_opts, uci_key)
			sys_get_lsliver( sys_conf, otree, uci_key )
			dbg( "next_state=%s lslivers=%s", tostring(next_state), ctree.as_string(otree.local_slivers) )
			return true
		end
	
	elseif next_state==NODE.allocated and uci_state==nil then
		
		local sliver_desc = "config sliver '%s'\n" %uci_key
		sliver_desc = sliver_desc.."	option fs_template_url 'file://%s%s'\n" %{sys_conf.sliver_template_dir,api_slv.local_template.image_sha256..".tgz"}
		sliver_desc = sliver_desc.."	option fs_template_type '%s'\n" %{api_slv.local_template.type}
		sliver_desc = sliver_desc.."	option exp_name '%s'\n" %{api_slv.local_slice.name:gsub("\n","")}
		sliver_desc = sliver_desc.."	option disk_mb '%s'\n" %{tools.min(api_slv.disk or api_slv.local_slice.disk or sys_conf.disk_dflt_per_sliver, sys_conf.disk_max_per_sliver)}
		
		if type(api_slv.local_exp_data.sha256)=="string" then
			sliver_desc = sliver_desc.."	option exp_data_url 'file://%s%s'\n" %{sys_conf.sliver_template_dir,api_slv.local_exp_data.sha256..".tgz"}
		end
		
		if type(api_slv.local_overlay.sha256)=="string" then
			sliver_desc = sliver_desc.."	option overlay_url 'file://%s%s'\n" %{sys_conf.sliver_template_dir,api_slv.local_overlay.sha256..".tgz"}
		end

		if type(api_slv.local_slice.vlan_nr)=="number" then
			sliver_desc = sliver_desc.."	option vlan_nr '%.3x'\n" %{api_slv.local_slice.vlan_nr}
		end
		
		local if_keys = tools.str2table(sys_conf.lxc_if_keys,"[%a%d]+")
		--ctree.dump (if_keys )
		local ifk,ifv
		for ifk,ifv in pairs( if_keys ) do
			local i = api_slv.interfaces[tostring( (tonumber(ifv, 16)) )]
			
			dbg("ifk=%s ifv=%s i=%s type=%s name=%s parent=%s",
			    tostring(ifk),tostring(ifv),tostring(i),tostring((i or {}).type),tostring((i or {}).name),tostring((i or {}).parent_name))
			
			if type(i)=="table" and type(i.type)=="string" and type(i.name)=="string" then
				
				sliver_desc = sliver_desc.."	option if%s_type '%s'\n" %{ifv, i.type}
				sliver_desc = sliver_desc.."	option if%s_name '%s'\n" %{ifv, i.name}
				if type(i.parent_name)=="string" then
					sliver_desc = sliver_desc.."	option if%s_parent '%s'\n" %{ifv, i.parent_name}
				end
				
			else
				break
			end
		end		
		
		
		if tools.execute( SLV_ALLOCATE_BIN.." "..uci_key.." <<EOF\n "..(sliver_desc:gsub("EOF","")).."EOF\n" )==0 then
		
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
				api_exp_data_uri = type(api_slv.local_exp_data.uri)=="string" and api_slv.local_exp_data.uri or nil,
				api_exp_data_sha256 = type(api_slv.local_exp_data.sha256)=="string" and api_slv.local_exp_data.sha256 or nil,
				api_overlay_uri = type(api_slv.local_overlay.uri)=="string" and api_slv.local_overlay.uri or nil,
				api_overlay_sha256 = type(api_slv.local_overlay.sha256)=="string" and api_slv.local_overlay.sha256 or nil
			}
			csystem.set_system_conf( sys_conf, "uci_sliver", sliver_opts, uci_key)
			sys_get_lsliver( sys_conf, otree, uci_key )
			dbg( "next_state=%s lslivers=%s", tostring(next_state), ctree.as_string(otree.local_slivers) )
			return true
		end			
		
	elseif next_state==NODE.allocated and uci_state==NODE.deployed then
		
		if tools.execute( SLV_UNDEPLOY_BIN.." "..uci_key )==0 then
			
			local sliver_opts = {
				api_slice_instance_sn = api_slv.local_slice.instance_sn,
			}
			csystem.set_system_conf( sys_conf, "uci_sliver", sliver_opts, uci_key)
			sys_get_lsliver( sys_conf, otree, uci_key )
			dbg( "next_state=%s lslivers=%s", tostring(next_state), ctree.as_string(otree.local_slivers) )
			return true
		end
		
	elseif next_state==NODE.fail_allocate and uci_state==nil then
		api_slv.state = next_state
		return true
	
	
	elseif next_state==NODE.deployed and uci_state==NODE.deployed then
		if tools.execute( SLV_STOP_BIN.." "..uci_key )==0 then
			csystem.get_system_conf( sys_conf )
			sys_get_lsliver( sys_conf, otree, uci_key )
			dbg( "next_state=%s lslivers=%s", tostring(next_state), ctree.as_string(otree.local_slivers) )
			return true
		end
		
	elseif next_state==NODE.deployed and uci_state==NODE.allocated then
		
		local sliver_desc = "config sliver '%s_%.4x'\n" %{uci_key,sys_conf.id}
		if tools.execute( SLV_DEPLOY_BIN.." "..uci_key.." <<EOF\n "..(sliver_desc:gsub("EOF","")).."EOF\n" )==0 then
			csystem.get_system_conf( sys_conf )
			sys_get_lsliver( sys_conf, otree, uci_key )
			dbg( "next_state=%s lslivers=%s", tostring(next_state), ctree.as_string(otree.local_slivers) )
			return true
		end
		
	elseif next_state==NODE.deployed and uci_state==NODE.started then
		
		if tools.execute( SLV_STOP_BIN.." "..uci_key )==0 then
			csystem.get_system_conf( sys_conf )
			sys_get_lsliver( sys_conf, otree, uci_key )
			dbg( "next_state=%s lslivers=%s", tostring(next_state), ctree.as_string(otree.local_slivers) )
			return true
		end
		
	elseif next_state==NODE.fail_deploy and uci_state==NODE.allocated then
		api_slv.state = next_state
		return true


	elseif next_state==NODE.started and uci_state==NODE.started then
		api_slv.state = next_state
		return true
		
	elseif next_state==NODE.started and uci_state==NODE.deployed then
		
		if tools.execute( SLV_START_BIN.." "..uci_key )==0 then
			csystem.get_system_conf( sys_conf )
			sys_get_lsliver( sys_conf, otree, uci_key )
			dbg( "next_state=%s lslivers=%s", tostring(next_state), ctree.as_string(otree.local_slivers) )
			return true
		end
		
	elseif next_state==NODE.fail_start and uci_state==NODE.deployed then
		api_slv.state = next_state
		return true
	end

	err( "next_state=%s slivers=%s", tostring(next_state), ctree.as_string(otree.local_slivers))
		
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
	
	if start_state and start_state~=oslv.state then
		if not sys_set_lsliver_state( a.sys_conf, a.otree, key, start_state ) then
			remove_slivers( a.sys_conf, a.otree, key, nil)
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
			remove_slivers( a.sys_conf, a.otree, key, nil)
			return false
		end

	elseif success_state~=oslv.state then
		if not sys_set_lsliver_state( a.sys_conf, a.otree, key, success_state ) then
			dbg( add_lslv_err(a.otree, a.path, "Failed state transition"))
			assert( error_state )
			if not sys_set_lsliver_state( a.sys_conf, a.otree, key, error_state ) then
				remove_slivers( a.sys_conf, a.otree, key, nil)
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
	
	--ctree.dump(otree.local_slivers[key] or {})

	if ntree.local_slivers[key] or otree.local_slivers[key] then
	
		local i,imax = 1,10
		local prev_state = nil
		local nslv = ntree.local_slivers[key]
		local oslv = otree.local_slivers[key] or ctree.set_path_val(otree, "/local_slivers/"..key, {state=NODE.registered })
		oslv.errors = nil
		
		local nslv_set_state =
			  (nslv and  nslv.local_slice and nslv.local_slice.set_state ~= null and (
				not nslv.set_state or
				nslv.set_state==null or
				nslv.local_slice.set_state==SERVER.register or
				(nslv.local_slice.set_state==SERVER.deploy and nslv.set_state==SERVER.start) ) and 
			   nslv.local_slice.set_state)
			or
			  (nslv and nslv.set_state)
			or
			  nil

		local test = false or false or nil
		assert( test==nil)
		
		while (oslv.state~=prev_state) do
			
			dbg("processing i=%s sliver=%s node_state=%s server_sliver_state=%s node_sliver_state=%s err=%s",
				i, key, otree.state, tostring(nslv_set_state), tostring(oslv.state), ctree.as_string(oslv.errors) )
			
			prev_state = oslv.state
			
			assert( (ntree.local_slivers[key] or otree.local_slivers[key]) and nslv==ntree.local_slivers[key] and oslv==otree.local_slivers[key] )
			assert( i <= imax )

			if (oslv.state==NODE.registered or (oslv.state==NODE.fail_allocate and i==1) or not NODE[oslv.state]) then
				
				oslv = ctree.set_path_val(otree, "/local_slivers/"..key, {state=NODE.registered })
				
				if nslv then
					if not slv_iterate( iargs, register_rules, NODE.registered, NODE.registered, NODE.registered) then break end
				end
				
				if not oslv.errors and (nslv_set_state==SERVER.deploy or nslv_set_state==SERVER.start) then
					
					if not slv_iterate( iargs, alloc_rules, NODE.registered, NODE.allocated, NODE.fail_allocate) then break end
					
					if oslv.errors then
						if not slv_iterate( iargs, dealloc_rules, NODE.fail_allocate, NODE.fail_allocate, NODE.fail_allocate) then break end
					end
					
				elseif not nslv then
					
					if not slv_iterate( iargs, nil, nil, nil, nil ) then break end
					break
				else
					break
				end
	
	
	
			elseif (oslv.state==NODE.allocated or (oslv.state==NODE.fail_deploy and i==1)) and 
				(not nslv or
				 nslv.instance_sn ~= oslv.instance_sn or
				 nslv_set_state==SERVER.register) then
				
				if not slv_iterate( iargs, dealloc_rules, NODE.allocated, NODE.registered, nil) then break end
				
				
			elseif (oslv.state==NODE.allocated or (oslv.state==NODE.fail_deploy and i==1)) and
				(nslv_set_state==SERVER.deploy or nslv_set_state==SERVER.start) then
				
				if not slv_iterate( iargs, deploy_rules, NODE.allocated, NODE.deployed, NODE.fail_deploy) then break end
				
				if oslv.errors then
					if not slv_iterate( iargs, undeploy_rules, NODE.fail_deploy, NODE.fail_deploy, NODE.fail_deploy) then break end
				end

	
	
			elseif (oslv.state==NODE.deployed or (oslv.state==NODE.fail_start and i==1)) and
				(not nslv or
				 nslv.instance_sn ~= oslv.instance_sn or nslv.local_slice.instance_sn ~= oslv.local_slice.instance_sn or
				 nslv_set_state==SERVER.register) then
				
				if not slv_iterate( iargs, undeploy_rules, NODE.deployed, NODE.allocated, nil) then break end
				
			elseif (oslv.state==NODE.deployed and nslv_set_state==SERVER.deploy) then
				
				if not slv_iterate( iargs, deployed_rules, NODE.deployed, NODE.deployed, nil) then break end
	
			elseif (oslv.state==NODE.deployed or (oslv.state==NODE.fail_start and i==1)) and
				(nslv_set_state==SERVER.start) then
				
				if not slv_iterate( iargs, start_rules, NODE.deployed, NODE.started, NODE.fail_start) then break end
				
				if oslv.errors then
					if not slv_iterate( iargs, stop_rules, NODE.fail_start, NODE.fail_start, NODE.fail_start) then break end
					break
				end
	
	

			elseif (oslv.state==NODE.started) and
				(not nslv or
				 nslv.instance_sn ~= oslv.instance_sn or nslv.local_slice.instance_sn ~= oslv.local_slice.instance_sn or
				 nslv_set_state==SERVER.register or nslv_set_state==SERVER.deploy) then
				
				if not slv_iterate( iargs, stop_rules, NODE.started, NODE.deployed, nil) then break end
				
			elseif (oslv.state==NODE.started and nslv_set_state==SERVER.start) then
				
				if not slv_iterate( iargs, start_rules, NODE.started, NODE.started, nil) then break end


			else
				break
			end
			
			
			i = i + 1
		end

		
		if otree.local_slivers[key] and not otree.local_slivers[key].errors then
			otree.local_slivers[key].errors = {}
		end
		
		dbg("finished   i=%s sliver=%s node_state=%s server_sliver_state=%s node_sliver_state=%s err=%s",
			i, key, otree.state, tostring(nslv_set_state), tostring((otree.local_slivers[key] or {}).state), ctree.as_string((otree.local_slivers[key] or {}).errors) )

	end	

	return true	
end


function cb2_set_slivers( rules, sys_conf, otree, ntree, path, begin, changed )
	if not rules then return "cb2_set_slivers" end
	otree.slivers = {}
	local i,v
	for i,v in pairs(otree.local_slivers) do
		if v.uri_id then
			otree.slivers[v.uri_id]=v
		end
	end
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
	table.insert(tmp_rules, {"/*/properties/*", "iterate"})
	table.insert(tmp_rules, {"/*/properties/*/*"})
	table.insert(tmp_rules, {"/*/instance_sn"})
	table.insert(tmp_rules, {"/*/disk"})
	table.insert(tmp_rules, {"/*/template"})
	table.insert(tmp_rules, {"/*/template/uri"})
	table.insert(tmp_rules, {"/*/exp_data_uri"})
	table.insert(tmp_rules, {"/*/exp_data_sha256"})
	table.insert(tmp_rules, {"/*/overlay_uri"})
	table.insert(tmp_rules, {"/*/overlay_sha256"})
	table.insert(tmp_rules, {"/*/interfaces"})
	table.insert(tmp_rules, {"/*/interfaces/*", "number_p1"})
	table.insert(tmp_rules, {"/*/interfaces/*/nr"})
	table.insert(tmp_rules, {"/*/interfaces/*/name"})
	table.insert(tmp_rules, {"/*/interfaces/*/type"})
	table.insert(tmp_rules, {"/*/interfaces/*/parent_name"}) --FIXME: parent_name (and search for parent)
	table.insert(tmp_rules, {"/*/interfaces/*/mac_addr"})
	table.insert(tmp_rules, {"/*/interfaces/*/ipv4_addr"})
	table.insert(tmp_rules, {"/*/interfaces/*/ipv6_addr"})
	table.insert(tmp_rules, {"/*/nr"})
	table.insert(tmp_rules, {"/*/state"})
	table.insert(tmp_rules, {"/*/set_state"})
	table.insert(tmp_rules, {"/*/errors"})
	table.insert(tmp_rules, {"/*/errors/*", "iterate"})
	table.insert(tmp_rules, {"/*/errors/*/member"})
	table.insert(tmp_rules, {"/*/errors/*/message"})



function get_templates( otree )

	local templates = {}
	local k,v
	if otree.local_slivers then
		for k,lslv in pairs(otree.local_slivers) do
			local id = lslv.local_template and lslv.local_template.id
			if id then
				templates[(tostring(id))] = lslv.local_template
			end
		end
	end
	return templates
end

template_out_filter = {}
tmp_rules = template_out_filter
	table.insert(tmp_rules, {"/*"})
	table.insert(tmp_rules, {"/*/id", nil, "number"})
	table.insert(tmp_rules, {"/*/uri"})
	table.insert(tmp_rules, {"/*/name"})
	table.insert(tmp_rules, {"/*/description"})
	table.insert(tmp_rules, {"/*/type"})
	table.insert(tmp_rules, {"/*/node_archs"})
	table.insert(tmp_rules, {"/*/node_archs/*", "iterate"})
	table.insert(tmp_rules, {"/*/is_active"})
	table.insert(tmp_rules, {"/*/image_uri"})
	table.insert(tmp_rules, {"/*/image_sha256"})
