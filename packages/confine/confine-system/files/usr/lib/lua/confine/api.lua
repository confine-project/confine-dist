-- TODO override node.state when needed ?
-- TODO class based server-related URLs ? (i.e. private ipv4/mgmt ipv6/public ipv4)
 

local json   = require "luci.json"
local ltn12  = require "luci.ltn12"

function get_table_by_key_val( t, val, key )
	
    local k,v
    for k,v in pairs(t) do
        if t[k][key] == val then
            return t[k]
        end
    end
    return nil
end

function file_get( file )
    local fd = io.open(file, "r")
    if not fd then
        return
    end
    local src = ltn12.source.file(fd)
    local jsd = json.Decoder(true)
    ltn12.pump.all(src, jsd:sink())
    return jsd:get()
end


function set_configuration()
    local sys_conf = file_get("/var/run/confine/system_state")

    SERVER_STATE = file_get("/var/run/confine/server_state")
    LINK_BASE_REL = sys_conf.link_base_rel
    SERVER_ADDR = sys_conf.server_base_uri:match('://(.-)/')
    SERVER_URI = sys_conf.server_base_uri:match('://(.*)')
    API_PATH_PREFIX = sys_conf.node_base_path
    NODE_URL = sys_conf.node_base_uri:gsub(API_PATH_PREFIX, '')
    WWW_PATH = '/var/confine/'
    NODE_ID = sys_conf.id
    DAEMON_PID_FILE = '/var/run/confine/pid'
    PULL_REQUEST_LOCK_FILE = '/dev/shm/confine.pull.lock'
    PULL_REQUEST_THROTTLE = 60
end


--UTILITY FUNCTIONS

function literalize(str)
    return str:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", function(c) return "%" .. c end)
end


function urlize(text)
    -- { mark_start, mark_end, quoted_mark_start, quoted_mark_end }
    local escape_marks = {{'"', '"', '"', '"'}, {"<", ">", "&lt;", "&gt;"},}
    for i, c in ipairs(escape_marks) do
        for url in text:gmatch(c[1]..'http(.-)'..c[2]) do
            url = 'http' .. url
            local link = c[3]..'<a href="' .. url .. '">' .. url .. '</a>'..c[4]
            url = c[1] .. url .. c[2]
            text = text:gsub(literalize(url), link)
        end
    end
    return text
end


function wrap_ipv6(addr)
    if addr:match('%w:%w*:') then
        return '['..addr..']'
    end
    return addr
end


function interp(s, tab)
  return (s:gsub('($%b{})', function(w) return tab[w:sub(3, -2)] or w end))
end


function get_protocol(request)
    if request['SERVER_PORT'] == 443 then
        return 'https'
    end
    return 'http'
end


function get_addr(request)
    return wrap_ipv6(request['SERVER_ADDR'])
end


function list_directories(directory)
    local i, t, popen = 0, {}, io.popen
    for filename in popen('ls -d ' .. directory .. '/*/'):lines() do
        i = i + 1
        t[i] = filename
    end
    return t
end


function escape_quotes(text)
    return text:gsub("'", "'\\''")
end


function get_etag(text)
    text = escape_quotes(text)
    local md5_handle = io.popen("echo -n '" .. text .. "'|md5sum|cut -d' ' -f1")
    local md5 = md5_handle:read()
    md5_handle:close()
    return '"' .. md5 .. '"'
end


function gzip(text)
    text = escape_quotes(text)
    local gzip_handle = io.popen("echo -n '" .. text .. "'|gzip -9f")
    local gzip = gzip_handle:read('*all')
    gzip_handle:close()
    return gzip
end



-- HELPER FUNCTIONS

function dynamic_urls(request, content)
    -- Rewrites content URLs according to SERVER_ADDR from the request
    local proto = get_protocol(request)
    local node_addr = get_addr(request)
    local server_url = "http(s*)://" .. literalize(SERVER_ADDR)
    local content = content:gsub(literalize(NODE_URL), proto .. '://' .. node_addr)
    return content:gsub(server_url, proto .. '://' .. SERVER_ADDR)
end


function render_as_html(request, response)
    local html_head = '<!DOCTYPE html>\n<html>\n<body style="font-family: monospace">\n'
    local html_tail = '\n</body>\n</html>'
    -- Render response as HTML (both response.headers and response.content)
    local title = '<header>\n'
    title = title .. '<h1>Confine-system node API</h1>\n'
    title = title .. '<b>GET</b> ' .. request['REQUEST_URI']
    title = title .. '\n</header>\n'
    -- Headers
    local headers = '<pre><b>' .. response['headers']['Status'] .. '</b>\n'
    for name, value in pairs(response['headers']) do
        if name ~= 'Status' then
            headers = headers .. '<b>' .. name .. ':</b> ' .. value .. '\n'
        end
    end
    headers = headers:gsub(', <', ',<br>      <') .. '</pre>\n'
    -- Content
    local content = '<code><pre>\n' .. response['content'] .. '</pre></code>'
    return urlize(html_head .. title .. headers .. content .. html_tail)
end


function get_links(request, name, patterns)
    -- Given a resource name it returns the associated header links
    local addr = get_addr(request)
    local proto = get_protocol(request)
    local node_links = {
        ['node_base'] = {'', 'node/base'},
        ['node_node'] = {'node/', 'node/node'},
        ['node_slivers'] = { 'slivers/', 'node/sliver-list'},
        ['node_templates'] = {'templates/', 'node/template-list'},
        ['node_refresh'] = {'node/ctl/refresh', 'node/do-refresh'},
    }

    local links, url, rel = {}
    for k, link in pairs(node_links) do
        url = '<' .. proto .. '://' .. addr .. API_PATH_PREFIX .. '/' .. link[1] .. '>; '
        rel = 'rel="' .. LINK_BASE_REL .. link[2] .. '"'
        links[k] = url .. rel
    end
    
    local map = {
        ['base'] = {'node_base', 'node_node', 'node_slivers', 'node_templates'},
        ['node'] = {'node_base',  'node_refresh'},
        ['slivers'] = {'node_base'},
        ['sliver'] = {'node_base', 'node_slivers'},
        ['templates'] = {'node_base'},
        ['template'] = {'node_base', 'node_templates'},
    }
    local rendered_links = {}
    for i, link in ipairs(map[name]) do
        rendered_links[i] = links[link]
    end

    for k,v in pairs(
        (name=='base'     and SERVER_STATE.local_base.header_links) or
        (name=='node'     and SERVER_STATE.header_links) or
        (name=='template' and SERVER_STATE.local_templates[tostring(patterns)].header_links) or
        (name=='sliver'   and (get_table_by_key_val(SERVER_STATE.local_slivers, tostring(patterns), "uri_id") or {}).header_links) or
        {} ) do
            rendered_links[#rendered_links+1] = v .. '; rel="' .. k .. '"'
    end

    return table.concat(rendered_links, ", ")
end


function conditional_response(request, response)
    -- Returns response based on If-None-Match request header
    local request_etag = request['headers']["If-None-Match"]
    local modified = true
    if request_etag and request_etag == response['headers']['ETag'] then
        response['headers']['Status'] = "HTTP/1.0 304 Not Modified"
        response['content'] = ''
        modified = false
    end
    return response, modified
end


function content_negotiation(request, response)
    -- Formats response content based on Accept request header
    local accept = request['headers']["Accept"]
    if accept and string.find(accept, "text/html") then
        response['headers']['Content-Type'] = "text/html"
        response['content'] = render_as_html(request, response)
    else
        response['headers']['Content-Type'] = "application/json"
    end
    return response
end


function encoding_negotiation(request, response)
    -- Encodes response based on Accept-Encoding request header
    local encoding = request['headers']["Accept-Encoding"] 
    if encoding and string.find(encoding, "gzip") and string.len(response['content']) > 0 then
        response['headers']['Content-Encoding'] = "gzip"
        response['content'] = gzip(response['content'])
    else
        response['headers']['Content-Encoding'] = "chunked"
    end
    return response
end


function cgi_response(response)
    -- Formats response as CGI expects
    local headers = response['headers']['Status'] .. '\r\n'
    for name, value in pairs(response['headers']) do
        if name ~= 'Status' then
            headers = headers .. name .. ': ' .. value .. '\r\n'
        end
    end
    local content = headers .. '\r\n'
    content = content .. response['content']
    return content
end


-- VIEWS

function redirect(request, url)
    -- 303 redirection to url   
    local content =''
    local headers = {
        ['Status'] = "HTTP/1.1 303 See Other",
        ['Location'] = url,
        ['Date'] = os.date('%a, %d %b %Y %H:%M:%S +0000'),
--        ['ETag'] = get_etag(content),
--        ['Allow'] = 'GET HEAD',
--        ['Content-Type'] = "text/plain",
--        ['Content-Encoding'] = "chunked",
--        ['Content-Length'] = string.len(content)
    }
    
    return cgi_response( {['headers'] = headers, ['content'] = content} )
end


function _redirect(request, url)
    -- 303 redirection to url
    local headers = {
        ['Status'] = "HTTP/1.1 303 See Other",
        ['Location'] = url
    }
    local response = {
        ['headers'] = headers,
        ['content'] = ''
    }
    return handle_response(request, response)
end


function not_found(request, url)
    -- 404 URL not found
    local headers = {
        ['Status'] = "HTTP/1.0 404 Not Found"
    }
    local content = '{\n    "detail": "Requested ' .. url ..' not found"\n}'
    local response = {
        ['headers'] = headers,
        ['content'] = content
    }
    return handle_response(request, response)
end


function listdir_view(request, name, patterns)
    -- Dir listing based content
    local directory = WWW_PATH .. name
    local addr = get_addr(request)
    local proto = get_protocol(request)
    
    local lines = {}
    for i, dir in ipairs(list_directories(directory)) do
        local dir = dir:match('^'..directory..'(.*)/$')
        local url = proto..'://'..addr..API_PATH_PREFIX..'/'..name..dir..'/'
        lines[i] = '{\n        "uri": "' .. url .. '"\n    }'
    end
    
    local content = '[\n    ' .. table.concat(lines, ",\n    ") .. '\n]'
    local last_modify_handle = io.popen('date -R -r ' .. directory)
    local headers = {
        ['Link'] = get_links(request, name, patterns),
        ['Last-Modified'] = last_modify_handle:read()
    }
    last_modify_handle:close()
    local response = {
        ['headers'] = headers,
        ['content'] = content
    }
    return handle_response(request, response)
end


function file_view(request, name, patterns)
    -- File based content
    local map = {
        ['base'] = 'index.html',
        ['node'] = 'node/index.html',
        ['slivers'] = 'slivers/index.html',
        ['sliver'] = 'slivers/%s/index.html',
        ['templates'] = 'templates/index.html',
        ['template'] = 'templates/%s/index.html',
    }
    
    local file = WWW_PATH .. map[name]:format(patterns)
    local f = io.open(file, "rb")
    if not f then
        return not_found(request, request['REQUEST_URI'])
    end
    local content = f:read("*all")
    f:close()
    
    local content = dynamic_urls(request, content)
    local last_modify_handle = io.popen('date -R -r ' .. file)
    local headers = {
        ['Link'] = get_links(request, name, patterns),
        ['Last-Modified'] = last_modify_handle:read()
    }
    last_modify_handle:close()
    local response = { 
        ['headers'] = headers,
        ['content'] = content
    }
    return handle_response(request, response)
end


function pullrequest_view(request, name, patterns)
    -- Wakes up confine daemon in order to make it poll the server
    -- TODO use POST instead of GET
    local headers = {}
    
    local lock_date_handle = io.popen('date -r '..PULL_REQUEST_LOCK_FILE..' +"%s"')
    local lock_date = tonumber(lock_date_handle:read('*all'))
    lock_date_handle:close()
    
    now_handle = io.popen('date +"%s"')
    now = now_handle:read('*all')
    now_handle:close()
    
    if not lock_date or (lock_date < now-PULL_REQUEST_THROTTLE) then
        local pid_file = io.open(DAEMON_PID_FILE, "rb")
        if pid_file then
            -- Wakeup confine daemon by sending a CONT signal
            pid = pid_file:read('*all')
            pid_file:close()
            os.execute('kill -s CONT ' .. pid)
            os.execute('touch ' .. PULL_REQUEST_LOCK_FILE)
            content = '{\n    "detail": "Node instructed to refresh itself"\n}'
        else
            headers['Status'] = "HTTP/1.0 500 Internal Server Error"
            content = '{\n    "detail": "Confine daemon is not running"\n}'
        end
    else
        headers['Status'] = "HTTP/1.0 429 Too Many Requests"
        content = '{\n    "detail": "Too many requests"\n}'
    end
    local response = {
        ['headers'] = headers,
        ['content'] = content
    }
    return handle_response(request, response)
end


-- REQUEST/RESPONSE CYCLE FUNCTIONS

function handle_response(request, response)
    -- Renders the response object as something that CGI server can understand
    -- also performs advance HTTP functions like content and encoding negotiation,
    -- conditional request, etc
    
    -- RFC 2822 date format
    response['headers']['Date'] = os.date('%a, %d %b %Y %H:%M:%S +0000')
    response['headers']['ETag'] = get_etag(response['content'])
    response['headers']['Allow'] = 'GET HEAD'
    
    if not response['headers']['Status'] then
        response['headers']['Status'] = "HTTP/1.0 200 OK"
    end
    
    -- Conditional response
    local response, modified = conditional_response(request, response)
    if modified then
        response = content_negotiation(request, response)
        response = encoding_negotiation(request, response)
    end
    response['headers']['Content-Length'] = string.len(response['content'])
    return cgi_response(response)
end


function api_path_dispatch(request, api_path)
    -- Mapping between API paths and functions (views/handlers)
    local map = {
        ['^/$'] = {file_view, 'base'},
        ['^/node/ctl/refresh/$'] = {pullrequest_view, 'ctl'},
        ['^/node/$'] = {file_view, 'node'},
        ['^/slivers/(%d+)/$'] = {file_view, 'sliver'},
--      ['^/slivers/$'] = {listdir_view, 'slivers'},
        ['^/slivers/$'] = {file_view, 'slivers'},
        ['^/templates/(%d+)/$'] = {file_view, 'template'},
--      ['^/templates/$'] = {listdir_view, 'templates'},
        ['^/templates/$'] = {file_view, 'templates'},
    }
    for p, view in pairs(map) do
        local patterns = api_path:match(p)
        if patterns then
            return view[1], view[2], tonumber(patterns)
        end
    end
    return
end


function internal_server_error(request, err_msg)

--    err_msg = '{\n    "detail": "Internal Server Error"\n}'

    local headers = {
        ['Status'] = "HTTP/1.0 500 Internal Server Error",
        ['Date'] = os.date('%a, %d %b %Y %H:%M:%S +0000'),
--        ['ETag'] = get_etag(err_msg),
        ['Allow'] = 'GET HEAD',
        ['Content-Type'] = "text/plain",
        ['Content-Encoding'] = "chunked",
        ['Content-Length'] = string.len(err_msg)
    }
    
    return cgi_response( {['headers'] = headers, ['content'] = err_msg} )
end


function handle_xpcall_error(e)
	local trace = string.format(
		"\n%s\n" ..
		"----------\n" ..
		"%s\n" ..
		"----------\n",
		tostring(e) or "(?)",
		tostring(debug.traceback(2))
	)
	return trace
end

function main(request)
    -- configuration is loaded on each request since it may not be available during uhttpd start
    set_configuration()
    
    local REQUEST_URI = request['REQUEST_URI']
    -- Remove path prefix from the beginning of the request URI path
    local api_path = REQUEST_URI:gsub('^' .. API_PATH_PREFIX, '')
    local view, name, patterns = api_path_dispatch(request, api_path)
    local response
    if view then
        response = view(request, name, patterns)
    else
        -- Hack in order to match a 'slashed' API path before returning 404
        if api_path:sub(-1, -1) == '/' then
            response = not_found(request, REQUEST_URI)
        else
            response = redirect(request, REQUEST_URI .. '/')
        end
    end
    
    return response
end

-- "MAIN" FUNCTION

function handle_request(request)
    
    local success, response = xpcall(function() return main(request) end, handle_xpcall_error)
    
    if not success then
	response = internal_server_error(request, response)	
    end
    
    uhttpd.send(response)
end
