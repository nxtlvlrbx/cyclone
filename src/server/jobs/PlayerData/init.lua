--[[
	PlayerData.lua
	ChiefWildin
	Created: 04/07/2022
	Version: 2.1.2

	Description:
		Handles the implementation of ProfileService and ReplicaService for
		managing player data.

	Setup:
		No setup necessary.

	API:
		::GetPlayerDataReplica(player: Player): Replica
	        Returns the Replica object associated with the given player.
	        Modifying tables/arrays should be done through the Replica instead
	        of GetValue/SetValue in order to make sure they replicate properly.
	        The Replica API can be found at:
	        https://madstudioroblox.github.io/ReplicaService/api/#replica
			Example:
			```lua
				local PlayerDataReplica = PlayerData:GetPlayerDataReplica(player)
                PlayerDataReplica:SetValue("Tokens", PlayerDataReplica.Data.Tokens + 1)
			```

		::GetValue(player: Player, keyPath: string | { string }): any?
			Returns the value at the given keyPath.
			Example:
			```lua
				local tokens = PlayerData:GetValue(player, "Tokens")
			```

		::SetValue(player: Player, keyPath: string | { string }, newValue: any)
			Sets the value at the given keyPath to the given newValue.
			Example:
			```lua
				PlayerData:SetValue(player, "Tokens", 0)
			```
--]]

-- Services

local Players = game:GetService("Players")

-- Task Declaration

local PlayerData = {}

-- Dependencies

local ReplicaService = shared("ReplicaService") ---@module ReplicaService
local ProfileService = shared("ProfileService") ---@module ProfileService
local ProfileTemplate = shared("ProfileTemplate") ---@module ProfileTemplate
local GetRemote = shared("GetRemote") ---@module GetRemote

-- Types

type Replica = ReplicaService.Replica

-- Constants

-- EXPOSED TO PLAYER, DO NOT ADD ANYTHING UNLESS YOU WANT TO LET THEM CHANGE IT
local FREE_SETTINGS = {
	-- ["MusicVolume"] = {
	-- 	Type = "number",
	-- 	Valid = function(value)
	-- 		return value >= 0 and value <= 1
	-- 	end,
	-- },
}
-- Whether or not the system warns about infinite yields on player data fetch
local INFINITE_YIELD_WARNING_ENABLED = false
-- How long to wait before warning about infinite yields on player data fetch
local INFINITE_YIELD_WARNING_TIME = 5

-- Global variables

local StoreName = "PlayerData"
local PlayerCache = {}
local PlayerProfiles = {}
local ProcessedPlayers = {}
local PlayerDataToken = ReplicaService.NewClassToken("PlayerData")
local ProfileStore: DataStore

-- Objects

-- Private functions

local function deepTableCopy(originalTable: {}): {}
	local copy = {}
	for i: any, v: any in pairs(originalTable) do
		if typeof(v) == "table" then
			copy[i] = deepTableCopy(v)
		else
			copy[i] = v
		end
	end
	return copy
end

local function profileReleased(player: Player)
	if PlayerCache[player] then
		-- Destroy player data Replica
		PlayerCache[player]:Destroy()
	end

	-- Dereference the Replica
	PlayerCache[player] = nil
	PlayerProfiles[player] = nil

	-- Kick the player, just in case
	player:Kick()
end

local function settingChangeRequested(player: Player, settingName: string, newValue: any)
	local params = FREE_SETTINGS[settingName]
	if params and typeof(newValue) == params.Type and params.Valid(newValue) then
		local playerDataReplica = PlayerData:GetPlayerDataReplica(player)
		playerDataReplica:SetValue({ "Profile", settingName }, newValue)
	else
		warn("Bad attempt from", player, "to change setting")
	end
end

local function processPlayer(player: Player)
	if ProcessedPlayers[player] then
		return
	end

	ProcessedPlayers[player] = true

	local profile = ProfileStore:LoadProfileAsync(tostring(player.UserId), "ForceLoad")
	if profile ~= nil then
		profile:AddUserId(player.UserId)
		profile:Reconcile()
		profile:ListenToRelease(function()
			profileReleased(player)
		end)

		if player:IsDescendantOf(Players) then
			local data: Replica = ReplicaService.NewReplica({
				ClassToken = PlayerDataToken,
				Tags = { Player = player },
				Data = profile.Data,
				Replication = { [player] = true },
			})

			PlayerCache[player] = data
			PlayerProfiles[player] = profile
		else
			profile:Release()
		end
	else
		player:Kick("An error occurred while loading. Please try again.")
	end
end

-- Public functions

--Returns the `Replica` object associated with the given player. Modifying
--tables/arrays should be done through the Replica instead of
--`GetValue`/`SetValue` in order to make sure they replicate properly. The
--Replica API can be found at:
--https://madstudioroblox.github.io/ReplicaService/api/#replica
function PlayerData:GetPlayerDataReplica(player: Player): Replica
	local startFetchTick = os.clock()
	local warned = false

	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		error("Bad argument #1 to PlayerData:GetPlayerDataReplica, Player expected, got " .. typeof(player))
	end

	while not PlayerCache[player] do
		task.wait()
		if
			INFINITE_YIELD_WARNING_ENABLED
			and os.clock() - startFetchTick > INFINITE_YIELD_WARNING_TIME
			and not warned
		then
			warn("Infinite yield possible on player data fetch for", player)
			warned = true
		end
	end
	return PlayerCache[player]
end

-- Returns the value at the given `keyPath`. Keys can be passed in any of the
-- following ways:
-- ```lua
-- PlayerData:GetValue(player, "Tokens")
-- PlayerData:GetValue(player, "Powerups.ExtraLives")
-- PlayerData:GetValue(player, { "Powerups", "ExtraLives" })
-- ```
function PlayerData:GetValue(player: Player, keyPath: string | { string }): any?
	local dataReplica = self:GetPlayerDataReplica(player)

	local indices
	if typeof(keyPath) == "string" then
		indices = string.split(keyPath, ".")
	elseif typeof(keyPath) == "table" then
		indices = keyPath
	else
		error("Invalid keyPath type: " .. typeof(keyPath))
	end

	local currentLocation = dataReplica.Data
	for count, index in indices do
		if count == #indices then
			return currentLocation[index]
		end
		currentLocation = currentLocation[index]
	end
end

-- Sets the value at the given `keyPath` to the given `newValue`. Keys can be
-- passed in any of the following ways:
-- ```lua
-- PlayerData:SetValue(player, "Tokens", 0)
-- PlayerData:SetValue(player, "Powerups.ExtraLives", 1)
-- PlayerData:SetValue(player, { "Powerups", "ExtraLives" }, 1)
-- ```
function PlayerData:SetValue(player: Player, keyPath: string | { string }, newValue: any)
	self:GetPlayerDataReplica(player):SetValue(keyPath, newValue)
end

-- Task Initialization

function PlayerData:Run()
	GetRemote("ChangeSetting"):OnServerEvent(settingChangeRequested)

	ProfileStore = ProfileService.GetProfileStore(StoreName, ProfileTemplate)

	Players.PlayerAdded:Connect(processPlayer)
	for _, player in pairs(Players:GetPlayers()) do
		processPlayer(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local profile = PlayerProfiles[player]
		if profile ~= nil then
			profile:Release()
		else
			PlayerCache[player] = nil
		end

		ProcessedPlayers[player] = nil
	end)
end

return PlayerData
