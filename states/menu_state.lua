-- states/menu_state.lua
-- Title screen: animated title, a decorative snake swimming in the
-- background, the saved high score, and a prompt to start.
local Input = require("input")
local HighScore = require("highscore")
local Visuals = require("visuals")

local colors = Visuals.colors

local MenuState = {
    highScore = 0,
    lastScore = nil,
    time = 0,
}

function MenuState:enter(manager, lastScore)
    self.manager = manager
    self.lastScore = lastScore
    self.highScore = HighScore:load()
    self.enterTime = 0

    self.input = Input:new()
    local start = function() manager:switch("playing") end
    self.input:bind("return", start)
    self.input:bind("kpenter", start)
    self.input:bind("space", start)
    self.input:bind("escape", function()
        -- A web page can't quit, so ESC does nothing in the browser build
        if love and love.system.getOS() ~= "Web" then love.event.quit() end
    end)
end

function MenuState:update(dt)
    self.time = self.time + dt
    self.enterTime = self.enterTime + dt
end

function MenuState:keypressed(key)
    self.input:handleKey(key)
end

-- Position along a looping figure-eight, used for the demo snake
local function demoPoint(t)
    local W, H = Visuals.WIDTH, Visuals.HEIGHT
    return W / 2 + math.sin(t) * W * 0.36,
           H * 0.56 + math.sin(t * 2) * H * 0.2
end

function MenuState:drawDemoSnake()
    local points = {}
    local head = self.time * 0.6
    for i = 0, 40 do
        local x, y = demoPoint(head - i * 0.035)
        points[#points + 1] = {x = x, y = y}
    end
    local ax, ay = demoPoint(head + 0.01)
    local angle = math.atan2 and math.atan2(ay - points[1].y, ax - points[1].x)
        or math.atan(ay - points[1].y, ax - points[1].x)

    Visuals.drawTube(points, {
        headRadius = 15, tailRadius = 7,
        headColor = colors.snakeHead, tailColor = colors.snakeTail,
        alpha = 0.9,
    })
    Visuals.drawHead(points[1].x, points[1].y, angle, 15, self.time, false)
end

function MenuState:draw()
    local W, H = Visuals.WIDTH, Visuals.HEIGHT
    local appear = math.min(self.enterTime / 0.5, 1)
    local ease = 1 - (1 - appear) ^ 3

    Visuals.drawBackground(self.time)
    self:drawDemoSnake()

    -- Soft vignette behind the text for readability
    love.graphics.setColor(0.03, 0.04, 0.09, 0.35)
    love.graphics.rectangle("fill", 0, 0, W, H)

    -- Title: each letter bobs on its own phase and is tinted along a gradient
    local title = "SNAKE"
    local font = Visuals.font(96)
    love.graphics.setFont(font)
    local totalW = font:getWidth(title) + (#title - 1) * 8
    local x = (W - totalW) / 2
    local baseY = 110 - 30 * (1 - ease)
    for i = 1, #title do
        local ch = title:sub(i, i)
        local y = baseY + math.sin(self.time * 3 + i * 0.6) * 8
        local r, g, b = Visuals.lerpColor(colors.snakeHead, colors.snakeTail, (i - 1) / (#title - 1))
        love.graphics.setColor(0, 0, 0, 0.4 * ease)
        love.graphics.print(ch, x + 3, y + 5)
        love.graphics.setColor(r, g, b, ease)
        love.graphics.print(ch, x, y)
        x = x + font:getWidth(ch) + 8
    end
    Visuals.text("a Lua / LÖVE assignment", 0, 228, W, "center", 15, colors.muted, ease)

    -- Score card
    local pw, ph = 300, self.lastScore and 120 or 90
    local px, py = (W - pw) / 2, 300 + 20 * (1 - ease)
    Visuals.panel(px, py, pw, ph, ease)
    Visuals.text("HIGH SCORE", px, py + 18, pw, "center", 13, colors.muted, ease)
    Visuals.text(tostring(self.highScore), px, py + 36, pw, "center", 36, colors.gold, ease)
    if self.lastScore then
        Visuals.text("last game: " .. self.lastScore, px, py + 86, pw, "center", 14, colors.text, ease * 0.8)
    end

    -- Start prompt pulses gently
    local pulse = 0.6 + 0.4 * math.sin(self.time * 3.5)
    Visuals.text("Press ENTER to start", 0, H - 150, W, "center", 24, colors.text, ease * pulse)
    local hint = love.system.getOS() == "Web" and "Arrows / WASD move   ·   P pause"
        or "Arrows / WASD move   ·   P pause   ·   ESC quit"
    Visuals.text(hint, 0, H - 100, W, "center", 14,
        colors.muted, ease)
end

return MenuState
