--[[
	DataController.lua
	ChiefWildin
	Version: 2.4.0

	Handles data replication coming from the server.

--[[ API

	::GetDataReplica()
		Returns the Replica object that contains player data.

	::GetValue(valueKey: string): any?
		Returns the value at the specified key in the player data table.

	::GetData()
        Returns the top-level table of player data, containing both the session
		and profile data tables. READ-ONLY, DO NOT ATTEMPT TO WRITE

	::SetValueCallback(path: string, callback: (newValue: any, oldValue: any) -> ())
        Sets a callback function to be run when the value in path is changed.
        Note that the path is a string that specifies the location from the
		top-level player data table.
		Example:
		```lua
			local function printValueChange(newValue, oldValue)
				print("Value changed from", oldValue, " to", newValue)
			end
			DataController:SetValueCallback("SomeKey.SomeOtherKey", printValueChange)
			-- OR
			DataController:SetValueCallback({"SomeKey", "SomeOtherKey"}, printValueChange)
		```
]]

-- Services

local RunService = game:GetService("RunService")

-- Task Declaration

local DataController = { Priority = 10 }

-- Dependencies

local DeepCopy = shared("DeepCopy") ---@module DeepCopy
local ReplicaClient = RunService:IsRunning() and shared("ReplicaClient") ---@module ReplicaClient

-- Types

type Replica = ReplicaClient.Replica

-- Global variables

local PlayerDataReplica: Replica

-- Private functions

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

-- Public functions

-- Returns the Replica object that contains player data
function DataController:GetDataReplica(): Replica
	while not PlayerDataReplica do
		if not RunService:IsRunning() then
			PlayerDataReplica = {
				Data = DeepCopy(shared("ProfileTemplate")),
				ListenToChange = function() end,
			} :: Replica
		else
			task.wait()
		end
	end

	return PlayerDataReplica
end

-- Returns the full table of player data
function DataController:GetData(): {}
	return self:GetDataReplica().Data
end

-- Returns the value at the specified path in the player data table. Paths can
-- be of the form "Key1.Key2.Key3" or {"Key1", "Key2", "Key3"}
function DataController:GetValue(keyPath: string | { string }): any?
	local indices = getPathTable(keyPath)
	local currentLocation = self:GetData()
	for count, index in indices do
		if count == #indices then
			return currentLocation[index]
		end
		currentLocation = currentLocation[index]
	end

	return nil
end

-- Sets a callback function to be run when the value in path is changed
function DataController:SetValueCallback(
	path: string | { string },
	callback: (newValue: any, oldValue: any) -> (),
	runImmediately: boolean?
): RBXScriptConnection
	if runImmediately then
		local value = DataController:GetValue(path)
		callback(value, value)
	end

	return self:GetDataReplica():OnSet(getPathTable(path), callback)
end

-- Framework callbacks

function DataController:Prep()
	if RunService:IsRunning() then
		ReplicaClient.OnNew("PlayerData", function(replica: Replica)
			PlayerDataReplica = replica
		end)

		ReplicaClient.RequestData()
	end
end

return DataController
