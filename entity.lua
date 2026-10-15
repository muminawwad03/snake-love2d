-- entity.lua
-- Minimal entity-component pattern: an entity is just a bag of named
-- components (plain data tables). Systems query entities by component.
local Vector2 = require("vector2")

local Entity = {}
Entity.__index = Entity

function Entity:new()
    local entity = {
        components = {}
    }
    return setmetatable(entity, Entity)
end

-- Returns self so calls can be chained:
--   Entity:new():addComponent("Position", ...):addComponent("Renderer", ...)
function Entity:addComponent(name, component)
    self.components[name] = component
    return self
end

function Entity:getComponent(name)
    return self.components[name]
end

function Entity:hasComponent(name)
    return self.components[name] ~= nil
end

function Entity:removeComponent(name)
    self.components[name] = nil
end

-- Component constructors -----------------------------------------------

Entity.Components = {}

-- Position (x, y): grid cell the entity occupies, stored as a Vector2
function Entity.Components.Position(x, y)
    return Vector2:new(x, y)
end

-- Movement (dx, dy): direction the entity travels each step
function Entity.Components.Movement(dx, dy)
    return Vector2:new(dx, dy)
end

-- Renderer (color, size): how the entity is drawn; color is {r, g, b[, a]}
-- in LÖVE 0..1 range, size is a fraction of a grid cell (1 = full cell)
function Entity.Components.Renderer(color, size)
    return {color = color or {1, 1, 1}, size = size or 1}
end

return Entity
