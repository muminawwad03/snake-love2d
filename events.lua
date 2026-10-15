-- events.lua
-- Bonus: simple observer pattern. Any module can subscribe to a named
-- event; emitting it calls every subscriber with the event data.
local Events = {}

local listeners = {}

-- Returns an unsubscribe function so a listener can remove itself later
function Events:subscribe(event, callback)
    listeners[event] = listeners[event] or {}
    table.insert(listeners[event], callback)

    return function()
        local list = listeners[event]
        if not list then return end
        for i = #list, 1, -1 do
            if list[i] == callback then
                table.remove(list, i)
            end
        end
    end
end

function Events:emit(event, data)
    local list = listeners[event]
    if not list then return end
    -- Iterate over a copy so listeners may unsubscribe while being called
    local snapshot = {}
    for i, callback in ipairs(list) do snapshot[i] = callback end
    for _, callback in ipairs(snapshot) do
        callback(data)
    end
end

function Events:clear(event)
    if event then
        listeners[event] = nil
    else
        listeners = {}
    end
end

return Events
