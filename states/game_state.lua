-- states/game_state.lua
-- Playing state: owns a SnakeGame, maps keys to commands, and reacts to
-- game events (high score saving, particles, screen shake) through the
-- event system.
local Input = require("input")
local Events = require("events")
local HighScore = require("highscore")
local SnakeGame = require("snake_game")
local Visuals = require("visuals")

local colors = Visuals.colors
local BX, BY = Visuals.BOARD_X, Visuals.BOARD_Y

local PlayState = {
    game = nil,
    paused = false,
    highScore = 0,
    newRecord = false,
    fx = nil,
    shake = 0,
    flash = 0,
    scoreBump = 0,
    overTime = 0,
    pauseFade = 0,
    time = 0,
}

local function boardCenter(pos)
    return BX + (pos.x + 0.5) * SnakeGame.CELL, BY + (pos.y + 0.5) * SnakeGame.CELL
end

-- Subscribed once at module load; observers don't need to know who ends
-- the game or eats the food, they only react to the events.
Events:subscribe("game_over", function(data)
    PlayState.highScore, PlayState.newRecord = HighScore:submit(data.score)
    PlayState.shake = 0.45
    PlayState.flash = 1
    PlayState.overTime = 0
    if PlayState.fx and data.position then
        local x, y = boardCenter(data.position)
        PlayState.fx:burst(x, y, colors.danger, 40, 260)
        PlayState.fx:burst(x, y, colors.snakeHead, 25, 180)
    end
end)

Events:subscribe("food_eaten", function(data)
    PlayState.scoreBump = 1
    if PlayState.fx then
        local x, y = boardCenter(data.position)
        PlayState.fx:burst(x, y, colors.apple, 22, 220)
        PlayState.fx:burst(x, y, colors.gold, 10, 140)
        PlayState.fx:popText(x, y - 10, "+1", colors.gold)
    end
end)

function PlayState:enter(manager)
    self.manager = manager
    self:restart()

    self.input = Input:new()
    local function turn(dx, dy)
        return function()
            if not self.paused then self:changeDirection(dx, dy) end
        end
    end
    for _, key in ipairs({"up", "w"}) do self.input:bind(key, turn(0, -1)) end
    for _, key in ipairs({"down", "s"}) do self.input:bind(key, turn(0, 1)) end
    for _, key in ipairs({"left", "a"}) do self.input:bind(key, turn(-1, 0)) end
    for _, key in ipairs({"right", "d"}) do self.input:bind(key, turn(1, 0)) end

    self.input:bind("p", function()
        if not self.game.gameOver then self.paused = not self.paused end
    end)
    self.input:bind("escape", function()
        manager:switch("menu", self.game.score)
    end)

    -- Separate bindings that are only active on the game over screen
    self.gameOverInput = Input:new()
    self.gameOverInput:bind("space", function() self:restart() end)
    self.gameOverInput:bind("return", function() self:restart() end)
    self.gameOverInput:bind("escape", function()
        manager:switch("menu", self.game.score)
    end)
end

function PlayState:restart()
    self.game = SnakeGame:new()
    self.paused = false
    self.newRecord = false
    self.highScore = HighScore:load()
    self.fx = Visuals.Particles:new()
    self.shake, self.flash, self.scoreBump = 0, 0, 0
    self.overTime, self.pauseFade = 0, 0
end

-- Kept so the starter main.lua (gameState.states.playing:changeDirection)
-- also works
function PlayState:changeDirection(dx, dy)
    return self.game:changeDirection(dx, dy)
end

function PlayState:update(dt)
    self.time = self.time + dt
    self.fx:update(dt)
    self.shake = math.max(0, self.shake - dt)
    self.flash = math.max(0, self.flash - dt * 3)
    self.scoreBump = math.max(0, self.scoreBump - dt * 4)
    if self.game.gameOver then self.overTime = self.overTime + dt end

    -- Fade the pause overlay in/out instead of popping
    local target = self.paused and 1 or 0
    self.pauseFade = self.pauseFade + (target - self.pauseFade) * (1 - math.exp(-14 * dt))

    if self.paused then return end
    self.game:update(dt)
end

function PlayState:keypressed(key)
    if self.game.gameOver then
        -- Short delay so a key held during the crash doesn't skip the screen
        if self.overTime > 0.35 then self.gameOverInput:handleKey(key) end
    else
        self.input:handleKey(key)
    end
end

function PlayState:drawHud()
    local W = Visuals.WIDTH
    Visuals.text("SCORE", BX + 4, 14, 200, "left", 13, colors.muted)
    local bump = 1 + 0.35 * self.scoreBump
    love.graphics.push()
    love.graphics.translate(BX + 4, 32)
    love.graphics.scale(bump, bump)
    Visuals.text(tostring(self.game.score), 0, -4, 200, "left", 32, colors.text)
    love.graphics.pop()

    local best = math.max(self.highScore, self.game.score)
    Visuals.text("BEST", W - BX - 204, 14, 200, "right", 13, colors.muted)
    Visuals.text(tostring(best), W - BX - 204, 28, 200, "right", 32, colors.gold)

    Visuals.text("P pause  ·  ESC menu", 0, 34, W, "center", 13, colors.muted, 0.7)
end

function PlayState:drawGameOver()
    local W, H = Visuals.WIDTH, Visuals.HEIGHT
    local a = math.min(self.overTime / 0.4, 1)
    local ease = 1 - (1 - a) ^ 3

    love.graphics.setColor(0.03, 0.04, 0.09, 0.65 * ease)
    love.graphics.rectangle("fill", 0, 0, W, H)

    local pw, ph = 380, 260
    local px = (W - pw) / 2
    local py = (H - ph) / 2 + 30 * (1 - ease)
    Visuals.panel(px, py, pw, ph, ease)

    Visuals.text("GAME OVER", px, py + 26, pw, "center", 40, colors.danger, ease)
    Visuals.text("SCORE", px, py + 92, pw / 2, "center", 13, colors.muted, ease)
    Visuals.text(tostring(self.game.score), px, py + 108, pw / 2, "center", 40, colors.text, ease)
    Visuals.text("BEST", px + pw / 2, py + 92, pw / 2, "center", 13, colors.muted, ease)
    Visuals.text(tostring(self.highScore), px + pw / 2, py + 108, pw / 2, "center", 40, colors.gold, ease)

    if self.newRecord then
        local glow = 0.75 + 0.25 * math.sin(self.time * 6)
        Visuals.text("NEW HIGH SCORE!", px, py + 168, pw, "center", 20, colors.gold, ease * glow)
    end
    local blink = 0.55 + 0.45 * math.sin(self.time * 4)
    Visuals.text("SPACE to play again  ·  ESC for menu", px, py + 212, pw, "center", 14,
        colors.text, ease * blink)
end

function PlayState:draw()
    local W, H = Visuals.WIDTH, Visuals.HEIGHT
    Visuals.drawBackground(self.time)

    love.graphics.push()
    if self.shake > 0 then
        local s = self.shake * 18
        love.graphics.translate((math.random() - 0.5) * s, (math.random() - 0.5) * s)
    end

    Visuals.drawBoard(BX, BY, SnakeGame.GRID, SnakeGame.CELL)
    self.game:draw(BX, BY)
    self.fx:draw()
    love.graphics.pop()

    self:drawHud()

    if self.flash > 0 then
        love.graphics.setColor(colors.danger[1], colors.danger[2], colors.danger[3], 0.35 * self.flash)
        love.graphics.rectangle("fill", 0, 0, W, H)
    end

    if self.pauseFade > 0.01 then
        local a = self.pauseFade
        love.graphics.setColor(0.03, 0.04, 0.09, 0.6 * a)
        love.graphics.rectangle("fill", 0, 0, W, H)
        Visuals.text("PAUSED", 0, H / 2 - 40, W, "center", 48, colors.text, a)
        Visuals.text("Press P to resume", 0, H / 2 + 20, W, "center", 16, colors.muted, a)
    end

    if self.game.gameOver then
        self:drawGameOver()
    end
end

return PlayState
