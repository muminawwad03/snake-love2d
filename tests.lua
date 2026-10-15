-- tests.lua
-- Headless checks for the assignment's Quick Test Checklist. Run through
-- `lua main.lua` (or `lua tests.lua`). Returns true when everything passes.
local Vector2 = require("vector2")
local Entity = require("entity")
local Events = require("events")
local Input = require("input")
local HighScore = require("highscore")
local SnakeGame = require("snake_game")
local GameState = require("gamestate")

local passed, failed = 0, 0

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("[PASS] " .. name)
    else
        failed = failed + 1
        print("[FAIL] " .. name .. "\n       " .. tostring(err))
    end
end

local function check(cond, msg)
    if not cond then error(msg or "check failed", 2) end
end

-- Keep the player's real high score file untouched
local realPath = HighScore.path
HighScore.path = os.tmpname()

test("Game starts with menu", function()
    local gs = GameState:new()
    check(gs.current == "menu", "initial state should be menu")
    gs:keypressed("return")
    check(gs.current == "playing", "ENTER should start the game")
    gs:keypressed("escape")
    check(gs.current == "menu", "ESC should return to menu")
end)

test("Vector2 math operations work", function()
    local a, b = Vector2:new(1, 2), Vector2:new(3, 4)
    check(a + b == Vector2:new(4, 6), "addition")
    check(b - a == Vector2:new(2, 2), "subtraction")
    check(a * 2 == Vector2:new(2, 4) and 2 * a == Vector2:new(2, 4), "scaling")
    check(-a == Vector2:new(-1, -2), "negation")
    check(a ~= b, "inequality")
    check(tostring(a) == "Vector2(1, 2)", "tostring: " .. tostring(a))
    check(Vector2:new(3, 4):length() == 5, "length")
end)

test("Entity components", function()
    local e = Entity:new()
        :addComponent("Position", Entity.Components.Position(1, 2))
        :addComponent("Movement", Entity.Components.Movement(1, 0))
        :addComponent("Renderer", Entity.Components.Renderer({1, 0, 0}, 1))
    check(e:hasComponent("Position") and e:hasComponent("Renderer"))
    check(not e:hasComponent("Health"))
    check(e:getComponent("Position") + e:getComponent("Movement") == Vector2:new(2, 2))
    e:removeComponent("Movement")
    check(not e:hasComponent("Movement"))
end)

test("Snake moves and can change direction", function()
    local g = SnakeGame:new()
    local head = g:head():getComponent("Position")
    check(head == Vector2:new(10, 10))
    g:update(g.stepTime)
    check(g:head():getComponent("Position") == Vector2:new(11, 10), "moves right")
    check(#g.snake == 3, "length unchanged when not eating")
    check(not g:changeDirection(-1, 0), "reversing must be ignored")
    check(g:changeDirection(0, 1), "turning down allowed")
    g:update(g.stepTime)
    check(g:head():getComponent("Position") == Vector2:new(11, 11), "moves down")
    check(g.snake[2]:getComponent("Position") == Vector2:new(11, 10), "body follows")
end)

test("Food spawns and increases score", function()
    local g = SnakeGame:new()
    local eaten
    local unsubscribe = Events:subscribe("food_eaten", function(d) eaten = d.score end)
    g.food:addComponent("Position", Vector2:new(11, 10))
    g:step()
    unsubscribe()
    check(g.score == 1, "score should be 1")
    check(eaten == 1, "food_eaten event should fire")
    check(#g.snake == 4, "snake should grow")
    local food = g.food:getComponent("Position")
    check(not g:occupies(food), "food must not spawn on the snake")
    check(g:isInside(food), "food must be on the board")
end)

test("High score saves/loads", function()
    os.remove(HighScore.path)
    check(HighScore:load() == 0, "missing file loads as 0")
    HighScore:save(42)
    check(HighScore:load() == 42, "saved value reloads")
    local best, isNew = HighScore:submit(10)
    check(best == 42 and not isNew, "lower score keeps record")
    best, isNew = HighScore:submit(50)
    check(best == 50 and isNew and HighScore:load() == 50, "higher score replaces record")
    print("       (using <close>: " .. tostring(HighScore.usesToBeClosed) .. ", " .. _VERSION .. ")")
end)

test("Game over detection works (wall)", function()
    local g = SnakeGame:new()
    local reason
    local unsubscribe = Events:subscribe("game_over", function(d) reason = d.reason end)
    for _ = 1, 20 do g:step() if g.gameOver then break end end
    unsubscribe()
    check(g.gameOver and reason == "wall", "should hit the right wall")
    check(g:head():getComponent("Position").x == SnakeGame.GRID - 1, "head stops at last cell")
end)

test("Game over detection works (self)", function()
    local g = SnakeGame:new()
    -- Grow to length 5, then turn in a tight square into our own body
    for i = 1, 2 do
        g.food:addComponent("Position", g:head():getComponent("Position") + g.direction)
        g:step()
    end
    check(#g.snake == 5)
    g.food:addComponent("Position", Vector2:new(0, 0))
    g:changeDirection(0, 1); g:step()
    g:changeDirection(-1, 0); g:step()
    g:changeDirection(0, -1); g:step()
    check(g.gameOver, "should collide with own body")
end)

test("Event system (observer pattern)", function()
    local got = {}
    local off = Events:subscribe("ping", function(d) got[#got + 1] = d.n end)
    Events:subscribe("ping", function(d) got[#got + 1] = d.n * 10 end)
    Events:emit("ping", {n = 1})
    off()
    Events:emit("ping", {n = 2})
    check(#got == 3 and got[1] == 1 and got[2] == 10 and got[3] == 20)
    Events:clear("ping")
end)

test("Input command pattern", function()
    local input, hits = Input:new(), 0
    input:bind("x", function() hits = hits + 1 end)
    check(input:handleKey("x") and not input:handleKey("y"))
    check(hits == 1)
end)

os.remove(HighScore.path)
HighScore.path = realPath

print(string.format("\n%d passed, %d failed", passed, failed))
return failed == 0
