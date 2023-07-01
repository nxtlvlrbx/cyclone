--[[
	DataController.lua
	ChiefWildin
	Created: 04/07/2022
	Version: 2.0.0-dev

	Description:
		Handles data replication coming from the server.

	Setup:
		No setup necessary.

	Documentation:
		::GetDataReplica()
			Returns the Replica object that contains player data.

		::GetValue(valueKey: string): any?
			Returns the value at the specified key in the player data table.

		::GetData()
			Returns the top-level table of player data, containing both the
			session and profile data tables. READ-ONLY, DO NOT ATTEMPT TO WRITE

		::SetValueCallback(path: string, callback: (newValue: any, oldValue: any) -> ())
			Sets a callback function to be run when the value in path is
			changed. Note that the path is a string that specifies the location
			from the top-level player data table.
			Example:
			```lua
				local function printValueChange(newValue, oldValue)
					print("Value changed from", oldValue, " to", newValue)
				end
	            DataController:SetValueCallback("SomeKey.SomeOtherKey", printValueChange)
				-- OR
	            DataController:SetValueCallback({"SomeKey", "SomeOtherKey"}, printValueChange)
			```
--]]

-- Services

-- Task Declaration

local DataController = { Priority = 10 }

-- Dependencies

local ReplicaController = shared("ReplicaController") ---@module ReplicaController

-- Types

type Replica = ReplicaController.Replica

-- Constants

-- Global variables

local PlayerDataReplica: Replica

-- Objects

-- Private functions

-- Public functions

-- Returns the Replica object that contains player data
function DataController:GetDataReplica(): Replica
	while not PlayerDataReplica do
		task.wait()
	end

	return PlayerDataReplica
end

-- Returns the full table of player data
function DataController:GetData(): {}
	while not PlayerDataReplica do
		task.wait()
	end

	return PlayerDataReplica.Data
end

-- Returns the value at the specified path in the player data table. Paths can
-- be of the form "Key1.Key2.Key3" or {"Key1", "Key2", "Key3"}
function DataController:GetValue(keyPath: string | {string}): any?
	while not PlayerDataReplica do
		task.wait()
	end

	local indices
	if typeof(keyPath) == "string" then
		indices = string.split(keyPath, ".")
	elseif typeof(keyPath) == "table" then
		indices = keyPath
	else
		error("Invalid keyPath type: " .. typeof(keyPath))
	end

	local currentLocation = PlayerDataReplica.Data
	for count, index in indices do
		if count == #indices then
			return currentLocation[index]
		end
		currentLocation = currentLocation[index]
	end
end

-- Sets a callback function to be run when the value in path is changed
function DataController:SetValueCallback(path: string, callback: (newValue: any, oldValue: any) -> ())
	while not PlayerDataReplica do
		task.wait()
	end

	PlayerDataReplica:ListenToChange(path, callback)
end

-- Framework callbacks

function DataController:Prep()
	ReplicaController.ReplicaOfClassCreated("PlayerData", function(replica: Replica)
		PlayerDataReplica = replica
	end)

	ReplicaController.RequestData()
end

return DataController
