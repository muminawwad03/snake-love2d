-- snake_game.lua
-- Core Snake logic. Every piece of the board (snake segments and food) is
-- an Entity built from Position / Movement / Renderer components, and all
-- grid math uses Vector2 metamethods (+ for stepping, == for collisions).
--
-- Smooth movement: the logic still moves one whole cell per step on a
-- fixed timer, but each segment also remembers the cell it came from
-- ("Previous" component). Every frame the renderer interpolates between
-- the two using how far we are into the current step, so the snake glides
-- at the display refresh rate instead of jumping a cell at a time.
local Entity = require("entity")
local Vector2 = require("vector2")
local Events = require("events")
local Visuals = require("visuals")

local Position = Entity.Components.Position
local Movement = Entity.Components.Movement
local Renderer = Entity.Components.Renderer

local SnakeGame = {}
SnakeGame.__index = SnakeGame

SnakeGame.GRID = 20          -- board is GRID x GRID cells
SnakeGame.CELL = 30          -- pixels per cell
SnakeGame.START_STEP = 0.12  -- seconds per move at the start
SnakeGame.MIN_STEP = 0.06    -- fastest the snake can go
SnakeGame.SPEEDUP = 0.002    -- step time removed per food eaten

local function random(lo, hi)
    if love and love.math then return love.math.random(lo, hi) end
    return math.random(lo, hi)
end

local function newSegment(x, y, isHead)
    local color = isHead and Visuals.colors.snakeHead or Visuals.colors.snakeTail
    local segment = Entity:new()
        :addComponent("Position", Position(x, y))
        :addComponent("Previous", Position(x, y))
        :addComponent("Renderer", Renderer(color, isHead and 0.82 or 0.5))
    if isHead then
        segment:addComponent("Movement", Movement(1, 0))
    end
    return segment
end

function SnakeGame:new()
    local game = {
        snake = {
            newSegment(10, 10, true),  -- Starting position (head)
            newSegment(9, 10),
            newSegment(8, 10),
        },
        direction = Vector2:new(1, 0),
        food = Entity:new()
            :addComponent("Position", Position(15, 15))
            :addComponent("Renderer", Renderer(Visuals.colors.apple, 0.8)),
        score = 0,
        gameOver = false,
        timer = 0,
        stepTime = SnakeGame.START_STEP,
        -- Presentation-only state
        time = 0,
        foodAge = 0,
        headAngle = 0,
    }
    -- Turns requested by input, applied one per step. Queueing (up to 2)
    -- means quick presses like up+left are never lost, and validating each
    -- against the previous turn stops the snake reversing into itself.
    game.turnQueue = {}
    return setmetatable(game, SnakeGame)
end

function SnakeGame:head()
    return self.snake[1]
end

function SnakeGame:isInside(pos)
    return pos.x >= 0 and pos.x < self.GRID and pos.y >= 0 and pos.y < self.GRID
end

-- True if any segment from 1..lastIndex sits on pos
function SnakeGame:occupies(pos, lastIndex)
    for i = 1, lastIndex or #self.snake do
        if self.snake[i]:getComponent("Position") == pos then
            return true
        end
    end
    return false
end

function SnakeGame:spawnFood()
    local free = {}
    for y = 0, self.GRID - 1 do
        for x = 0, self.GRID - 1 do
            local cell = Vector2:new(x, y)
            if not self:occupies(cell) then
                free[#free + 1] = cell
            end
        end
    end
    if #free == 0 then
        -- Board is full: the player has won
        self.gameOver = true
        Events:emit("game_over", {score = self.score, won = true})
        return
    end
    self.food:addComponent("Position", free[random(1, #free)])
    self.foodAge = 0
end

-- Advances the snake one cell. Called on a fixed timer from update().
function SnakeGame:step()
    if #self.turnQueue > 0 then
        self.direction = table.remove(self.turnQueue, 1)
    end
    local head = self:head()
    head:getComponent("Movement").x = self.direction.x
    head:getComponent("Movement").y = self.direction.y

    local newPos = head:getComponent("Position") + head:getComponent("Movement")
    local eating = newPos == self.food:getComponent("Position")

    -- Wall collision
    if not self:isInside(newPos) then
        return self:endGame("wall")
    end

    -- Self collision. The tail moves out of the way this step unless we
    -- are growing, so it only counts when eating.
    local checkUpTo = eating and #self.snake or #self.snake - 1
    if self:occupies(newPos, checkUpTo) then
        return self:endGame("self")
    end

    -- Remember where every segment was, for interpolated drawing
    for _, segment in ipairs(self.snake) do
        segment:addComponent("Previous", segment:getComponent("Position"):copy())
    end

    -- Grow by adding a segment where the tail currently is
    if eating then
        local tailPos = self.snake[#self.snake]:getComponent("Position")
        self.snake[#self.snake + 1] = newSegment(tailPos.x, tailPos.y)
    end

    -- Each segment takes the position of the one ahead of it
    for i = #self.snake, 2, -1 do
        local ahead = self.snake[i - 1]:getComponent("Position")
        self.snake[i]:addComponent("Position", ahead:copy())
    end
    head:addComponent("Position", newPos)

    -- Handle food eating
    if eating then
        self.score = self.score + 1
        self.stepTime = math.max(self.MIN_STEP, self.stepTime - self.SPEEDUP)
        Events:emit("food_eaten", {score = self.score, position = newPos})
        self:spawnFood()
    end
end

function SnakeGame:endGame(reason)
    self.gameOver = true
    Events:emit("game_over", {score = self.score, reason = reason,
        position = self:head():getComponent("Position")})
end

function SnakeGame:update(dt)
    self.time = self.time + dt
    self.foodAge = self.foodAge + dt

    -- Turn the head towards its travel direction smoothly
    local move = self:head():getComponent("Movement")
    local target = math.atan2 and math.atan2(move.y, move.x) or math.atan(move.y, move.x)
    self.headAngle = Visuals.lerpAngle(self.headAngle, target, 1 - math.exp(-25 * dt))

    if self.gameOver then return end
    self.timer = self.timer + dt
    while self.timer >= self.stepTime and not self.gameOver do
        self.timer = self.timer - self.stepTime
        self:step()
    end
end

-- How far (0..1) we are between the previous step and the next one
function SnakeGame:stepProgress()
    if self.gameOver then return 1 end
    return math.min(self.timer / self.stepTime, 1)
end

-- Pixel centre of a grid cell
function SnakeGame:cellCenter(pos, ox, oy)
    return ox + (pos.x + 0.5) * self.CELL, oy + (pos.y + 0.5) * self.CELL
end

-- Interpolated pixel centre of a segment
function SnakeGame:segmentCenter(segment, alpha, ox, oy)
    local prev = segment:getComponent("Previous")
    local cur = segment:getComponent("Position")
    local x = Visuals.lerp(prev.x, cur.x, alpha)
    local y = Visuals.lerp(prev.y, cur.y, alpha)
    return ox + (x + 0.5) * self.CELL, oy + (y + 0.5) * self.CELL
end

-- Builds the polyline the body follows: the head and tail slide between
-- cells, every joint in between sits exactly on a cell centre (so corners
-- stay sharp and in place while the snake flows through them).
function SnakeGame:bodyPath(ox, oy)
    local alpha = self:stepProgress()
    local n = #self.snake
    local points = {}

    local hx, hy = self:segmentCenter(self.snake[1], alpha, ox, oy)
    points[1] = {x = hx, y = hy}
    for i = 2, n do
        local x, y = self:cellCenter(self.snake[i]:getComponent("Position"), ox, oy)
        points[#points + 1] = {x = x, y = y}
    end
    -- Tail end: slides from where the tail was towards its new cell
    local tail = self.snake[n]:getComponent("Previous")
    local tx, ty = self:cellCenter(tail, ox, oy)
    local cx, cy = points[#points].x, points[#points].y
    points[#points + 1] = {x = Visuals.lerp(tx, cx, alpha), y = Visuals.lerp(ty, cy, alpha)}
    return points
end

-- Draws food and snake with the board's top-left corner at (ox, oy)
function SnakeGame:draw(ox, oy)
    ox, oy = ox or 0, oy or 0
    local cell = self.CELL

    -- Food
    local foodPos = self.food:getComponent("Position")
    local fx, fy = self:cellCenter(foodPos, ox, oy)
    Visuals.drawApple(fx, fy, cell, self.time, self.foodAge * 3)

    -- Snake: colours and thickness come from the head/tail Renderers
    local headR = self:head():getComponent("Renderer")
    local tailR = self.snake[#self.snake]:getComponent("Renderer")
    local headColor, tailColor = headR.color, tailR.color
    if self.gameOver then
        -- Desaturate on death
        local function grey(c)
            local l = (c[1] + c[2] + c[3]) / 3
            return {Visuals.lerp(c[1], l, 0.6), Visuals.lerp(c[2], l, 0.6), Visuals.lerp(c[3], l, 0.6)}
        end
        headColor, tailColor = grey(headColor), grey(tailColor)
    end

    local points = self:bodyPath(ox, oy)
    Visuals.drawTube(points, {
        headRadius = cell * headR.size / 2,
        tailRadius = cell * tailR.size / 2,
        headColor = headColor,
        tailColor = tailColor,
    })
    Visuals.drawHead(points[1].x, points[1].y, self.headAngle,
        cell * headR.size / 2, self.time, self.gameOver)
end

-- Ignores reversals (e.g. right -> left) which would be instant death
function SnakeGame:changeDirection(dx, dy)
    local wanted = Vector2:new(dx, dy)
    local last = self.turnQueue[#self.turnQueue] or self.direction
    if #self.turnQueue >= 2 or wanted == -last or wanted == last then
        return false
    end
    table.insert(self.turnQueue, wanted)
    return true
end

return SnakeGame
