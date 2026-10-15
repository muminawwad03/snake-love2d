-- gamestate.lua
-- State manager. Only one state is active at a time; love callbacks are
-- forwarded to it. A state is a table that may define:
--   enter(manager, ...)  called when switched to
--   exit()               called when switched away from
--   update(dt), draw(), keypressed(key)
local GameState = {}
GameState.__index = GameState

function GameState:new()
    local state = {
        current = "menu",
        states = {
            menu = require("states.menu_state"),
            playing = require("states.game_state")
        }
    }
    setmetatable(state, GameState)
    state:switch("menu")
    return state
end

-- Extra arguments are passed through to the new state's enter()
function GameState:switch(newState, ...)
    local target = self.states[newState]
    assert(target, "unknown game state: " .. tostring(newState))

    local old = self.states[self.current]
    if old and old ~= target and old.exit then
        old:exit()
    end

    self.current = newState
    if target.enter then
        target:enter(self, ...)
    end
end

function GameState:active()
    return self.states[self.current]
end

function GameState:update(dt)
    local state = self:active()
    if state.update then state:update(dt) end
end

function GameState:draw()
    local state = self:active()
    if state.draw then state:draw() end
end

function GameState:keypressed(key)
    local state = self:active()
    if state.keypressed then state:keypressed(key) end
end

return GameState
