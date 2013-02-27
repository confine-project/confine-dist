--[[



]]--


--- CONFINE system abstraction library.
module( "confine.system", package.seeall )

local nixio   = require "nixio"
local lsys    = require "luci.sys"
local sig     = require "signal"
local uci     = require "confine.uci"
local tools   = require "confine.tools"
local data    = require "confine.data"
local null    = data.null


RUNTIME_DIR = "/var/run/confine/"
PID_FILE = RUNTIME_DIR.."pid"
LOG_FILE = "/var/log/confine.log"
LOG_SIZE = 1000000

SERVER_BASE_PATH = "/confine/api"
NODE_BASE_PATH = "/confine/api"

node_state_file     = RUNTIME_DIR.."node_state"
server_state_file   = RUNTIME_DIR.."server_state"
system_state_file   = RUNTIME_DIR.."system_state"

rest_confine_dir    = "/tmp/confine"
rest_base_dir       = rest_confine_dir.."/"
rest_node_dir       = rest_confine_dir.."/node/"
rest_slivers_dir    = rest_confine_dir.."/slivers/"
rest_templates_dir  = rest_confine_dir.."/templates/"

function check_pid()
	tools.mkdirr( RUNTIME_DIR )
	local pid = nixio.fs.readfile( PID_FILE )
	
	if pid and tonumber(pid) and nixio.fs.stat( "/proc/"..pid.."/cmdline" ) then
		tools.err("There already seem a confine deamon running. If not remove %s and retry!", PID_FILE)
		return false
	else
		local out = io.open(PID_FILE, "w")
		assert(out, "Failed to open %s" %PID_FILE)
		out:write( nixio.getpid() )
		out:close()
		return true
	end	
end

function stop(code)
	tools.dbg("Terminating")
	pcall(nixio.fs.remover, rest_confine_dir)
	pcall(nixio.fs.remover, PID_FILE)
	os.exit(code)
--	nixio.kill(nixio.getpid(),sig.SIGKILL)
end

function reboot()
	tools.dbg("rebooting...")
	tools.sleep(2)
	os.execute("reboot")
	stop(0)
end



function help()
	print("usage: /usr/lib/lua/confine/confine.lua  \\\
	      [--debug] \\\
	      [--interactive] \\\
	      [--count=<max iterations>] \\\
	      [--interval=<seconds per iteration>] \\\
	      [--retry==<max failure retries>] \\\
	      [--server-base-path==</confine/api>] \\\
	      [--node-base-path==</confine/api>] \\\
	      [--logfile=<path to logfile>] \\\
	      [--logsize=<max-logfile-size-in-bytes>] \\\
	      ")
	os.exit(0)
end

function get_system_conf(sys_conf, arg)

--	if uci.dirty( "confine" ) then return false end
	
	local conf = sys_conf or {}
	local flags = {}
	
	if arg then
		local trash
		flags,trash = tools.parse_flags(arg)
		assert( not trash, "Illegal flags: ".. tostring(trash) )
	end
	
	if flags["help"] then
		help()
		return
	end
		
	conf.debug          	   = conf.debug       or flags["debug"]              or false
	conf.interactive	   = conf.interactive or flags["interactive"]        or false
	conf.count		   = conf.count       or tonumber(flags["count"])    or 0
	conf.interval 		   = conf.interval    or tonumber(flags["interval"]) or tonumber(uci.get("confine", "node", "interval"))    or 60
	conf.retry_limit           = conf.retry_limit or tonumber(flags["retry"])    or tonumber(uci.get("confine", "node", "retry_limit")) or 0
	conf.logfile               = conf.logfile     or flags["logfile"]  or uci.get("confine", "node", "logfile")     or LOG_FILE
	if conf.logfile then tools.logfile = conf.logfile end

	conf.logsize               = conf.logsize     or flags["logsize"]  or uci.get("confine", "node", "logsize")     or LOG_SIZE
	if conf.logsize then tools.logsize = conf.logsize end

	conf.id                    = tonumber((uci.get("confine", "node", "id") or "x"), 16)
	conf.uuid                  = uci.get("confine", "node", "uuid") or null
	conf.cert		   = null  -- http://wiki.openwrt.org/doc/howto/certificates.overview  http://man.cx/req
	conf.arch                  = tools.canon_arch(nixio.uname().machine)
	conf.soft_version          = (tools.subfindex( nixio.fs.readfile( "/etc/banner" ) or "???", "show%?branch=", "\n" ) or "???"):gsub("&rev=",".")

	conf.mgmt_ipv6_prefix48    = uci.get("confine", "testbed", "mgmt_ipv6_prefix48")
	conf.mgmt_ipv6_prefix	   = conf.mgmt_ipv6_prefix48.."::/48"

	conf.priv_ipv6_prefix      = (uci.get("confine-defaults", "confine", "priv_ipv6_prefix48")).."::/48"
	conf.debug_ipv6_prefix     = (uci.get("confine-defaults", "confine", "debug_ipv6_prefix48")).."::/48"


	conf.node_base_path        = conf.node_base_path or flags["node-base-path"] or uci.get("confine", "node", "base_path") or NODE_BASE_PATH
	assert(conf.node_base_path:match("/api$"), "node-base-path MUST end with /api")
	conf.node_base_uri         = "http://["..conf.mgmt_ipv6_prefix48..":".."%X"%conf.id.."::2]"..conf.node_base_path
--	conf.server_base_uri       = "https://controller.confine-project.eu/api"
	conf.server_base_path      = conf.server_base_path or flags["server-base-path"] or uci.get("confine", "server", "base_path") or SERVER_BASE_PATH
	assert(conf.server_base_path:match("/api$"), "server-base-path MUST end with /api")
	conf.server_base_uri       = lsys.getenv("SERVER_URI") or "http://["..conf.mgmt_ipv6_prefix48.."::2]"..conf.server_base_path
	
	conf.local_iface           = uci.get("confine", "node", "local_ifname")
	
	conf.sys_state             = uci.get("confine", "node", "state")
	conf.boot_sn               = tonumber(uci.get("confine", "node", "boot_sn", 0))

	conf.node_pubkey_file      = "/etc/dropbear/openssh_rsa_host_key.pub" --must match /etc/dropbear/dropbear_rsa_*
--	conf.server_cert_file      = "/etc/confine/keys/server.ca"
--	conf.node_cert_file        = "/etc/confine/keys/node.crt.pem" --must match /etc/uhttpd.crt and /etc/uhttpd.key

	conf.tinc_node_key_priv    = "/etc/tinc/confine/rsa_key.priv" -- required
	conf.tinc_node_key_pub     = "/etc/tinc/confine/rsa_key.pub"  -- created by confine_node_enable
	conf.tinc_hosts_dir        = "/etc/tinc/confine/hosts/"       -- required
	conf.tinc_conf_file        = "/etc/tinc/confine/tinc.conf"    -- created by confine_tinc_setup
	conf.tinc_pid_file         = "/var/run/tinc.confine.pid"
	
	conf.ssh_node_auth_file    = "/etc/dropbear/authorized_keys"


	
	conf.priv_ipv4_prefix      = uci.get("confine", "node", "priv_ipv4_prefix24") .. ".0/24"
	conf.sliver_mac_prefix     = "0x" .. uci.get("confine", "node", "mac_prefix16"):gsub(":", "")
	
	conf.sliver_pub_ipv4       = uci.get("confine", "node", "sl_public_ipv4_proto")
	conf.sl_pub_ipv4_addrs     = uci.get("confine", "node", "sl_public_ipv4_addrs")
	conf.sl_pub_ipv4_total     = tonumber(uci.get("confine", "node", "public_ipv4_avail"))
	

	conf.direct_ifaces         = tools.str2table((uci.get("confine", "node", "rd_if_iso_parents") or ""),"[%a%d_]+")
	
	conf.lxc_if_keys           = uci.get("lxc", "general", "lxc_if_keys" )

	conf.uci = {}
--	conf.uci.confine           = uci.get_all("confine")
	conf.uci.slivers           = uci.get_all("confine-slivers")

	data.file_put( conf, system_state_file )

	return conf
end

function set_system_conf( sys_conf, opt, val)
	
	assert(opt and type(opt)=="string", "set_system_conf()")
	
	if not val then
	
	elseif opt == "boot_sn" and
		type(val)=="number" and 		
		uci.set("confine", "node", opt, val) then
		
		return get_system_conf(sys_conf)
		
	elseif opt == "uuid" and
		type(val)=="string" and not uci.get("confine", "node", opt) and
		uci.set("confine", "node", opt, val) then
		
		return get_system_conf(sys_conf)
		
	elseif opt == "sys_state" and
		(val=="prepared" or val=="applied" or val=="failure") and
		uci.set("confine", "node", "state", val) then
		
		if val=="failure" then
			os.exec()
		end
		
		return get_system_conf(sys_conf)
		

	elseif opt == "priv_ipv4_prefix" and (val==null or val=="") then
		
		return get_system_conf(sys_conf)
		
	elseif opt == "priv_ipv4_prefix" and
		type(val)=="string" and val:gsub(".0/24",""):match("[0-255].[0-255].[0-255]") and
		uci.set("confine", "node", "priv_ipv4_prefix24", val:gsub(".0/24","") ) then
		
		return get_system_conf(sys_conf)


	elseif opt == "direct_ifaces" and type(val) == "table" then
		
		local devices = lsys.net.devices()
	
		local k,v
		for k,v in pairs(val) do
			if type(v)~="string" or not (v:match("^eth[%d]+$") or v:match("^wlan[%d]+$")) then
				tools.dbg("opt=%s val=%s Invalid interface prefix!", opt, tostring(v))
				devices = nil
				break
			end
			
			if not devices or not tools.get_table_by_key_val(devices,v) then
				tools.dbg("opt=%s val=%s Interface does NOT exist on system!",opt,tostring(v))
				devices = nil
				break
			end
		end
		
		if devices and uci.set("confine", "node", "rd_if_iso_parents", table.concat( val, " ") ) then
			return get_system_conf(sys_conf)
		end
		

	elseif opt == "sliver_mac_prefix" and (val==null or val=="") then
		
		return get_system_conf(sys_conf)

	elseif opt == "sliver_mac_prefix" and type(val) == "string" then
		
		local dec = tonumber(val,16) or 0
		local msb = math.modf(dec / 256)
		local lsb = dec - (msb*256)
		
		if msb > 0 and msb <= 255 and lsb >= 0 and lsb <= 255 and
			uci.set("confine","node","mac_prefix16", "%.2x:%.2x"%{msb,lsb}) then
			
			return get_system_conf(sys_conf)
		end
	end
		
	assert(false, "ERR_SETUP: Invalid opt=%s val=%s" %{opt, tostring(val)})
	
end


