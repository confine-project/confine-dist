--[[



]]--

--- CONFINE data io library.
module( "confine.uci", package.seeall )

local tools  = require "confine.tools"
local dbg    = tools.dbg

local lucim  = require "luci.model.uci"



function is_clean( config )
	
	local uci = lucim.cursor()

	local uci_changes = uci.changes( config )
	if uci_changes[config] then
		dbg("config=%s has uncomiited changes:", config )
		luci.util.dumptable(uci_changes)
		return false
	end
	return uci
end

function set( config, section, option, val)

	local uci = is_clean(config)
	assert( uci, "uci.set config=%s DIRTY when setting option=%s"
	       %{tostring(config), tostring(section).."."..tostring(option).."."..tostring(val)})

	assert( uci:set( config, section, option, val ) and uci:commit( config ) and
	       uci:set( config, section, option, val ) and uci:commit( config ) and --FIXME: WTF!!!!!!!!!!!!!
	       uci:get( config, section, option )==tostring(val),
		"%s.%s.%s NOT %s" %{ tostring(config),tostring(section),tostring(option),tostring(val)})
	
	return true
	       
end

function get( config, section, option, default )

	local uci = is_clean(config)
	assert( uci, "uci.get config=%s DIRTY when getting option=%s" %{tostring(config), tostring(section).."."..tostring(option)})

	local val = uci:get( config, section, option)
	
	if val == nil and default ~= nil then
		set( config, section, option, default)
		return default
	end
	
	return val
end


function get_all( config, section )

	local uci = is_clean(config)
	assert( uci )
	
	dbg("config=%s, section=%s", tostring(config), tostring(section))
	
	if section then
		
		return uci:get_all( config, section)
	else
		return uci:get_all( config )
	end
end

function set_section_opts( config, section, values )
	
	local uci = is_clean(config)
	assert( uci )
	dbg("")

	for ok,ov in pairs( values ) do
		if type(ok)=="string" and not ok:match("^%.") then
			dbg( "%s.%s.%s=%s", config,section,ok,ov )
			assert( set( config, section, ok, tostring(ov) ) )
			--assert( get( config, section, ok )==tostring(ov), "%s.%s.%s NOT %s" %{ config,section,ok,ov} )
		end
	end
	
	return true
end

function set_all( config, sections )

	assert()
	assert( type(config)=="string" and type(sections)=="table" )

	local uci = is_clean(config)
	assert( uci )

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

