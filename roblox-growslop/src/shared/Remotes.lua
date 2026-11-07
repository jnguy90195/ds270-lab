-- Creates (server) or waits for (client) the RemoteEvents used for mining, placing and inventory sync.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local FOLDER_NAME = "Remotes"
local EVENT_NAMES = { "Mine", "Place", "Inventory", "Sync" }

function Remotes.get()
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			for _, name in EVENT_NAMES do
				local event = Instance.new("RemoteEvent")
				event.Name = name
				event.Parent = folder
			end
			folder.Parent = ReplicatedStorage
		end
		return folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

return Remotes
