local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Characters spawn only after the world exists, so nobody drops into an empty void.
Players.CharacterAutoLoads = false

require(ReplicatedStorage.Shared.Remotes).get()

local WorldService = require(script.Parent.WorldService)
local PlayerService = require(script.Parent.PlayerService)

WorldService.init()
PlayerService.init()
