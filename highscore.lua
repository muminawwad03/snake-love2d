-- highscore.lua
-- File-based high score using Lua 5.4 to-be-closed variables.
--
-- MODERN LUA FEATURE: to-be-closed variables (Lua 5.4)
--   local file <close> = io.open(...)
-- Marking a local with <close> makes Lua call its __close metamethod as
-- soon as the variable goes out of scope -- on a normal return, a break,
-- OR when an error is thrown. File handles have __close, so the file is
-- always closed without an explicit file:close(), and an error in
-- file:write() can no longer leak an open handle. It is the Lua version of
-- C#'s `using` or Python's `with`.
--
-- Compatibility note: LÖVE runs on LuaJIT (Lua 5.1 syntax), which cannot
-- even parse `<close>`. So the 5.4 code is compiled with load() only when
-- running on Lua 5.4+ (`lua main.lua`); under LÖVE a fallback with the same
-- guarantee (close the file even if an error occurs) is used instead.
local HighScore = {}

HighScore.path = "highscore.txt"

local LUA54_SOURCE = [[
local HighScore = ...

function HighScore:save(score)
    local file <close> = io.open(self.path, "w")
    if file then
        file:write(tostring(score))
        -- File automatically closes even if error occurs
        return true
    end
    return false
end

function HighScore:load()
    local file <close> = io.open(self.path, "r")
    if file then
        local content = file:read("*a")
        return tonumber(content) or 0
    end
    return 0
end
]]

local function supportsToBeClosed()
    local major, minor = _VERSION:match("Lua (%d+)%.(%d+)")
    major, minor = tonumber(major), tonumber(minor)
    return major and (major > 5 or (major == 5 and minor >= 4))
end

if supportsToBeClosed() then
    local chunk = assert(load(LUA54_SOURCE, "=highscore_lua54"))
    chunk(HighScore)
    HighScore.usesToBeClosed = true
else
    -- Emulates <close>: run the body, then always close, then re-raise
    local function withFile(path, mode, body)
        local file = io.open(path, mode)
        if not file then return nil end
        local ok, result = pcall(body, file)
        file:close()
        if not ok then error(result, 0) end
        return result
    end

    function HighScore:save(score)
        return withFile(self.path, "w", function(file)
            file:write(tostring(score))
            return true
        end) or false
    end

    function HighScore:load()
        return withFile(self.path, "r", function(file)
            return tonumber(file:read("*a")) or 0
        end) or 0
    end

    HighScore.usesToBeClosed = false
end

-- In the browser build (love.js) io.open only reaches a temporary
-- in-memory filesystem, so use LÖVE's save directory, which the browser
-- keeps in IndexedDB between visits.
if love and love.system and love.system.getOS() == "Web" then
    -- love.js raises an error (instead of returning nil) for missing files,
    -- so check first and guard both calls
    function HighScore:save(score)
        local ok, written = pcall(love.filesystem.write, self.path, tostring(score))
        return ok and written and true or false
    end

    function HighScore:load()
        if not love.filesystem.getInfo(self.path) then return 0 end
        local ok, content = pcall(love.filesystem.read, self.path)
        return ok and tonumber(content) or 0
    end
end

-- Saves only if the score beats the stored one; returns the current best
function HighScore:submit(score)
    local best = self:load()
    if score > best then
        self:save(score)
        return score, true
    end
    return best, false
end

return HighScore
