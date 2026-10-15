-- conf.lua
-- Window settings are applied before the window opens, so there is no
-- flicker from recreating it in love.load().
function love.conf(t)
    t.identity = "snake_assignment"
    t.window.title = "Snake"
    t.window.width = 640
    t.window.height = 700
    t.window.vsync = 1        -- lock rendering to the display refresh (60 Hz+)
    t.window.msaa = 8         -- anti-aliased edges for the round shapes
    t.window.highdpi = true   -- crisp on Retina displays
    t.modules.joystick = false
    t.modules.physics = false
end
