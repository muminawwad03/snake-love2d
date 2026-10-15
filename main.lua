-- main.lua
-- Entry point.
--   love .         -> play the game (LÖVE 11.x, window set up in conf.lua)
--   lua main.lua   -> no window available, so run a headless self-test of
--                     every module instead (needs Lua 5.4 for <close>)

-- Let require() find our modules even when started from another folder
local dir = (arg and arg[0] or ""):match("^(.*[/\\])") or ""
package.path = dir .. "?.lua;" .. package.path

if not love then
    -- Plain Lua: run the checklist in tests.lua and exit with its result
    local ok = dofile(dir .. "tests.lua")
    os.exit(ok and 0 or 1)
end

local GameState = require("gamestate")

local gameState

function love.load()
    love.graphics.setDefaultFilter("linear", "linear")
    love.graphics.setLineStyle("smooth")
    love.math.setRandomSeed(os.time())
    math.randomseed(os.time())
    gameState = GameState:new()
end

function love.update(dt)
    -- Cap dt so a hitch (window drag, breakpoint) can't make the snake
    -- jump several cells in one frame
    gameState:update(math.min(dt, 1 / 20))
end

function love.draw()
    gameState:draw()
end

function love.keypressed(key, scancode, isrepeat)
    if isrepeat then return end
    -- Each state routes keys through its own Input (command pattern)
    gameState:keypressed(key)
end
