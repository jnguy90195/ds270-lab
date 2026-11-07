-- Client: side-view camera, movement, mining/placing input, hotbar HUD, crack visuals.
-- The server is authoritative; this script only sends requests and draws what the server says.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local remotes = Remotes.get()
local world = workspace:WaitForChild("World")

local S, D = Config.TileSize, Config.TileDepth
local ACTION_INTERVAL = 0.15
local NUMBER_KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three }

-- Side-scroller: turn off Roblox's default 3D controls and drive the character ourselves.
local playerModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
playerModule:GetControls():Disable()

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------
local function new(className, props, parent)
	local obj = Instance.new(className)
	for k, v in props do
		obj[k] = v
	end
	obj.Parent = parent
	return obj
end

local function getChar()
	local char = player.Character
	if not char then
		return nil, nil
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	if hum and root and hum.Health > 0 then
		return hum, root
	end
	return nil, nil
end

-- Intersect the mouse ray with the gameplay plane (z = 0) and convert to grid coords.
local function mouseTile()
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local dz = ray.Direction.Z
	if math.abs(dz) < 1e-6 then
		return nil
	end
	local t = -ray.Origin.Z / dz
	if t < 0 then
		return nil
	end
	local p = ray.Origin + ray.Direction * t
	local gx = math.floor(p.X / S + 0.5) + 1
	local gy = math.floor(-p.Y / S + 0.5) + 1
	if not Config.inBounds(gx, gy) then
		return nil
	end
	return gx, gy
end

-------------------------------------------------------------------------------
-- HUD
-------------------------------------------------------------------------------
local gui = new("ScreenGui", { Name = "GrowSlopHUD", ResetOnSpawn = false }, player:WaitForChild("PlayerGui"))

local gemsLabel = new("TextLabel", {
	Size = UDim2.fromOffset(200, 40),
	Position = UDim2.fromOffset(16, 16),
	BackgroundColor3 = Color3.fromRGB(20, 20, 28),
	BackgroundTransparency = 0.3,
	TextColor3 = Color3.fromRGB(120, 230, 255),
	Font = Enum.Font.GothamBold,
	TextSize = 22,
	Text = "Gems: 0",
}, gui)

local hotbar = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -16),
	Size = UDim2.fromOffset(360, 64),
	BackgroundTransparency = 1,
}, gui)
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, hotbar)

local inventory = { gems = 0, items = {} }
local selected = Config.PlaceableOrder[1]
local buttons = {}

local function refreshHud()
	gemsLabel.Text = "Gems: " .. tostring(inventory.gems)
	for i, id in Config.PlaceableOrder do
		local btn = buttons[id]
		local def = Config.Blocks[id]
		btn.Text = string.format("%d %s\nx%d", i, def.name, inventory.items[id] or 0)
		btn.BackgroundColor3 = (id == selected) and Color3.fromRGB(230, 180, 60) or Color3.fromRGB(40, 40, 52)
	end
end

for i, id in Config.PlaceableOrder do
	local btn = new("TextButton", {
		Size = UDim2.fromOffset(110, 60),
		BackgroundColor3 = Color3.fromRGB(40, 40, 52),
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		Text = "",
		LayoutOrder = i,
	}, hotbar)
	buttons[id] = btn
	btn.MouseButton1Click:Connect(function()
		selected = id
		refreshHud()
	end)
end

-------------------------------------------------------------------------------
-- Cursor (shows which tile you're pointing at; red when out of reach)
-------------------------------------------------------------------------------
local cursor = new("Part", {
	Name = "Cursor",
	Anchored = true,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
	CastShadow = false,
	Material = Enum.Material.Neon,
	Color = Color3.fromRGB(255, 255, 255),
	Transparency = 0.6,
	Size = Vector3.new(S + 0.2, S + 0.2, 0.5),
}, workspace)

-------------------------------------------------------------------------------
-- Crack visuals: server sets "Damage" (0..1) on each tile, we darken it
-------------------------------------------------------------------------------
local function watchTile(part)
	if not part:IsA("BasePart") then
		return
	end
	part:GetAttributeChangedSignal("Damage"):Connect(function()
		local def = Config.Blocks[part:GetAttribute("Id")]
		if not def then
			return
		end
		local dmg = math.clamp(part:GetAttribute("Damage") or 0, 0, 1)
		part.Color = def.color:Lerp(Color3.new(0, 0, 0), dmg * 0.6)
	end)
end
world.ChildAdded:Connect(watchTile)
for _, child in world:GetChildren() do
	watchTile(child)
end

-------------------------------------------------------------------------------
-- Input
-------------------------------------------------------------------------------
local mining, placing = false, false

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		mining = true
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		placing = true
	elseif input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.W or input.KeyCode == Enum.KeyCode.Up then
		local hum = getChar()
		if hum then
			hum.Jump = true
		end
	else
		for i, key in NUMBER_KEYS do
			if input.KeyCode == key and Config.PlaceableOrder[i] then
				selected = Config.PlaceableOrder[i]
				refreshHud()
			end
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		mining = false
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		placing = false
	end
end)

-------------------------------------------------------------------------------
-- Server sync
-------------------------------------------------------------------------------
remotes.Inventory.OnClientEvent:Connect(function(payload)
	inventory = payload
	refreshHud()
end)
refreshHud()
remotes.Sync:FireServer()

-------------------------------------------------------------------------------
-- Main loop: movement, camera, cursor, and sending mine/place requests
-------------------------------------------------------------------------------
local lastMine, lastPlace = 0, 0

RunService.RenderStepped:Connect(function()
	local hum, root = getChar()
	if not hum then
		return
	end

	-- Movement: A/D or arrows, locked to the X axis.
	local dir = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
		dir += 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
		dir -= 1
	end
	hum:Move(Vector3.new(dir, 0, 0), false)

	-- Side-on camera looking down -Z at the slab.
	camera.CameraType = Enum.CameraType.Scriptable
	local focus = root.Position + Vector3.new(0, 2, 0)
	camera.CFrame = CFrame.new(focus + Vector3.new(0, 0, 36), focus)

	-- Targeting.
	local gx, gy = mouseTile()
	if not gx then
		cursor.Transparency = 1
		return
	end
	local tilePos = Config.worldPos(gx, gy)
	cursor.Transparency = 0.6
	cursor.Position = tilePos + Vector3.new(0, 0, D / 2 + 0.25)

	local inReach = (root.Position - tilePos).Magnitude <= Config.Reach
	cursor.Color = inReach and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(255, 80, 80)

	local now = os.clock()
	if mining and inReach and now - lastMine >= ACTION_INTERVAL then
		lastMine = now
		remotes.Mine:FireServer(gx, gy)
	end
	if placing and inReach and (inventory.items[selected] or 0) > 0 and now - lastPlace >= ACTION_INTERVAL then
		lastPlace = now
		remotes.Place:FireServer(gx, gy, selected)
	end
end)
