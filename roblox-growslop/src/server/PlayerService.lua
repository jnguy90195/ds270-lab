-- Tracks each player's gems and inventory, and validates every mine / place request.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local WorldService = require(script.Parent.WorldService)

local S = Config.TileSize
local PlayerService = {}
local data = {} -- [player] = { gems, items, gemsValue, lastMine, lastPlace }

local function copyItems(src)
	local out = {}
	for k, v in src do
		out[k] = v
	end
	return out
end

local function getRoot(player)
	local char = player.Character
	if not char then
		return nil
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	if hum and root and hum.Health > 0 then
		return root
	end
	return nil
end

local function push(player)
	local d = data[player]
	if not d then
		return
	end
	d.gemsValue.Value = d.gems
	Remotes.get().Inventory:FireClient(player, { gems = d.gems, items = d.items })
end

local function onMine(player, gx, gy)
	local d = data[player]
	if not d or type(gx) ~= "number" or type(gy) ~= "number" then
		return
	end
	local now = os.clock()
	if now - d.lastMine < Config.ActionCooldown then
		return
	end
	d.lastMine = now

	gx, gy = math.floor(gx), math.floor(gy)
	local root = getRoot(player)
	if not root or not Config.inBounds(gx, gy) then
		return
	end
	if (root.Position - Config.worldPos(gx, gy)).Magnitude > Config.Reach then
		return
	end

	local brokenId = WorldService.hit(gx, gy)
	if brokenId then
		local def = Config.Blocks[brokenId]
		if def.drop then
			d.items[def.drop] = (d.items[def.drop] or 0) + 1
		end
		if def.gems then
			d.gems += math.random(def.gems[1], def.gems[2])
		end
		push(player)
	end
end

local function onPlace(player, gx, gy, id)
	local d = data[player]
	if not d or type(gx) ~= "number" or type(gy) ~= "number" or type(id) ~= "number" then
		return
	end
	local now = os.clock()
	if now - d.lastPlace < Config.ActionCooldown then
		return
	end
	d.lastPlace = now

	gx, gy, id = math.floor(gx), math.floor(gy), math.floor(id)
	local def = Config.Blocks[id]
	if not def or not def.placeable or (d.items[id] or 0) <= 0 then
		return
	end
	local root = getRoot(player)
	if not root or not Config.inBounds(gx, gy) or WorldService.get(gx, gy) ~= 0 then
		return
	end

	local tilePos = Config.worldPos(gx, gy)
	if (root.Position - tilePos).Magnitude > Config.Reach then
		return
	end
	-- Don't place a block inside the player's body.
	local dx = math.abs(root.Position.X - tilePos.X)
	local dy = math.abs(root.Position.Y - tilePos.Y)
	if dx < S / 2 + 1 and dy < S / 2 + 3 then
		return
	end
	if not WorldService.hasSolidNeighbor(gx, gy) then
		return
	end

	d.items[id] -= 1
	WorldService.setTile(gx, gy, id)
	push(player)
end

local function setupPlayer(player)
	if data[player] then
		return
	end
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local gems = Instance.new("IntValue")
	gems.Name = "Gems"
	gems.Parent = stats
	stats.Parent = player

	data[player] = {
		gems = Config.StartGems,
		items = copyItems(Config.StartItems),
		gemsValue = gems,
		lastMine = 0,
		lastPlace = 0,
	}
	player:LoadCharacter()
	push(player)
end

function PlayerService.init()
	local remotes = Remotes.get()
	remotes.Mine.OnServerEvent:Connect(onMine)
	remotes.Place.OnServerEvent:Connect(onPlace)
	remotes.Sync.OnServerEvent:Connect(push)

	Players.PlayerAdded:Connect(setupPlayer)
	Players.PlayerRemoving:Connect(function(player)
		data[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end
end

return PlayerService
