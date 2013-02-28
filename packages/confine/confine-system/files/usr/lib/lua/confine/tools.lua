 --[[



]]--

--- CONFINE tools library.
module( "confine.tools", package.seeall )

local lucifs = require "luci.fs"
local socket  = require "socket"
local nixio   = require "nixio"


logfile = false


function dbg_(nl, err, fmt, ...)
	local t = nixio.times()
	local l = "[%d.%3d] %s() %s%s" %{os.time(), (t.utime + t.stime + t.cutime + t.cstime), debug.getinfo(2).name or "???", string.format(fmt,...), nl and "\n" or "" }
	if err then
		io.stderr:write(l)
	else
		io.stdout:write(l)
	end
	
	if logfile then
		local out = io.open(logfile, "a")
		assert(out, "Failed to open %s" %logfile)
		out:write(l)
		out:close()
	end

	--io.stdout:write(string.format("[%d.%3d] ", os.time(), t.utime + t.stime + t.cutime + t.cstime))
	--io.stdout:write((debug.getinfo(2).name or "???").."() ")
	--io.stdout:write(string.format(fmt, ...))
	--if nl then io.stdout:write("\n") end
end

function dbg(fmt, ...)
	dbg_(true, false, fmt, ...)
end

function err(fmt, ...)
	dbg_(true, true, fmt, ...)
end

--- Extract flags from an arguments list.
-- Given string arguments, extract flag arguments into a flags set.
-- For example, given "foo", "--tux=beep", "--bla", "bar", "--baz",
-- it would return the following:
-- {["bla"] = true, ["tux"] = "beep", ["baz"] = true}, "foo", "bar".
function parse_flags(args)
--   local args = {...}
   local flags = {}
   for i = #args, 1, -1 do
      local flag = args[i]:match("^%-%-(.*)")
      if flag then
         local var,val = flag:match("([a-z_%-]*)=(.*)")
         if val then
            flags[var] = val
         else
            flags[flag] = true
         end
         table.remove(args, i)
      end
   end
   return flags, unpack(args)
end

stop = false

function handler(signo)
	nixio.signal(nixio.const.SIGINT,  "ign")
	nixio.signal(nixio.const.SIGTERM, "ign")
	dbg("going to stop now...")
	stop = true
end

function sleep(sec)
	local interval=1
	if stop then
		return
	else
		dbg("sleeping for %s seconds...", sec)
	end
		
	while sec>0 do
		if stop then return end
		if sec > interval then
			sec = sec - interval
		else
			interval = sec
			sec = 0
		end
		socket.select(nil, nil, interval)
	end
end



function canon_arch(arch)
	--if arch == "amd64" or arch == "x86_64" or
	--   arch == "i386"  or arch == "i486" or
	--   arch == "i586"  or arch == "i686"
	--then
	--	return "x86"
	--end

	return arch
end

function canon_ipv6(ipv6)

	local cidr = luci.ip.IPv6(ipv6)
	
	if cidr then
		return cidr:string()
	end
end

function mkdirr( path, mode )
	local first = 0
	local last = path:len()

	while true do
		local sub = path:sub(first + 1)
		local pos = sub:find( "/" )
		if pos then
			first = first + pos
			local dir = string.sub(path, 1, first)
			if not lucifs.isdirectory(dir) then
				dbg("mkdir "..dir)
				nixio.fs.mkdir( dir, mode )
			end
			assert( lucifs.isdirectory(dir), "Failed creating dir=%s" %dir )
		else
			return
		end
	end
end

function join_tables( t1, t2 )
	local tn = {}
	local k,v
	for k,v in pairs(t1) do tn[k] = v end
	for k,v in pairs(t2) do tn[k] = v end
	return tn
end

function get_table_items( t )
	local count = 0
	local k,v
	for k,v in pairs(t) do
		count = count + 1
		--dbg("get_table_items() c=%s k=%s v=%s", count, k, tostring(v))
	end
	--dbg("get_table_items() t=%s c=%s", tostring(t), count)
	return count
end

function get_table_by_key_val( t, val, key )
	
	local k,v
	for k,v in pairs(t) do
		if key then
			if t[k][key] == val then
				return t[k]
			end
		else
			if t[k] == val then
				return k
			end
		end
	end
	return nil
end

function fname()
	return debug.getinfo(2).name.."() "
end

function str2table( str, pattern )

	if not pattern then pattern = "%a+" end
	
	local t = {}
	local word
	for word in string.gmatch( str, pattern ) do
		t[#t+1] = word
	end
	
	return t
end

function subfind(str, start_pattern, end_pattern )

	local i,j = str:find(start_pattern)
	
	if i and j then
		
		if end_pattern then
			local k,l = str:sub(j+1):find(end_pattern)
	
--			dbg("sp=%s=%s %d %d ep=%s=%s %d %d found:\n%s",
--			    start_pattern,str:sub(i,j), i, j, end_pattern, str:sub(j+k,j+l), k, l, str:sub(i,j+l) )
			
			if (k and l) then
				return (str:sub(i,j+l)), i, (j+l)
			else
				return nil
			end
		end
		
		return str:sub(i), i, str:len()
	end	
end

function subfindex( str, start_pattern, end_pattern )
	local res,i,j = subfind(str, start_pattern, end_pattern)
	
	if res then
		if end_pattern then		
			return res:gsub( "^%s"%start_pattern,""):gsub("%s$"%end_pattern,""),
				(i+(start_pattern:len())), (j-(end_pattern:len()))
		else
			return res:gsub( "^%s"%start_pattern,""), (i+(start_pattern:len())), j
		end
	end
end
