#!/usr/bin/env tarantool

box.cfg {
    listen = 3301,
    wal_mode = 'none',
}

box.schema.user.passwd('admin', 'crud')

local function init()
    box.schema.space.create('customer', {if_not_exists = true})
    box.space.customer:format({
        {name = 'uuid', type = 'string'},
        {name = 'name', type = 'string'},
        {name = 'group', type = 'string'},
    })
    box.space.customer:create_index('uuid', {parts = {{field = 'uuid'}}, if_not_exists = true})
    box.space.customer:create_index('group', {parts = {{field = 'group'}}, if_not_exists = true})
end

local function flatten(format, data)
    local tuple = {}
    for _, field in ipairs(format) do
        table.insert(tuple, data[field.name])
    end
    return tuple
end

local function unflatten(format, tuple)
    local data = {}
    for i, field in ipairs(format) do
        data[field.name] = tuple[i]
    end
    return data
end

local function create(customer)
    local space = box.space.customer
    local tuple = flatten(space:format(), customer)
    space:replace(tuple)
end

local function update(uuid, updates)
    local space = box.space.customer
    local update_list = {}

    for key, value in pairs(updates) do
        table.insert(update_list, {'=', key, value})
    end

    space:update({uuid}, update_list)
end

local function delete(uuid)
    box.space.customer:delete({uuid})
end

local function get(uuid)
    local space = box.space.customer
    local tuple = space:get({uuid})
    if tuple == nil then
        return nil
    end

    local object = unflatten(space:format(), tuple)
    return object
end

_G.create = create
_G.update = update
_G.delete = delete
_G.get = get

init()
