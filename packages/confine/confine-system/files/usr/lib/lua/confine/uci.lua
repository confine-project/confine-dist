--[[



]]--

--- CONFINE data io library.
module( "confine.uci", package.seeall )

local tools  = require "confine.tools"
local dbg    = tools.dbg

local uci    = require "luci.model.uci".cursor()



local function dirty( config )
	local uci_changes = uci.changes( config )
	if uci_changes[config] then
		dbg("config=%s has uncomiited changes:", config )
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

function set_all( config, sections )

	assert( type(config)=="string" and type(sections)=="table" )

	if dirty( config ) then
		return false
	else
		
		local sk,sv
		for sk,sv in pairs( get_all( config ) or {} ) do
			uci:delete( config, sk )
		end
		
		for sk,sv in pairs( sections ) do
			uci:set( config, sk, sv[".type"] )
			local ok,ov
			for ok,ov in pairs( sv ) do
				if type(ok)=="string" and not ok:match("^%.") then
					uci:set( config, sk, ok, ov )
				end
			end
		end
		
		if uci:save( config ) then
			return uci:commit( config )
		else
			uci:revert( config )
			return false
		end
	end
end

--function get_dirty( config, section, option )
--	
--	assert( dirty(config), "uci.get config=%s uncomitted when getting option=%s" %{tostring(config), tostring(section).."."..tostring(option)})
--
--	return uci:get( config, section, option)
--end