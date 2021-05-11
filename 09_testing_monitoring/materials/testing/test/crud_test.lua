#!/usr/bin/env tarantool

local t = require('luatest')
local g = t.group('test.crud')
local fio = require('fio')

g.before_all(function()
    local tmpdir = fio.tempdir()
    g.server = t.Server:new({
        command = 'init.lua',
        -- additional envars to pass to process
        env = {SOME_FIELD = 'value'},
        -- passed as TARANTOOL_WORKDIR
        workdir = tmpdir,
        -- passed as TARANTOOL_HTTP_PORT, used in http_request
        http_port = 8080,
        -- passed as TARANTOOL_LISTEN, used in connect_net_box
        net_box_port = 3301,
        -- passed to net_box.connect in connect_net_box
        net_box_credentials = {user = 'admin', password = 'crud'},
    })
    g.server:start()
    t.helpers.retrying({}, function()
        g.server:connect_net_box()
    end)
end)

g.after_each(function()
    g.server.net_box:eval([[
        box.space.customer:truncate()
    ]])
end)

g.after_all(function()
    g.server:stop()
end)

function g.test_get()
    local uuid = '978046d5-f768-4c08-9757-02cb041ea7b0'

    local customer = g.server.net_box:call('get', {uuid})
    t.assert_equals(customer, nil)

    g.server.net_box:call('create', {
        { uuid = uuid, name = 'Ivan', group = 'developer'}
    })

    customer = g.server.net_box:call('get', {uuid})
    t.assert_not_equals(customer, nil)
    t.assert_equals(customer.uuid, uuid)
    t.assert_equals(customer.name, 'Ivan')
    t.assert_equals(customer.group, 'developer')
end
