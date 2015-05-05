--[[



]]--


--- CONFINE system abstraction library.
module( "confine.system", package.seeall )

local nixio   = require "nixio"
local lsys    = require "luci.sys"
local lutil   = require "luci.util"
local sig     = require "signal"
local uci     = require "confine.uci"
local tools   = require "confine.tools"
local data    = require "confine.data"
local ctree   = require "confine.tree"
local null    = data.null


RUNTIME_DIR = "/var/run/confine/"
PID_FILE = RUNTIME_DIR.."pid"
LOG_FILE = "/var/log/confine.log"
LOG_SIZE = 1000000

NODE_BASE_PATH = "/confine/api"

DFLT_SLIVER_DISK_MAX_MB      = 2000
DFLT_SLIVER_DISK_DFLT_MB     = 1000
DFLT_SLIVER_DISK_RESERVED_MB = 500

DFLT_SLIVER_MEM_MAX_MB      = 2000
DFLT_SLIVER_MEM_DFLT_MB     = 1000


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
	      [--node-base-path==</confine/api>] \\\
	      [--logfile=<path to logfile>] \\\
	      [--logsize=<max-logfile-size-in-bytes>] \\\
	      ")
	os.exit(0)
end


function check_direct_ifaces( ifaces, picky )

	local sys_devices = lsys.net.devices()
	local direct_ifaces = {}
	
	local k,v
	local n=0
	for k,v in pairs(ifaces) do
		local result = os.execute("ip >/dev/null link show dev" .. " " .. tostring(v))
		if type(v)=="string" and result==0 and tools.get_table_by_key_val(sys_devices,v) then
			
			n=n+1
			direct_ifaces[tostring(n)] = v
			
		else
			
			tools.dbg("val=%s Invalid interface prefix or Interface does not exits!", tostring(v))
			if picky then
				return false
			end
		end
	end
	
	return direct_ifaces
end

function get_system_conf(sys_conf, arg)

	if not uci.is_clean("confine") or not uci.is_clean("confine-slivers") then return false end
	
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
	conf.err_cnt		   = conf.err_cnt     or 0
	conf.logfile               = conf.logfile     or flags["logfile"]  or uci.get("confine", "node", "logfile")     or LOG_FILE
	if conf.logfile then tools.logfile = conf.logfile end

	conf.logsize               = conf.logsize     or flags["logsize"]  or uci.get("confine", "node", "logsize")     or LOG_SIZE
	if conf.logsize then tools.logsize = conf.logsize end

	conf.id                    = tonumber((uci.get("confine", "node", "id") or "x"), 16)
	conf.uuid                  = uci.get("confine", "node", "uuid") or null
	
	if not conf.arch then
		
		conf.arch                  = tools.canon_arch(nixio.uname().machine)
		
		local cns_version_file     = io.open("/etc/confine.version", "r")
		if cns_version_file then
			local cns_timestamp        = cns_version_file:read() or "???"
			local cns_branch           = cns_version_file:read() or "???"
			local cns_revision         = cns_version_file:read() or "???"
			conf.sys_revision = cns_branch .. "." .. (cns_revision:sub(1,7))
			cns_version_file:close()
		end
		
		conf.cns_version           = lutil.exec( "opkg info confine-system" )
		conf.cns_version           = type(conf.cns_version) == "string" and conf.cns_version:match("Version: [^\n]+\n") or "???"
		conf.cns_version           = conf.cns_version:gsub("Version: ",""):gsub(" ",""):gsub("\n","")
		conf.soft_version          = (conf.sys_revision or "???.???") .. "-" .. conf.cns_version
		
		local meminfo = nixio.fs.readfile( "/proc/meminfo" ) or "0"
		local ifname = (uci.get("confine", "node", "local_ifname")) or ""
		local ethtool = (lutil.exec('ethtool ' .. ifname)) or ""
		local cpuinfo = nixio.fs.readfile( "/proc/cpuinfo" ) or ""
		local _, cpucount = string.gsub(cpuinfo, "model name", "")
		conf.properties = {
			hw_cpu_model = cpuinfo:match("model name[^%a]+([%a][^\n]+)\n"),
		--	hw_cpu_op_mode = "64-bit",
			hw_cpu_num_cores = tostring(cpucount),
			hw_cpu_speed_MHz = cpuinfo:match("cpu MHz[^%d]+([%d]+)"),
			hw_mem_total_MiB = tostring(math.floor((meminfo:match("([%d]+) kB"))/1024) ),
		--	hw_mem_free_MB = "2058",
		--	hw_eth_model = "82579LM Gigabit Network Connection",
			hw_eth_tx_mode = ethtool:match("Duplex: ([%a]+)"),
		--	hw_eth_capacity_Mbps = "1000",
			hw_eth_speed_Mbps = ethtool:match("Speed: ([%d]+)"),
		--	hw_eth_model = "82579LM Gigabit Network Connection",
		--	hw_disk_total_GB = "210",
		--	hw_disk_free_GB = "73"
		}
	end

	conf.node_pubkey_file      = "/etc/dropbear/openssh_rsa_host_key.pub" --must match /etc/dropbear/dropbear_rsa_*
--	conf.server_cert_file      = "/etc/confine/keys/server.ca"
	conf.node_cert_file        = "/etc/uhttpd.crt.pem" --must match /etc/uhttpd.crt and /etc/uhttpd.key -- http://wiki.openwrt.org/doc/howto/certificates.overview  http://man.cx/req

	conf.sync_node_admins      = uci.get_bool("confine", "node", "sync_node_admins", true)
	
	conf.local_iface           = uci.get("confine", "node", "local_ifname")

	conf.local_bridge          = lutil.exec( "ip addr show dev br-local" )
	conf.local_bridge          = type(conf.local_bridge)=="string" and conf.local_bridge or ""
	
	conf.internal_bridge       = lutil.exec( "ip addr show dev br-internal" )
	conf.internal_bridge       = type(conf.internal_bridge)=="string" and conf.internal_bridge or ""


	conf.mgmt_ipv6_prefix48    = uci.get("confine", "testbed", "mgmt_ipv6_prefix48")
	conf.mgmt_ipv6_prefix	   = conf.mgmt_ipv6_prefix48.."::/48"

	conf.debug_ipv6_prefix48   = uci.get("confine-defaults", "confine", "debug_ipv6_prefix48")
	conf.debug_ipv6_prefix     = conf.debug_ipv6_prefix48.."::/48"

	conf.priv_ipv6_prefix48    = (uci.get("confine-defaults", "confine", "priv_ipv6_prefix48"))
	conf.priv_ipv6_prefix      = conf.priv_ipv6_prefix48.."::/48"

	conf.priv_ipv4_prefix24    = uci.get("confine", "node", "priv_ipv4_prefix24")
	conf.priv_ipv4_prefix      = conf.priv_ipv4_prefix24..".0/24"


	conf.sliver_mac_prefix     = "0x" .. uci.get("confine", "node", "mac_prefix16"):gsub(":", "")

	conf.addrs                 = {}
	conf.addrs.mgmt            = (conf.mgmt_ipv6_prefix48..(":%x::2"%{conf.id}))
	conf.addrs.mgmt_host       = null
	conf.addrs.local_mac       = (conf.local_bridge:match("[%x][%x]:[%x][%x]:[%x][%x]:[%x][%x]:[%x][%x]:[%x][%x]")) or null
	conf.addrs.debug           = (conf.local_bridge:match(conf.debug_ipv6_prefix48.."[^/]+")) or null
	conf.addrs.internal_ipv4   = (conf.internal_bridge:match(conf.priv_ipv4_prefix24.."[^/]+")) or null
	conf.addrs.internal_ipv6   = (conf.internal_bridge:match(conf.priv_ipv6_prefix48.."[^/]+")) or null
	conf.addrs.recovery_ipv4   = (conf.local_bridge:match(conf.priv_ipv4_prefix24.."[^/]+")) or null
	conf.addrs.recovery_ipv6   = (conf.local_bridge:match(conf.priv_ipv6_prefix48..":1:[^/]+")) or null
	conf.addrs.recovery_unique = (conf.local_bridge:match(conf.priv_ipv6_prefix48..":2:[^/]+")) or null
	conf.addrs.local_ipv4      = ((function()
					local addr
					for addr in conf.local_bridge:gmatch("inet [^\n]+ scope global") do
						addr = addr:match("[%d]+%.[%d]+%.[%d]+%.[%d]+")
						if addr ~= conf.addrs.recovery_ipv4 then
							return addr
						end
					end
				        return null
				     end)())
	conf.addrs.local_ipv6      = ((function()
					local addr
					for addr in conf.local_bridge:gmatch("inet6 [^\n]+ scope global") do
						addr = addr:match("[%x]+:[^/]+")
						if addr ~= conf.addrs.mgmt and addr ~= conf.addrs.debug and addr ~= conf.addrs.recovery_ipv6 and addr ~= conf.addrs.recovery_unique then
							return addr
						end
					end
					return null
				     end)())
	

	conf.node_base_path        = conf.node_base_path or flags["node-base-path"] or uci.get("confine", "node", "base_path") or NODE_BASE_PATH
	assert(conf.node_base_path:match("/api$"), "node-base-path MUST end with /api")
	conf.node_base_uri         = "http://["..conf.mgmt_ipv6_prefix48..":".."%X"%conf.id.."::2]"..conf.node_base_path

	conf.server_base_uri       = (uci.get("confine", "registry", "base_uri") or "http://[" .. conf.mgmt_ipv6_prefix48 .. "::2]/api"):gsub("/$","")
	conf.link_base_rel         = (uci.get("confine", "registry", "link_base_rel")) or "http://confine-project.eu/rel/"
	
	conf.sys_state             = uci.get("confine", "node", "state")
	conf.boot_sn               = tonumber(uci.get("confine", "node", "boot_sn", 0))

	conf.tinc_gateway          = uci.get("confine", "node", "tinc_gateway")
--	conf.tinc_node_key_priv    = "/etc/tinc/confine/rsa_key.priv" -- required
--	conf.tinc_node_key_pub     = "/etc/tinc/confine/rsa_key.pub"  -- created by confine_node_start
	conf.tinc_hosts_dir        = "/etc/tinc/confine/hosts/"       -- required
	conf.tinc_conf_file        = "/etc/tinc/confine/tinc.conf"    -- created by confine_tinc_setup
	conf.tinc_pid_file         = "/var/run/tinc.confine.pid"
	
	conf.ssh_node_auth_file    = "/etc/dropbear/authorized_keys"

	
	conf.sl_pub_ipv4_proto     = uci.get("confine", "node", "sl_public_ipv4_proto")
	conf.sl_pub_ipv4_addrs     = uci.get("confine", "node", "sl_public_ipv4_addrs")
	conf.sl_pub_ipv4_total     = tonumber(uci.get("confine", "node", "public_ipv4_avail"))	

	conf.direct_ifaces = check_direct_ifaces( tools.str2table((uci.get("confine", "node", "rd_if_iso_parents") or ""),"[^%s]+") )

	
	conf.lxc_if_keys           = uci.get("lxc", "general", "lxc_if_keys" )

--	conf.uci = {}
--	conf.uci.confine           = uci.get_all("confine")
	conf.uci_slivers           = uci.get_all("confine-slivers")
	
	conf.sliver_system_dir     = uci.get("lxc", "general", "lxc_images_path").."/"
	
	conf.sliver_template_dir   = uci.get("lxc", "general", "lxc_templates_path").."/"
	
	conf.disk_max_per_sliver   = tonumber(uci.get("confine", "node", "disk_max_per_sliver")  or DFLT_SLIVER_DISK_MAX_MB)
	conf.disk_dflt_per_sliver  = tonumber(uci.get("confine", "node", "disk_dflt_per_sliver") or DFLT_SLIVER_DISK_DFLT_MB)
	conf.disk_reserved         = tonumber(uci.get("confine", "node", "disk_reserved")        or DFLT_SLIVER_DISK_RESERVED_MB)
	conf.disk_avail            = math.floor(tonumber(lutil.exec( "df -P "..conf.sliver_template_dir .."/ | tail -1 | awk '{print $4}'" )) / 1024) - conf.disk_reserved
	
	conf.mem_max_per_sliver   = tonumber(uci.get("confine", "node", "mem_max_per_sliver")  or DFLT_SLIVER_MEM_MAX_MB)
	conf.mem_dflt_per_sliver  = tonumber(uci.get("confine", "node", "mem_dflt_per_sliver") or DFLT_SLIVER_MEM_DFLT_MB)

	data.file_put( conf, system_state_file )

	if conf.sys_state ~= "started" then
		tools.err("Confine system config NOT in state=started (current state=%s)!", conf.sys_state)
		stop()
	end

	return conf
end

function set_system_conf( sys_conf, opt, val, section)
	
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
			stop()
		end
		
		return get_system_conf(sys_conf)
		
	elseif opt == "direct_ifaces" and type(val) == "table" then
		
		local ifaces = check_direct_ifaces( val, true )
		tools.dbg( "iftable="..tools.table2string(ifaces, " ", 1).." ifstr="..tostring(table.concat(ifaces)) )
		if ifaces and uci.set("confine", "node", "rd_if_iso_parents", tools.table2string(ifaces, " ", 1) ) then
			return get_system_conf(sys_conf)
		end
		
	elseif (opt == "disk_max_per_sliver" or opt == "disk_dflt_per_sliver") and
		type(val)=="number" and val <= 10000 and
		uci.set("confine", "node", opt, val) then
		
		return get_system_conf(sys_conf)

	elseif opt=="uci_sliver" and
		type(val)=="table" and type(section)=="string" and
		uci.set_section_opts( "confine-slivers", section, val) then
		
		return get_system_conf(sys_conf)
	--elseif opt == "uci_slivers" and
	--	type(val) == "table" and
	--	uci.set_all( "confine-slivers", val) then
	--	
	--	return get_system_conf(sys_conf)
		
	end
		
	assert(false, "ERR_SETUP: Invalid opt=%s val=%s section=%s" %{opt, tostring(val), tostring(section)})
	
end


