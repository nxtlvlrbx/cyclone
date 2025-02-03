--[[

	PlayerData.lua
	ChiefWildin
	Version: 2.4.0

	Handles the implementation of ProfileStore and Replica for managing player
	data.

]]

--[[ API
	::GetPlayerDataReplica(player: Player): Replica
	Returns the Replica object associated with the given player. Modifying
	tables/arrays should be done through the Replica instead of
	GetValue/SetValue in order to make sure they replicate properly.
	The Replica API can be found at:
	https://madstudioroblox.github.io/Replica/
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

	::SetValueCallback(player: Player, keyPath: string | { string }, callback: (newValue: any, oldValue: any) -> ()): RBXScriptConnection
		Sets a callback function to be run when the value in path is changed.
		Example:
		```lua
			PlayerData:SetValueCallback(player, "Tokens", function(newValue, oldValue)
				print(player.Name .. "'s tokens have changed from " .. tostring(oldValue) .. " to " .. tostring(newValue))
			end)
		```
--]]

-- Services

local Players = game:GetService("Players")

-- Task Declaration

local PlayerData = {}

-- Dependencies

local ReplicaServer = shared("ReplicaServer") ---@module ReplicaServer
local ProfileStore = shared("ProfileStore") ---@module ProfileStore
local ProfileTemplate = shared("ProfileTemplate") ---@module ProfileTemplate
local GetRemote = shared("GetRemote") ---@module GetRemote

-- Types

type Replica = ReplicaServer.Replica

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
local DataCallbacks: { [string]: (new: any, old: any) -> () } = {}
local ReplicaCache = {}
local PlayerProfiles: { [Player]: typeof(ProfileStore:StartSessionAsync()) } = {}
local ProcessedPlayers = {}
local PlayerDataToken = ReplicaServer.Token("PlayerData")
local ProfileDataStore: ProfileStore.ProfileStore<typeof(ProfileTemplate)>

-- Objects

-- Private functions

local function deepTableCopy(originalTable: { [any]: any }): { [any]: any }
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

local function settingChangeRequested(player: Player, settingName: string, newValue: any)
	local params = FREE_SETTINGS[settingName]
	if params and typeof(newValue) == params.Type and params.Valid(newValue) then
		local playerDataReplica = PlayerData:GetPlayerDataReplica(player)
		playerDataReplica:Set({ "Profile", settingName }, newValue)
	else
		warn("Bad attempt from", player, "to change setting")
	end
end

local function processPlayer(player: Player)
	if ProcessedPlayers[player] then
		return
	end

	ProcessedPlayers[player] = true

	local profile = ProfileDataStore:StartSessionAsync(tostring(player.UserId), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile ~= nil then
		profile:AddUserId(player.UserId)
		profile:Reconcile()

		profile.OnSessionEnd:Connect(function()
			if ReplicaCache[player] then
				ReplicaCache[player]:Destroy()
			end

			ReplicaCache[player] = nil
			PlayerProfiles[player] = nil

			player:Kick(`Profile session end - Please rejoin`)
		end)

		if player:IsDescendantOf(Players) then
			local data: Replica = ReplicaServer.New({
				Token = PlayerDataToken,
				Tags = { Player = player },
				Data = profile.Data,
			})

			data:Subscribe(player)

			ReplicaCache[player] = data
			PlayerProfiles[player] = profile
		else
			profile:EndSession()
		end
	else
		player:Kick("Profile data load failed - Please rejoin")
	end
end

local function getPathTable(path: string | { string }): { string }
	local indices
	if typeof(path) == "string" then
		indices = string.split(path, ".")
	elseif typeof(path) == "table" then
		indices = path
	else
		error("Invalid keyPath type: " .. typeof(path))
	end

	return indices
end

local function getPathString(path: string | { string }): string
	if typeof(path) == "string" then
		return path
	elseif typeof(path) == "table" then
		return table.concat(path, ".")
	else
		error("Invalid keyPath type: " .. typeof(path))
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

	while not ReplicaCache[player] do
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
	return ReplicaCache[player]
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

	local indices = getPathTable(keyPath)

	local currentLocation = dataReplica.Data
	for count, index in indices do
		if count == #indices then
			return currentLocation[index]
		end
		currentLocation = currentLocation[index]
	end

	return
end

-- Sets the value at the given `keyPath` to the given `newValue`. Keys can be
-- passed in any of the following ways:
-- ```lua
-- PlayerData:SetValue(player, "Tokens", 0)
-- PlayerData:SetValue(player, "Powerups.ExtraLives", 1)
-- PlayerData:SetValue(player, { "Powerups", "ExtraLives" }, 1)
-- ```
function PlayerData:SetValue(player: Player, keyPath: string | { string }, newValue: any)
	local callback = DataCallbacks[`{player.UserId}.{getPathString(keyPath)}`]
	local oldValue = callback and self:GetValue(player, keyPath)

	self:GetPlayerDataReplica(player):Set(keyPath, newValue)

	if callback then
		task.spawn(callback, newValue, oldValue)
	end
end

-- Sets a callback function to be run when the value in path is changed. Only
-- works when data is set through PlayerData:SetValue() until officially
-- supported server-side in Replica. Keys can be passed in any of the following
-- ways:
-- ```lua
-- PlayerData:SetValueCallback(player, "Tokens", callback)
-- PlayerData:SetValueCallback(player, "Powerups.ExtraLives", callback)
-- PlayerData:SetValueCallback(player, { "Powerups", "ExtraLives" }, callback)
-- ```
function PlayerData:SetValueCallback(
	player: Player,
	keyPath: string | { string },
	callback: (newValue: any, oldValue: any) -> (),
	runImmediately: boolean?
)
	local index = `{player.UserId}.{getPathString(keyPath)}`
	DataCallbacks[index] = callback

	if runImmediately then
		local value = self:GetValue(player, keyPath)
		task.spawn(callback, value, value)
	end
end

function PlayerData:ClearValueCallback(player: Player, keyPath: string | { string })
	local index = `{player.UserId}.{getPathString(keyPath)}`
	DataCallbacks[index] = nil
end

-- Task Initialization

function PlayerData:Run()
	GetRemote("ChangeSetting"):OnServerEvent(settingChangeRequested)

	ProfileDataStore = ProfileStore.New(StoreName, ProfileTemplate)

	Players.PlayerAdded:Connect(processPlayer)
	for _, player in pairs(Players:GetPlayers()) do
		processPlayer(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local profile = PlayerProfiles[player]
		if profile ~= nil then
			profile:EndSession()
		else
			ReplicaCache[player] = nil
		end

		ProcessedPlayers[player] = nil
	end)
end

return PlayerData
