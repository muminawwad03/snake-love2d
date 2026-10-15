# Snake: Lua Game Programming Assignment

A Snake game built with LÖVE 11.x that uses a state manager, entity components, Vector2 metamethods, the command pattern, an event system and Lua 5.4 to-be-closed variables.

**Play it in your browser:** https://muminawwad03.github.io/snake-love2d/

## Running

```sh
love .          # play the game (from inside snake_game/)
lua main.lua    # no window: runs the headless test checklist (Lua 5.4+)
```

**Controls:** arrow keys or WASD to move, P to pause, ESC for the menu or to quit, and ENTER or SPACE to start or restart.

## Structure

```
snake_game/
├── main.lua            -- Entry point (LÖVE callbacks, or the tests under plain Lua)
├── conf.lua            -- Window setup: vsync, 8x MSAA, high-DPI
├── visuals.lua         -- Palette, fonts, board, snake/apple drawing, particles, UI panels
├── gamestate.lua       -- State manager (menu <-> playing)
├── entity.lua          -- Entity + Position / Movement / Renderer components
├── vector2.lua         -- Vector2 with __add, __sub, __mul, __unm, __eq, __tostring
├── highscore.lua       -- High score save/load using <close>
├── input.lua           -- Command-pattern key bindings
├── events.lua          -- Observer pattern (bonus)
├── states/
│   ├── menu_state.lua  -- Menu state
│   └── game_state.lua  -- Playing state
├── snake_game.lua      -- Core game logic
└── tests.lua           -- Quick Test Checklist, run by `lua main.lua`
```

## Modern Lua feature: to-be-closed variables

`highscore.lua` opens the save file with `local file <close> = io.open(...)`. When a local is marked `<close>`, Lua calls its `__close` metamethod as soon as the variable goes out of scope. That happens on a normal return and also when an error is thrown. So the file handle is always released, with no explicit `file:close()`.

LÖVE runs on LuaJIT, which only understands Lua 5.1 syntax and cannot parse `<close>`. For that reason the Lua 5.4 code is compiled with `load()` only when `_VERSION` is 5.4 or newer. Under LÖVE, a `pcall` wrapper gives the same "always close" guarantee.

## Design notes

- **Entities:** every snake segment and the food is an `Entity`. The head also has a `Movement` component. The snake's colours and thickness come from the head and tail `Renderer` components.
- **Vector2:** the next head position is `position + movement`, and collision checks use `==`.
- **Events:** `snake_game.lua` emits `food_eaten` and `game_over`. The playing state subscribes to `game_over` to save the high score, so the game logic never calls the save system directly.
- **Input:** each state has its own `Input` with key-to-command bindings. Direction changes are buffered until the next step, which stops the snake from reversing into itself.
- **Smooth movement:** the logic still steps one cell at a time on a fixed timer. Each segment also keeps a `Previous` position, and every frame the renderer interpolates between the two by how far the current step has progressed. The snake therefore glides at the display's refresh rate (vsync on), and `dt` is capped so a hitch can't make it jump.
- **Turn queue:** up to two turns are buffered, so a quick "up then left" is never dropped, and each turn is checked against the one before it so the snake can't reverse.
- **Visuals:** the snake is drawn as a tapered tube with a head-to-tail gradient, a shadow and a highlight, plus eyes, blinking and a tongue. Also included: a glowing apple that pops in, particle bursts and "+1" pop-ups, screen shake and a red flash on death, and fading pause and game over panels.
- The snake speeds up a little with each food eaten.

## Web version

`build_web.sh` packages the game and builds it with [love.js](https://github.com/Davidobot/love.js), a port of LÖVE to WebAssembly. The page template is `web/index.html`. On every push to `main`, `.github/workflows/pages.yml` runs the build and publishes it to GitHub Pages. To try it locally, run `./build_web.sh && python3 -m http.server -d dist 8000`.

The high score is written to `highscore.txt` in the current working directory, so run `love .` from inside this folder.
