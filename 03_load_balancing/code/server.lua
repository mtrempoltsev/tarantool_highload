#!/usr/bin/env tarantool

--
-- IProto-server
-- Should be used to distribute input requests using load balancer.
-- to run `tarantool -i server.lua <port>`. <port> should be 3301, 3302, 3303.
--

local fio = require('fio')
local digest = require('digest')
local port = tonumber(arg[1])
if port == nil then
    error('Invalid port')
end

local work_dir = fio.pathjoin('data', port)
fio.mktree(work_dir)
box.cfg({
    listen = port,
    work_dir = work_dir,
})
box.schema.user.passwd('admin', 'test')

function exec()
    local str = string.format("I'm %s", port)
    for _ = 1, 1e2 do
        digest.sha512_hex(str)
    end
    return str
end
