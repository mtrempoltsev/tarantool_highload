#!/usr/bin/env tarantool

local log = require('log')
local netbox = require('net.box')
local http_server = require('http.server')

--
-- HTTP server that distributes requests between IProto servers.
-- to run `tarantool -i balance.lua`
-- Following instances should be started before this HTTP server.
--

local hosts = {
    'admin:test@localhost:3301',
    'admin:test@localhost:3302',
    'admin:test@localhost:3303',
}

local connections = {}
for _, host in ipairs(hosts) do
    local conn = netbox.connect(host)
    assert(conn)
    log.info('Connected to %s', host)
    table.insert(connections, conn)
end

local req_num = 1
local function handler()
    local conn = connections[req_num]

    if req_num == #connections then
        req_num = 1
    else
        req_num = req_num + 1
    end

    local result = conn:call('exec')

    return {
        body = result,
        status = 200,
    }
end

local httpd = http_server.new('0.0.0.0', '8080', {log_requests = false})
httpd:route({method = 'GET', path = '/'}, handler)
httpd:start()
