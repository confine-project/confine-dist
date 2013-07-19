-- TODO override node.state when needed ?
-- TODO class based server-related URLs ?
 

local data = require 'confine.data'


function set_configuration()
    local sys_conf = data.file_get("/var/run/confine/system_state")

    SERVER_ADDR = sys_conf.server_base_uri:match('://(.-)/')
    API_PATH_PREFIX = sys_conf.node_base_path
    NODE_URL = sys_conf.node_base_uri:gsub(API_PATH_PREFIX, '')
    SERVER_API_PATH_PREFIX = sys_conf.server_base_path
    WWW_PATH = '/var/confine/'
    NODE_ID = sys_conf.id
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
            link = c[3]..'<a href="' .. url .. '">' .. url .. '</a>'..c[4]
            url = c[1] .. url .. c[2]
            text = text:gsub(literalize(url), link)
        end
    end
    return text
end


function wrap_ipv6(addr)
    if addr:match('%d:%d*:') then
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



-- HELPER FUNCTIONS

function dynamic_urls(request, content)
    -- Rewrites content URLs according to SERVER_ADDR from the request
    local proto = get_protocol(request)
    local node_addr = get_addr(request)
    local server_url = "http(s*)://" .. literalize(SERVER_ADDR)
    content = content:gsub(literalize(NODE_URL), proto .. '://' .. node_addr)
    return content:gsub(server_url, proto .. '://' .. SERVER_ADDR)
end


function render_as_html(request, response)
    html_head = '<!DOCTYPE html>\n<html>\n<body style="font-family: monospace">\n'
    html_tail = '\n</body>\n</html>'
    -- Render response as HTML (both response.headers and response.content)
    title = '<header>\n'
    title = title .. '<h1>Confine-system node API</h1>\n'
    title = title .. '<b>GET</b> ' .. request['REQUEST_URI']
    title = title .. '\n</header>\n'
    -- Headers
    headers = '<pre><b>' .. response[1]['Status'] .. '</b>\n'
    for name, value in pairs(response[1]) do
        if name ~= 'Status' then
            headers = headers .. '<b>' .. name .. ':</b> ' .. value .. '\n'
        end
    end
    headers = headers:gsub(', ', ',<br>      ') .. '</pre>\n'
    -- Content
    content = '<code><pre>\n' .. response[2] .. '</pre></code>'
    return urlize(html_head .. title .. headers .. content .. html_tail)
end


function get_links(request, name, patterns)
    -- Given a resource name it returns the associated header links
    local addr = get_addr(request)
    local proto = get_protocol(request)
    node_links = {
        ['node_base'] = {'', 'node/base'},
        ['node_node'] = {'node/', 'node/node'},
        ['node_slivers'] = { 'slivers/', 'node/sliver-list'},
        ['node_templates'] = {'templates/', 'node/template-list'},
    }
    server_links = {
        ['server_base'] = {'', 'server/base'},
        ['server_server'] = {'server/', 'server/server'},
        ['server_nodes'] = {'nodes/', 'server/node-list'},
        ['server_slices'] = {'slices/', 'server/slice-list'},
        ['server_slivers'] = { 'slivers/', 'server/sliver-list'},
        ['server_users'] = { 'users/', 'server/user-list'},
        ['server_groups'] = {'groups/', 'server/group-list'},
        ['server_gateways'] = {'gateways/', 'server/gateway-list'},
        ['server_hosts'] = {'hosts/', 'server/host-list'},
        ['server_templates'] = {'templates/', 'server/template-list'},
        ['server_islands'] = {'islands/', 'server/island-list'},
        ['server_reboot'] = {'nodes/${node_id}/ctl/reboot', 'server/do-reboot'},
        ['server_cache_cndb'] = {'nodes/${node_id}/ctl/reboot', 'server/do-cache-cndb'},
        ['server_req_api_cert'] = {'nodes/${node_id}/ctl/request-api-cert', 'server/do-request-api-cert'},
        ['server_node_source'] = {'nodes/${node_id}', 'node/source'},
        ['server_update'] = {'slivers/${object_id}/ctl/update', 'server/do-update'},
        ['server_upload_exp_data'] = {'slivers/${object_id}/ctl/upload-exp-data', 'server/do-upload-exp-data'},
        ['server_sliver_source'] = {'slivers/${object_id}', 'node/source'},
        ['server_upload_image'] = {'templates/${object_id}/ctl/upload-image', 'server/do-upload-image'},
        ['server_template_source'] = {'templates/${object_id}', 'node/source'},
    }
    links = {}
    for k, link in pairs(node_links) do
        url = '<' .. proto .. '://' .. addr .. API_PATH_PREFIX .. '/' .. link[1] .. '>; '
        rel = 'rel="http://confine-project.eu/rel/'..link[2]..'"'
        links[k] = url .. rel
    end
    
    for k, link in pairs(server_links) do
        url = '<' .. proto .. '://' .. SERVER_ADDR .. SERVER_API_PATH_PREFIX .. '/' .. link[1] .. '>; '
        url = interp(url, {node_id=NODE_ID, object_id=patterns})
        rel = 'rel="http://confine-project.eu/rel/' .. link[2] .. '"'
        links[k] = url .. rel
    end
    
    map = {
        ['base'] = {'node_base', 'node_node', 'node_slivers', 'node_templates',
                    'server_node_source', 'server_base', 'server_server', 'server_nodes',
                    'server_users', 'server_groups', 'server_gateways', 'server_slivers',
                    'server_hosts', 'server_templates', 'server_islands'},
        ['node'] = {'node_base',  'server_nodes', 'server_node_source', 'server_reboot',
                    'server_cache_cndb'},
        ['slivers'] = {'node_base', 'server_slivers'},
        ['sliver'] = {'node_base', 'node_slivers', 'server_slivers', 'server_sliver_source',
                      'server_update', 'server_upload_exp_data'},
        ['templates'] = {'node_base', 'server_templates'},
        ['template'] = {'node_base', 'node_templates', 'server_templates',
                        'server_template_source', 'server_upload_image'},
    }
    rendered_links = {}
    for i, link in ipairs(map[name]) do
        rendered_links[i] = links[link]
    end
    return table.concat(rendered_links, ", ")
end



-- VIEWS

function redirect(request, url)
    -- 303 redirection to URL
    headers = {
        ['Status'] = "HTTP/1.1 303 See Other",
        ['Location'] = url
    }
    response = {headers, ''}
    return handle_response(request, response)
end


function not_found(request, url)
    -- 404 URL not found
    headers = {
        ['Status'] = "HTTP/1.0 404 Not Found"
    }
    content = '{\n    "detail": "Requested ' .. url ..' not found"\n}'
    response = {headers, content}
    return handle_response(request, response)
end


function listdir_view(request, name, patterns)
    -- Dir listing based content
    local directory = WWW_PATH .. name
    local addr = get_addr(request)
    local proto = get_protocol(request)
    
    local lines = {}
    for i, dir in ipairs(list_directories(directory)) do
        dir = dir:match('^'..directory..'(.*)/$')
        url = proto..'://'..addr..API_PATH_PREFIX..'/'..name..dir..'/'
        lines[i] = '{\n        "uri": "' .. url .. '"\n    }'
    end
    
    local content = '[\n    ' .. table.concat(lines, ",\n    ") .. '\n]'
    headers = {
        ['Link'] = get_links(request, name, patterns),
        ['Last-Modified'] = io.popen('date -r ' .. directory):read()
    }
    response = {headers, content}
    return handle_response(request, response)
end


function file_view(request, name, patterns)
    -- File based content
    local map = {
        ['base'] = 'index.html',
        ['node'] = 'node/index.html',
        ['sliver'] = 'slivers/%s/index.html',
        ['template'] = 'templates/%s/index.html',
    }
    
    local file = WWW_PATH .. map[name]:format(patterns)
    local f = io.open(file, "rb")
    if not f then
        return not_found(request, request['REQUEST_URI'])
    end
    local content = f:read("*all")
    f:close()
    
    content = dynamic_urls(request, content)
    headers = {
        ['Link'] = get_links(request, name, patterns),
        ['Last-Modified'] = io.popen('date -r ' .. file):read()
    }
    response = {headers, content}
    return handle_response(request, response)
end



-- REQUEST/RESPONSE CYCLE FUNCTIONS

function handle_response(request, response)
    -- Renders the response object as something that CGI server can understand
    -- and performs content negotiation
    if not response[1]['Status'] then
        response[1]['Status'] = "HTTP/1.0 200 OK"
    end
    if string.find(request["headers"]["Accept"], "text/html") then
        response[1]['Content-Type']= "text/html"
        response[2] = render_as_html(request, response)
    end
    content = response[1]['Status'] .. '\r\n'
    for name, value in pairs(response[1]) do
        if name ~= 'Status' then
            content = content .. name .. ': ' .. value .. '\r\n'
        end
    end
    content = content .. '\r\n'
    content = content .. response[2]
    return content
end


function api_path_dispatch(request, api_path)
    -- Mapping between API paths and functions (views/handlers)
    map = {
        ['^/$'] = {file_view, 'base'},
        ['^/node/$'] = {file_view, 'node'},
        ['^/slivers/(%d+)/$'] = {file_view, 'sliver'},
        ['^/slivers/$'] = {listdir_view, 'slivers'},
        ['^/templates/(%d+)/$'] = {file_view, 'template'},
        ['^/templates/$'] = {listdir_view, 'templates'},
    }
    for p, view in pairs(map) do
        patterns = api_path:match(p)
        if patterns then
            return view[1], view[2], tonumber(patterns)
        end
    end
    return
end



-- "MAIN" FUNCTION

function handle_request(request)
    -- configuration is loaded on each request since it may not be available during uhttpd start
    set_configuration()

    local REQUEST_URI = request['REQUEST_URI']
    -- Remove the path prefix from the beginning of the request URI path
    local api_path = REQUEST_URI:gsub('^' .. API_PATH_PREFIX, '')
    view, name, patterns = api_path_dispatch(request, api_path)
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
    uhttpd.send(response)
end
