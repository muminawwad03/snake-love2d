-- vector2.lua
-- Small 2D vector class. Metamethods let us write game math naturally:
--   local next = head + direction       (__add)
--   if next == food then ... end         (__eq)
--   print(next)                          (__tostring)
local Vector2 = {}
Vector2.__index = Vector2

function Vector2:new(x, y)
    return setmetatable({x = x or 0, y = y or 0}, Vector2)
end

-- Vector addition: returns a new vector, operands are not modified
function Vector2:__add(other)
    return Vector2:new(self.x + other.x, self.y + other.y)
end

function Vector2:__sub(other)
    return Vector2:new(self.x - other.x, self.y - other.y)
end

-- Scalar multiplication (works as v * 2 or 2 * v)
function Vector2.__mul(a, b)
    if type(a) == "number" then
        return Vector2:new(a * b.x, a * b.y)
    elseif type(b) == "number" then
        return Vector2:new(a.x * b, a.y * b)
    end
    return Vector2:new(a.x * b.x, a.y * b.y)
end

function Vector2:__unm()
    return Vector2:new(-self.x, -self.y)
end

-- Vector equality: two vectors are equal when both components match
function Vector2:__eq(other)
    return self.x == other.x and self.y == other.y
end

-- String representation, e.g. "Vector2(3, 4)"
function Vector2:__tostring()
    return string.format("Vector2(%g, %g)", self.x, self.y)
end

function Vector2:copy()
    return Vector2:new(self.x, self.y)
end

function Vector2:length()
    return math.sqrt(self.x * self.x + self.y * self.y)
end

return Vector2
