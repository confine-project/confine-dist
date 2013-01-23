--[[



]]--

--- CONFINE data io library.
module( "confine.uci", package.seeall )


local uci    = require "luci.model.uci".cursor()



function dirty( config )
	local uci_changes = uci.changes("confine")
	if uci_changes.confine then
		dbg("confine config has uncomiited changes:")
		luci.util.dumptable(uci_changes)
		return true
	end
	return false
end

function set( config, section, option, val)

	if dirty( config ) then
		return false
	else
		if uci:set( config, section, option, val ) and uci:commit( config ) then
			return true
		else
			return false
		end
	end
end


function get( config, section, option )

	if dirty( config ) then
		return false
	else
		return uci:get( config, section, option)
	end
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


function getd( config, section, option )
	return uci:get( config, section, option)
end