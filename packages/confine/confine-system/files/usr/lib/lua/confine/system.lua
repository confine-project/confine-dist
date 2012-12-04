--[[



]]--


--- CONFINE system abstraction library.
module( "confine.system", package.seeall )

local lsys    = require "luci.sys"
local uci     = require "confine.uci"
local tools   = require "confine.tools"
local data    = require "confine.data"
local null    = data.null


function get_system_conf(sys_conf)

	if uci.dirty( "confine" ) then return false end
	
	local conf = sys_conf or {}

	conf.id                    = tonumber((uci.getd("confine", "node", "id") or "x"), 16)
	conf.uuid                  = null
	conf.cert		   = null  -- http://wiki.openwrt.org/doc/howto/certificates.overview  http://man.cx/req
	conf.arch                  = tools.canon_arch(nixio.uname().machine)
	conf.soft_version          = (tools.subfindex( nixio.fs.readfile( "/etc/banner" ) or "???", "show%?branch=", "\n" ) or "???"):gsub("&rev=",".")

	conf.mgmt_ipv6_prefix48    = uci.getd("confine", "testbed", "mgmt_ipv6_prefix48")

	conf.node_base_uri         = "http://["..conf.mgmt_ipv6_prefix48..":".."%X"%conf.id.."::2]/confine/api"
--	conf.server_base_uri       = "https://controller.confine-project.eu/api"
	conf.server_base_uri       = lsys.getenv("SERVER_URI") or "http://["..conf.mgmt_ipv6_prefix48.."::2]/confine/api"
	
	conf.local_iface           = uci.getd("confine", "node", "local_ifname")
	
	conf.sys_state             = uci.getd("confine", "node", "state")
	conf.boot_sn               = tonumber(uci.getd("confine", "node", "boot_sn")) or 0

	conf.node_pubkey_file      = "/etc/dropbear/openssh_rsa_host_key.pub" --must match /etc/dropbear/dropbear_rsa_*
--	conf.server_cert_file      = "/etc/confine/keys/server.ca"
--	conf.node_cert_file        = "/etc/confine/keys/node.crt.pem" --must match /etc/uhttpd.crt and /etc/uhttpd.key

	conf.tinc_node_key_priv    = "/etc/tinc/confine/rsa_key.priv" -- required
	conf.tinc_node_key_pub     = "/etc/tinc/confine/rsa_key.pub"  -- created by confine_node_enable
	conf.tinc_hosts_dir        = "/etc/tinc/confine/hosts/"       -- required
	conf.tinc_conf_file        = "/etc/tinc/confine/tinc.conf"    -- created by confine_tinc_setup
	conf.tinc_pid_file         = "/var/run/tinc.confine.pid"
	
	conf.ssh_node_auth_file    = "/etc/dropbear/authorized_keys"


	
	conf.priv_ipv4_prefix      = uci.getd("confine", "node", "priv_ipv4_prefix24") .. ".0/24"
	conf.sliver_mac_prefix     = "0x" .. uci.getd("confine", "node", "mac_prefix16"):gsub(":", "")
	
	conf.sliver_pub_ipv4       = uci.getd("confine", "node", "sl_public_ipv4_proto")
	conf.sl_pub_ipv4_addrs     = uci.getd("confine", "node", "sl_public_ipv4_addrs")
	conf.sl_pub_ipv4_total     = tonumber(uci.getd("confine", "node", "public_ipv4_avail"))
	

	conf.direct_ifaces         = tools.str2table(uci.getd("confine", "node", "rd_if_iso_parents"),"[%a%d_]+")
	
	conf.lxc_if_keys           = uci.getd("lxc", "general", "lxc_if_keys" )

	conf.uci = {}
--	conf.uci.confine           = uci.get_all("confine")
	conf.uci.slivers           = uci.get_all("confine-slivers")

	return conf
end

function set_system_conf( sys_conf, opt, val)
	
	assert(opt and type(opt)=="string" and val, "set_system_conf()")
	
	if opt == "boot_sn" then
		
		if type(val)~="number" then return false end
		
		uci.set("confine", "node", "boot_sn", val)
		
	elseif opt == "sys_state" then
		
		if val~="prepared" or val~="applied" or val~="failure" then return false end
		
		uci.set("confine", "node", "state", val)
		
	elseif opt == "priv_ipv4_prefix" then
		
		if type(val)~="string" or not val:gsub(".0/24",""):match("[0-255].[0-255].[0-255]") then
			return false
		end
		
		uci.set("confine", "node", "priv_ipv4_prefix24", val:gsub(".0/24","") )
		
	elseif opt == "direct_ifaces" and type(val) == "table" then
		
		local devices = lsys.net.devices()
		
		local k,v
		for k,v in pairs(val) do
			if type(v)~="string" or not (v:match("^eth[%d]+$") or v:match("^wlan[%d]+$")) then
				dbg("set_system_conf() opt=%s val=%s Invalid interface prefix!", opt, tostring(v))
				return false
			end
			
			if not tools.get_table_by_key_val(devices,v) then
				dbg("set_system_conf() opt=%s val=%s Interface does NOT exist on system!",opt,tostring(v))
				return false
			end
		end
		
		uci.set("confine", "node", "rd_if_iso_parents", table.concat( val, " ") )
		
	elseif opt == "sliver_mac_prefix" and type(val) == "string" then
		
		local dec = tonumber(val,16) or 0
		local msb = math.modf(dec / 256)
		local lsb = dec - (msb*256)
		
		if msb > 0 and msb <= 255 and lsb >= 0 and lsb <= 255 then
			local mac = "%.2x:%.2x"%{msb,lsb}
			uci.set("confine","node","mac_prefix16", mac)
		else
			return false
		end

	else
		
		assert(false, "set_system_conf(): Invalid opt=%s val=%s", opt, tostring(val))
	end
	
	return get_system_conf(sys_conf)
end


