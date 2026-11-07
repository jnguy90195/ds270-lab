-- Shared constants and block definitions. Used by both server and client.
local Config = {}

Config.TileSize = 4        -- studs per tile (width and height)
Config.TileDepth = 40      -- studs deep on Z, so the 2D world is a thick slab
Config.Cols = 80           -- world width in tiles
Config.Rows = 36           -- world height in tiles (row 1 = top)
Config.SurfaceRow = 10     -- average ground level
Config.Reach = 14          -- studs from the player you can mine / place
Config.ActionCooldown = 0.12
Config.StartGems = 0
Config.StartItems = { [1] = 30, [5] = 5 } -- itemId -> count
Config.PlaceableOrder = { 1, 3, 5 }       -- hotbar order (1, 2, 3 keys)

Config.Blocks = {
	[0] = { name = "Air" },
	[1] = { name = "Dirt", color = Color3.fromRGB(121, 85, 58), hardness = 2, drop = 1, placeable = true },
	[2] = { name = "Grass", color = Color3.fromRGB(96, 170, 72), hardness = 2, drop = 1 },
	[3] = { name = "Stone", color = Color3.fromRGB(125, 125, 130), hardness = 4, drop = 3, placeable = true },
	[4] = { name = "Bedrock", color = Color3.fromRGB(45, 42, 48), hardness = math.huge },
	[5] = { name = "Brick", color = Color3.fromRGB(170, 70, 52), hardness = 3, drop = 5, placeable = true },
	[6] = { name = "Gem Ore", color = Color3.fromRGB(96, 190, 220), hardness = 5, drop = 3, gems = { 1, 3 } },
}

-- Grid (gx, gy) -> world position of the tile center. Column 1 is the left edge, row 1 is the top.
function Config.worldPos(gx, gy)
	return Vector3.new((gx - 1) * Config.TileSize, -(gy - 1) * Config.TileSize, 0)
end

function Config.inBounds(gx, gy)
	return gx >= 1 and gx <= Config.Cols and gy >= 1 and gy <= Config.Rows
end

return Config
