--[[



]]--

--- CONFINE jaon data io library.
module( "confine.data", package.seeall )



local nixio  = require "nixio"
local json   = require "luci.json"
local ltn12  = require "luci.ltn12"
local http   = require "luci.http.protocol"
local lutil  = require "luci.util"

local tools  = require "confine.tools"
local ctree  = require "confine.tree"

local dbg    = tools.dbg

local json_pretty_print_tool   = [=[python -c "import json, sys; print json.dumps(json.loads(sys.stdin.read().decode('utf8', errors='replace')), indent=4)" ]=]

null = json.null

function val2string(val)
	if val == nil then
		return tostring(val)--"ERROR"
	elseif val==null then
		return "null"
	else
		return tostring(val)
	end
end


function file_put( data, file, dir )

	if dir then
		tools.mkdirr(dir)
	else
		dir = ""
	end


	dbg("updating "..dir..(file or ""))
	
	if file and data then
		local out = io.open(dir .. file, "w")
		assert(out, "Failed to open %s" %dir .. file)	
		ltn12.pump.all(json.Encoder(data):source(), ltn12.sink.file(out))
		
		local tmp = os.tmpname()
		local cmd = "cat "..dir..file.." | "..json_pretty_print_tool.." > "..tmp
		
		if os.execute( cmd ) == 0 then
			nixio.fs.move( tmp, dir..file)
		else
			os.remove(tmp)
		end
		
	elseif data then
		local k,v
		for k,v in pairs(data) do
			file_put( v, "index.html", dir .. k .. "/" )
		end
	end
end

function file_get( file )

	local fd = io.open(file, "r")
	if not fd then
		dbg("Failed to open %s" %file)
		return
	end
	
	local src = ltn12.source.file(fd)
	local jsd = json.Decoder(true)
	
	ltn12.pump.all(src, jsd:sink())

	return ctree.copy_recursive_rebase_keys(jsd:get())

end

function curl(url, data, header, etag, cert, compressed, timeout, stderr)
		
		assert(url)
		assert(data)
		local header_opt = header and ("--dump-header %s" %{header}) or ""
		local etag_opt = etag and ([[ --header 'If-None-Match: %q' ]] %{etag}) or ""
		local cert_opt = cert and ("--ca-certificate=%s" %{cert}) or "--insecure"
		local compressed_opt = compressed and "--compressed" or ""		
		local timeout_opt = timeout and ("--max-time %s --connect-timeout %s" %{timeout, timeout}) or "3600"
		local stderr_log = stderr and "" or "2>/dev/null"
		
		local cmd = [[ /usr/bin/curl -gG %s %s %s --output %s %s %s %s %s ]]
				%{cert_opt, compressed_opt, timeout_opt, data, header_opt, etag_opt, url, stderr_log}
				
		return os.execute( cmd )
end

function http_get_raw( url, dst, cert_file )
	if not url then return nil end
	
	assert(url and dst and not nixio.fs.stat(dst))
	
	return ( curl( url, dst, false, false, cert_file, false, "3600", true) == 0) and true or false
end


function http_get_keys_as_table(url, base_uri, cert_file, cache)

	if not url then return nil end
	
	local base_key,index_key = ctree.get_url_keys( url )
	local cached             = cache and cache[base_key] and ((index_key and cache[base_key][index_key]) or (not index_key and cache[base_key])) or false
	
	url = base_uri..base_key..(index_key or "") --.. ".invalid"
	
	if cached and cached.sqn and cached.sqn == cache.sqn then
		
		dbg("%6s url=%-60s base_key=%s index_key=%s", "CACHED", url, tostring(base_key), tostring(index_key))
		return cached.data, index_key
	
	else

		local etag = (cached and cached.etag or "0000")
		local header_file = os.tmpname()
		local data_file = os.tmpname()
		
		curl( url, data_file, header_file, etag, cert_file, true, "20")

		local header = nixio.fs.readfile( header_file )
		local data_fd = io.open(data_file, "r")
		
		local src = ltn12.source.file(data_fd)
		local jsd = json.Decoder(true)
		local result = ltn12.pump.all(src, jsd:sink())
		
		os.remove(header_file)
		os.remove(data_file)
		
		if header:match("HTTP/1.1 404 NOT FOUND") then
			
			dbg("%6s url=%-60s base_key=%s index_key=%s", "MISSING", url, tostring(base_key), tostring(index_key))
			assert( false, "wget returned: '404 NOT FOUND' full response: " .. tostring(header) )
			
		elseif header:match("HTTP/1.1 200 OK") then
			
			header_etag = (header:match( "ETag:[^\n]+\n") or ""):gsub(" ",""):gsub("ETag:",""):gsub([["]],""):gsub("\n",""):match("^[^;]+")
			
			dbg("%6s url=%-60s base_key=%s index_key=%s etag=%s", cache and "MODIFIED" or "NO CACHE", url, tostring(base_key), tostring(index_key), tostring(header_etag))
			
			assert(result, "Failed processing json input from: %s"%{url} )
			
			result = jsd:get()
			
			assert(type(result)=="table", "Failed decoding json input from: %s"%{url} )
			
			result = ctree.copy_recursive_rebase_keys(result)
			assert(type(result) == "table", "Failed rebasing json keys from: %s"%{url} )
			
			if cache then
				if not cache[base_key] then cache[base_key] = {} end
				
				if index_key then
					cache[base_key][index_key] = {sqn=cache.sqn, etag=header_etag, data=result}
				else
					cache[base_key] = {sqn=cache.sqn, etag=header_etag, data=result}
				end
			end
			
			
		elseif header:match("HTTP/1.1 304 NOT MODIFIED") then
			
			dbg("%6s url=%-60s base_key=%s index_key=%s", "UNCHANGED", url, tostring(base_key), tostring(index_key))
			
			assert( cache and cached and cached.sqn and cached.etag and cached.data, "Corrupted cache")
			result = cached.data
			cached.sqn = cache.sqn
			
		else
			dbg("%6s url=%-60s base_key=%s index_key=%s", "ERROR!!", url, tostring(base_key), tostring(index_key))
			dbg("curl data saved to: "..data_file.." response from "..url..": "..tostring(header))
		end
		
		
		return result, index_key
		
	end
end

function http_post(path, base_uri, data)

	dbg("post %s", path)

	local str = http.urlencode_params(data)
	local cmd = wpost %{ base_uri..path, str }

	local fd = io.popen(cmd, "r")
	assert(fd, "Failed to execute %s" %{ cmd })

	local src = ltn12.source.file(fd)
	local jsd = json.Decoder(true)


	ltn12.pump.all(src, jsd:sink())

	return jsd:get()
end

