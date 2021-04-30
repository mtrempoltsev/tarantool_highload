function request()
    local url

    if math.random() < 0.1 then
        url = '/hell0'
    else
        url = '/hello'
    end

    local req = wrk.format('GET', url, {
        ['Content-Type'] = 'application/json',
    })
    return req
end
