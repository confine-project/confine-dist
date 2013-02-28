--[[



]]--

--- CONFINE data io library.
module( "confine.uci", package.seeall )

local tools  = require "confine.tools"
local dbg    = tools.dbg

local uci    = require "luci.model.uci".cursor()



local function dirty( config )
	local uci_changes = uci.changes("confine")
	if uci_changes.confine then
		dbg("confine config has uncomiited changes:")
		luci.util.dumptable(uci_changes)
		return true
	end
	return false
end

function set( config, section, option, val)

	assert( not dirty(config), "uci.set config=%s DIRTY when setting option=%s"
	       %{tostring(config), tostring(section).."."..tostring(option).."."..tostring(val)})

	if uci:set( config, section, option, val ) and uci:commit( config ) then
		return true
	else
		return false
	end
end

function get( config, section, option, default )

	assert( not dirty(config), "uci.get config=%s DIRTY when getting option=%s" %{tostring(config), tostring(section).."."..tostring(option)})

	local val = uci:get( config, section, option)
	
	if val == nil and default ~= nil then
		set( config, section, option, default)
		return default
	end
	
	return val
end


function get_all( config, section )

	if dirty( config ) then
		return false
	elseif section then
		return uci:get_all( config, section)
	else
		return uci:get_all( config )
	end
end


--function get_dirty( config, section, option )
--	
--	assert( dirty(config), "uci.get config=%s uncomitted when getting option=%s" %{tostring(config), tostring(section).."."..tostring(option)})
--
--	return uci:get( config, section, option)
--end