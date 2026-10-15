-- input.lua
-- Command pattern: keys are bound to command functions, so the code that
-- reads the keyboard never needs to know what an action actually does.
local Input = {}
Input.__index = Input

function Input:new()
    local input = {
        commands = {}
    }
    return setmetatable(input, Input)
end

function Input:bind(key, command)
    self.commands[key] = command
end

function Input:unbind(key)
    self.commands[key] = nil
end

-- Returns true if a command was bound to the key and executed
function Input:handleKey(key)
    local command = self.commands[key]
    if command then
        command()
        return true
    end
    return false
end

return Input
