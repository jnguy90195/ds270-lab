# GrowSlop (Roblox)

A rough, Growtopia-inspired 2D mining sandbox for Roblox. It's a slop prototype on purpose:
the goal is a playable loop, not polish.

## What works right now

- Procedurally generated side-view world (80×36 tiles) with grass, dirt, stone, caves, bedrock, and gem ore
- Shared world: all players see the same tiles, and the server is authoritative
- Mine tiles (hold left mouse). Tiles take several hits to break and heal if you stop
- Place blocks (hold right mouse) from a hotbar (keys 1/2/3). Blocks must touch a solid neighbor and be in reach
- Gem ore drops gems (leaderstats + HUD)
- Movement: A/D or arrows to walk, Space/W/Up to jump

## Project layout

```
default.project.json          Rojo project file (maps folders into Roblox services)
src/shared/Config.lua         Tile size, world size, block definitions, tuning
src/shared/Remotes.lua        RemoteEvents (Mine, Place, Inventory, Sync)
src/server/main.server.lua    Boot order: world -> players
src/server/WorldService.lua   Tile grid, world generation, damage/break
src/server/PlayerService.lua  Inventory, gems, validates every request
src/client/main.client.lua    Camera, movement, input, HUD, crack visuals
```

## Running it

Easiest path is [Rojo](https://rojo.space):

1. Install Rojo (`aftman`/`rokit` or the Roblox Studio plugin from the Creator Store).
2. From this folder: `rojo serve`
3. In Roblox Studio, open a new baseplate, install the Rojo plugin, and click **Connect**.
4. Press **Play**.

Without Rojo: copy each file into the matching place in Studio:

| File | Studio location | Type |
| --- | --- | --- |
| `src/shared/Config.lua` | ReplicatedStorage/Shared | ModuleScript |
| `src/shared/Remotes.lua` | ReplicatedStorage/Shared | ModuleScript |
| `src/server/*.lua` (except main) | ServerScriptService/Server | ModuleScript |
| `src/server/main.server.lua` | ServerScriptService/Server | Script |
| `src/client/main.client.lua` | StarterPlayer/StarterPlayerScripts/Client | LocalScript |

## Status

- Not yet tested inside Roblox Studio. The code was written without a Studio session, so expect small bugs on the first run.
- No Luau linter was available when this was written.

## Ideas for next time

- Real sprites/textures instead of flat colors
- Inventory grid, tool upgrades (pickaxe tiers)
- Seeds + farming (Growtopia's whole gimmick)
- Worlds per player / world-join codes
- Tile crack animation and break particles
- Save world to DataStore
