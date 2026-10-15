-- visuals.lua
-- Shared look-and-feel: palette, layout, fonts and drawing helpers
-- (background, board, snake tube, apple, particles, panels).
local Visuals = {}

-- Layout -----------------------------------------------------------------

Visuals.WIDTH = 640
Visuals.HEIGHT = 700
Visuals.BOARD_X = 20
Visuals.BOARD_Y = 80

-- Palette ----------------------------------------------------------------

local function hex(h, a)
    h = h:gsub("#", "")
    return {
        tonumber(h:sub(1, 2), 16) / 255,
        tonumber(h:sub(3, 4), 16) / 255,
        tonumber(h:sub(5, 6), 16) / 255,
        a or 1,
    }
end
Visuals.hex = hex

Visuals.colors = {
    bgTop     = hex("#161b33"),
    bgBottom  = hex("#0a0d1a"),
    boardA    = hex("#1b2240"),
    boardB    = hex("#1f2748"),
    boardEdge = hex("#2c3766"),
    snakeHead = hex("#8ef5a4"),
    snakeTail = hex("#1fa59b"),
    apple     = hex("#ff4f6d"),
    appleDark = hex("#c42a4a"),
    leaf      = hex("#5ee08a"),
    stem      = hex("#7a4a2a"),
    text      = hex("#e8ecf8"),
    muted     = hex("#8b93b8"),
    gold      = hex("#ffd166"),
    danger    = hex("#ff5c7a"),
}

-- Math helpers -----------------------------------------------------------

function Visuals.lerp(a, b, t)
    return a + (b - a) * t
end

function Visuals.lerpColor(c1, c2, t, alpha)
    return Visuals.lerp(c1[1], c2[1], t), Visuals.lerp(c1[2], c2[2], t),
           Visuals.lerp(c1[3], c2[3], t), alpha or 1
end

-- Shortest-path angle interpolation, used to turn the head smoothly
function Visuals.lerpAngle(a, b, t)
    local diff = (b - a + math.pi) % (2 * math.pi) - math.pi
    return a + diff * t
end

-- Fonts (created lazily, LÖVE must be initialised first) ------------------

local fonts = {}
function Visuals.font(size)
    if not fonts[size] then
        fonts[size] = love.graphics.newFont(size)
    end
    return fonts[size]
end

-- Background -------------------------------------------------------------

local bgMesh
function Visuals.drawBackground(time)
    if not bgMesh then
        local top, bottom = Visuals.colors.bgTop, Visuals.colors.bgBottom
        local w, h = Visuals.WIDTH, Visuals.HEIGHT
        bgMesh = love.graphics.newMesh({
            {0, 0, 0, 0, top[1], top[2], top[3], 1},
            {w, 0, 1, 0, top[1], top[2], top[3], 1},
            {w, h, 1, 1, bottom[1], bottom[2], bottom[3], 1},
            {0, h, 0, 1, bottom[1], bottom[2], bottom[3], 1},
        }, "fan", "static")
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(bgMesh)

    -- Slowly drifting soft light blobs
    love.graphics.setBlendMode("add")
    for i = 1, 3 do
        local x = Visuals.WIDTH * (0.5 + 0.4 * math.sin(time * 0.13 * i + i * 2))
        local y = Visuals.HEIGHT * (0.5 + 0.4 * math.cos(time * 0.11 * i + i))
        for r = 1, 6 do
            love.graphics.setColor(0.25, 0.35, 0.8, 0.012)
            love.graphics.circle("fill", x, y, 60 + r * 35)
        end
    end
    love.graphics.setBlendMode("alpha")
end

-- Board: rounded panel with a subtle checkerboard
function Visuals.drawBoard(x, y, grid, cell)
    local size = grid * cell
    local c = Visuals.colors

    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", x - 6, y - 2, size + 12, size + 14, 16, 16)
    love.graphics.setColor(c.boardEdge)
    love.graphics.rectangle("fill", x - 6, y - 6, size + 12, size + 12, 16, 16)

    love.graphics.setColor(c.boardA)
    love.graphics.rectangle("fill", x, y, size, size, 10, 10)
    love.graphics.setColor(c.boardB)
    for gy = 0, grid - 1 do
        for gx = 0, grid - 1 do
            if (gx + gy) % 2 == 0 then
                -- Corner tiles keep the board's rounded corners
                local corner = (gx == 0 or gx == grid - 1) and (gy == 0 or gy == grid - 1)
                love.graphics.rectangle("fill", x + gx * cell, y + gy * cell, cell, cell,
                    corner and 6 or 0, corner and 6 or 0)
            end
        end
    end
end

-- Snake body -------------------------------------------------------------

-- Draws a smooth tapered tube through `points` ({x, y} pixel centres,
-- head first). The path is resampled by arc length and filled with
-- overlapping circles, giving round joints, a head-to-tail colour
-- gradient and a taper towards the tail.
function Visuals.drawTube(points, opts)
    local n = #points
    if n == 0 then return end
    local headR, tailR = opts.headRadius, opts.tailRadius
    local headC, tailC = opts.headColor, opts.tailColor
    local spacing = opts.spacing or 2.5

    local lengths, total = {0}, 0
    for i = 2, n do
        local dx, dy = points[i].x - points[i - 1].x, points[i].y - points[i - 1].y
        total = total + math.sqrt(dx * dx + dy * dy)
        lengths[i] = total
    end

    local function sampleAll(fn)
        if total == 0 then
            fn(points[1].x, points[1].y, 0)
            return
        end
        local seg = 2
        local d = total
        -- Walk tail -> head so the head-end circles are drawn on top
        while d >= 0 do
            while seg < n and lengths[seg] < d do seg = seg + 1 end
            while seg > 2 and lengths[seg - 1] > d do seg = seg - 1 end
            local a, b = points[seg - 1], points[seg]
            local segLen = lengths[seg] - lengths[seg - 1]
            local t = segLen > 0 and (d - lengths[seg - 1]) / segLen or 0
            fn(Visuals.lerp(a.x, b.x, t), Visuals.lerp(a.y, b.y, t), d / total)
            d = d - spacing
        end
        fn(points[1].x, points[1].y, 0)
    end

    local function radius(f) return Visuals.lerp(headR, tailR, f) end

    -- 1. drop shadow
    love.graphics.setColor(0, 0, 0, 0.28)
    sampleAll(function(x, y, f)
        love.graphics.circle("fill", x + 2, y + 5, radius(f), 20)
    end)
    -- 2. darker outline
    sampleAll(function(x, y, f)
        local r, g, b = Visuals.lerpColor(headC, tailC, f)
        love.graphics.setColor(r * 0.55, g * 0.55, b * 0.6, 1)
        love.graphics.circle("fill", x, y, radius(f) + 1.5, 20)
    end)
    -- 3. body
    sampleAll(function(x, y, f)
        love.graphics.setColor(Visuals.lerpColor(headC, tailC, f, opts.alpha))
        love.graphics.circle("fill", x, y, radius(f), 20)
    end)
    -- 4. glossy highlight along the top
    sampleAll(function(x, y, f)
        local r = radius(f)
        love.graphics.setColor(1, 1, 1, 0.13)
        love.graphics.circle("fill", x - r * 0.15, y - r * 0.35, r * 0.45, 14)
    end)
end

-- Head details: eyes looking along `angle`, blink and tongue flick
function Visuals.drawHead(x, y, angle, radius, time, dead)
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(angle)

    -- Tongue flicks out briefly every couple of seconds
    local flick = (time % 2.3)
    if not dead and flick < 0.25 then
        local len = radius * (0.6 + 0.6 * math.sin(flick / 0.25 * math.pi))
        love.graphics.setColor(Visuals.colors.danger)
        love.graphics.setLineWidth(2.5)
        love.graphics.line(radius * 0.8, 0, radius * 0.8 + len, 0)
        love.graphics.line(radius * 0.8 + len, 0, radius * 0.8 + len + 4, -3)
        love.graphics.line(radius * 0.8 + len, 0, radius * 0.8 + len + 4, 3)
        love.graphics.setLineWidth(1)
    end

    local blink = (time % 3.7) < 0.12
    for _, side in ipairs({-1, 1}) do
        local ex, ey = radius * 0.3, side * radius * 0.48
        love.graphics.setColor(1, 1, 1)
        if dead then
            love.graphics.setColor(0.1, 0.1, 0.15)
            love.graphics.setLineWidth(2.5)
            local s = radius * 0.22
            love.graphics.line(ex - s, ey - s, ex + s, ey + s)
            love.graphics.line(ex - s, ey + s, ex + s, ey - s)
            love.graphics.setLineWidth(1)
        elseif blink then
            love.graphics.setColor(0.1, 0.1, 0.15)
            love.graphics.setLineWidth(2.5)
            love.graphics.line(ex - radius * 0.2, ey, ex + radius * 0.2, ey)
            love.graphics.setLineWidth(1)
        else
            love.graphics.circle("fill", ex, ey, radius * 0.3, 16)
            love.graphics.setColor(0.08, 0.08, 0.14)
            love.graphics.circle("fill", ex + radius * 0.1, ey, radius * 0.16, 12)
            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.circle("fill", ex + radius * 0.14, ey - radius * 0.06, radius * 0.06, 8)
        end
    end
    love.graphics.pop()
end

-- Food -------------------------------------------------------------------

-- `appear` goes 0 -> 1 after the apple spawns (springy pop-in)
function Visuals.drawApple(x, y, cell, time, appear)
    local c = Visuals.colors
    local t = math.min(appear, 1)
    -- Overshooting ease-out: grows a little past full size then settles
    local pop = 1 + 2.70158 * (t - 1) ^ 3 + 1.70158 * (t - 1) ^ 2
    local pulse = 1 + 0.05 * math.sin(time * 5)
    local r = cell * 0.36 * pulse * pop
    if r <= 0 then return end

    -- Glow
    love.graphics.setBlendMode("add")
    for i = 1, 5 do
        love.graphics.setColor(c.apple[1], c.apple[2], c.apple[3], 0.05)
        love.graphics.circle("fill", x, y, r + i * 5)
    end
    love.graphics.setBlendMode("alpha")

    -- Shadow, body, shading, shine
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.ellipse("fill", x + 2, y + r * 0.9, r * 0.85, r * 0.3)
    love.graphics.setColor(c.appleDark)
    love.graphics.circle("fill", x, y + 1, r, 24)
    love.graphics.setColor(c.apple)
    love.graphics.circle("fill", x - r * 0.08, y - r * 0.05, r * 0.9, 24)
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.ellipse("fill", x - r * 0.38, y - r * 0.35, r * 0.22, r * 0.14)

    -- Stem and leaf, gently swaying
    love.graphics.setColor(c.stem)
    love.graphics.setLineWidth(2.5)
    love.graphics.line(x, y - r * 0.8, x + 1.5, y - r * 1.25)
    love.graphics.setLineWidth(1)
    love.graphics.push()
    love.graphics.translate(x + 2, y - r * 1.1)
    love.graphics.rotate(-0.6 + 0.15 * math.sin(time * 2.5))
    love.graphics.setColor(c.leaf)
    love.graphics.ellipse("fill", r * 0.35, 0, r * 0.38, r * 0.17)
    love.graphics.pop()
end

-- Particles --------------------------------------------------------------

local Particles = {}
Particles.__index = Particles
Visuals.Particles = Particles

function Particles:new()
    return setmetatable({list = {}, texts = {}}, Particles)
end

function Particles:burst(x, y, color, count, speed)
    for _ = 1, count do
        local angle = math.random() * math.pi * 2
        local v = speed * (0.4 + math.random() * 0.8)
        local life = 0.4 + math.random() * 0.4
        table.insert(self.list, {
            x = x, y = y,
            vx = math.cos(angle) * v, vy = math.sin(angle) * v,
            life = life, maxLife = life,
            size = 2 + math.random() * 3.5,
            color = color,
        })
    end
end

function Particles:popText(x, y, text, color)
    table.insert(self.texts, {x = x, y = y, text = text, color = color, life = 0.9, maxLife = 0.9})
end

function Particles:update(dt)
    local drag = math.exp(-4 * dt)
    for i = #self.list, 1, -1 do
        local p = self.list[i]
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(self.list, i)
        else
            p.vx, p.vy = p.vx * drag, p.vy * drag + 120 * dt
            p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
        end
    end
    for i = #self.texts, 1, -1 do
        local t = self.texts[i]
        t.life = t.life - dt
        t.y = t.y - 45 * dt
        if t.life <= 0 then table.remove(self.texts, i) end
    end
end

function Particles:draw()
    love.graphics.setBlendMode("add")
    for _, p in ipairs(self.list) do
        local f = p.life / p.maxLife
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], f)
        love.graphics.circle("fill", p.x, p.y, p.size * (0.5 + 0.5 * f))
    end
    love.graphics.setBlendMode("alpha")

    love.graphics.setFont(Visuals.font(20))
    for _, t in ipairs(self.texts) do
        local f = t.life / t.maxLife
        love.graphics.setColor(t.color[1], t.color[2], t.color[3], math.min(1, f * 2))
        love.graphics.printf(t.text, t.x - 40, t.y - 12, 80, "center")
    end
end

-- UI ---------------------------------------------------------------------

-- Text with a soft drop shadow
function Visuals.text(str, x, y, width, align, size, color, alpha)
    love.graphics.setFont(Visuals.font(size))
    love.graphics.setColor(0, 0, 0, 0.45 * (alpha or 1))
    love.graphics.printf(str, x + 2, y + 3, width, align)
    local c = color or Visuals.colors.text
    love.graphics.setColor(c[1], c[2], c[3], (c[4] or 1) * (alpha or 1))
    love.graphics.printf(str, x, y, width, align)
end

function Visuals.panel(x, y, w, h, alpha)
    alpha = alpha or 1
    love.graphics.setColor(0, 0, 0, 0.35 * alpha)
    love.graphics.rectangle("fill", x, y + 6, w, h, 18, 18)
    love.graphics.setColor(0.09, 0.11, 0.22, 0.94 * alpha)
    love.graphics.rectangle("fill", x, y, w, h, 18, 18)
    love.graphics.setColor(1, 1, 1, 0.08 * alpha)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h, 18, 18)
    love.graphics.setLineWidth(1)
end

return Visuals
