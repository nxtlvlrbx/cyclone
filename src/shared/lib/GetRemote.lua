--[[
	Author: ChiefWildin
	Module: GetRemote.lua
	Created: 01/25/2023
	Version: 1.1.0

	Provides a simple interface for creating and using remotes. The Remote
	object is a wrapper that will dynamically create RemoteEvents and
	RemoteFunctions based on what it is used for. It combines the interface of
	both objects into one for ease of use.

	Example usage:
	```lua
		local GetRemote = shared("GetRemote") ---@module GetRemote

		local TestRemote = GetRemote("TestRemote")

		TestRemote:OnEvent(function(player, ...)
			print("TestRemote fired by " .. player.Name .. ", got:", ...)
		end)

		TestRemote:OnInvoke(function()
			return "Working"
		end)

		TestRemote:Fire("Fired to all clients")

		local player = Players:GetPlayers()[1]
		print("Client invoke test returned:", TestRemote:Invoke(player))
		TestRemote:FireClient(player, "Fired to " .. player.Name)
	```
--]]

-- Services

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Dependencies

-- Constants

local FOLDER_NAME = "Remotes"
local IS_SERVER = RunService:IsServer()
local IS_CLIENT = RunService:IsClient()

-- Global Variables

local AllRemotes = {}
local RemoteFolder: Folder

-- Objects

local RequestFunction: RemoteFunction

-- Types

export type Remote = {
	new: (name: string) -> Remote,
	OnEvent: (self: Remote, callback: (...any) -> ()) -> RBXScriptConnection,
	OnInvoke: (self: Remote, callback: (player: Player, ...any) -> any) -> (),
	FireClient: (self: Remote, player: Player, ...any) -> (),
	FireAllClients: (self: Remote, ...any) -> (),
	FireServer: (self: Remote, ...any) -> (),
	Fire: (self: Remote, ...any) -> (),
	InvokeClient: (self: Remote, player: Player, ...any) -> any,
	InvokeServer: (self: Remote, ...any) -> any,
	Invoke: (self: Remote, ...any) -> (),
}

-- Classes

local Remote = {}
Remote.__index = Remote

function Remote.new(name): Remote
	local self = setmetatable({}, Remote)

	self._name = name
	self._event = nil :: RemoteEvent
	self._function = nil :: RemoteFunction

	AllRemotes[name] = self

	return self
end

function Remote:_getEventServer(): RemoteEvent
	if not self._event then
		self._event = Instance.new("RemoteEvent")
		self._event.Name = self._name .. "Event"
		self._event.Parent = RemoteFolder
	end

	return self._event
end

function Remote:_getEventClient(): RemoteEvent
	if not self._event then
		self._event = RemoteFolder:WaitForChild(self._name .. "Event", 3)
		if not self._event then
			self._event = RequestFunction:InvokeServer(self._name, "Event")
		end
	end

	return self._event
end

function Remote:_getFunctionServer(): RemoteFunction
	if not self._function then
		self._function = Instance.new("RemoteFunction")
		self._function.Name = self._name .. "Function"
		self._function.Parent = RemoteFolder
	end

	return self._function
end

function Remote:_getFunctionClient(): RemoteFunction
	if not self._function then
		self._function = RemoteFolder:WaitForChild(self._name .. "Function")
		if not self._function then
			self._function = RequestFunction:InvokeServer(self._name, "Function")
		end
	end

	return self._function
end

-- Connects the provided callback to the remote's event. Context is determined
-- automatically.
function Remote:OnEvent(callback): RBXScriptConnection
	if IS_SERVER then
		return self:_getEventServer().OnServerEvent:Connect(callback)
	else
		return self:_getEventClient().OnClientEvent:Connect(callback)
	end
end

Remote.OnServerEvent = Remote.OnEvent
Remote.OnClientEvent = Remote.OnEvent

-- Identical to RemoteEvent:FireClient()
function Remote:FireClient(player, ...)
	assert(IS_SERVER, "FireClient can only be called on the server")
	self:_getEventServer():FireClient(player, ...)
end

-- Identical to RemoteEvent:FireAllClients()
function Remote:FireAllClients(...)
	assert(IS_SERVER, "FireAllClients can only be called on the server")
	self:_getEventServer():FireAllClients(...)
end

-- Identical to RemoteEvent:FireServer()
function Remote:FireServer(...)
	assert(IS_CLIENT, "FireServer can only be called on the client")
	self:_getEventClient():FireServer(...)
end

-- Determines by context where to fire the event - if called from a client it
-- will use `:FireServer()`, if called from the server it will use
-- `:FireAllClients()`
function Remote:Fire(...)
	if IS_SERVER then
		self:_getEventServer():FireAllClients(...)
	else
		self:_getEventClient():FireServer(...)
	end
end

-- Identical to RemoteFunction:InvokeClient()
function Remote:InvokeClient(player: Player, ...): any
	assert(IS_SERVER, "InvokeClient can only be called on the server")
	return self:_getFunctionServer():InvokeClient(player, ...)
end

-- Identical to RemoteFunction:InvokeServer()
function Remote:InvokeServer(...): any
	assert(IS_CLIENT, "InvokeServer can only be called on the client")
	return self:_getFunctionClient():InvokeServer(...)
end

-- Determines by context where to invoke the function - if called from a client
-- it will use `:InvokeServer()`, if called from the server it will use
-- `:InvokeClient()`. If invoking a client, the first argument should be the
-- target player.
function Remote:Invoke(...): any
	if IS_SERVER then
		local args = { ... }
		local player = table.remove(args, 1)
		return self:_getFunctionServer():InvokeClient(player, table.unpack(args))
	else
		return self:_getFunctionClient():InvokeServer(...)
	end
end

-- Identical to setting RemoteFunction.OnServerInvoke or
-- RemoteFunction.OnClientInvoke to the provided callback function
function Remote:OnInvoke(callback: (any) -> ()?)
	if IS_SERVER then
		self:_getFunctionServer().OnServerInvoke = callback
	else
		self:_getFunctionClient().OnClientInvoke = callback
	end
end

Remote.OnServerInvoke = Remote.OnInvoke
Remote.OnClientInvoke = Remote.OnInvoke

-- Return function

if not RunService:IsRunning() then
	return function(name): Remote
		return Remote.new("Mock" .. name)
	end
elseif IS_SERVER then
	return function(name): Remote
		assert(type(name) == "string", "Invalid name '" .. tostring(name) .. "' - remote name must be a string")

		if not RemoteFolder then
			RemoteFolder = Instance.new("Folder")
			RemoteFolder.Name = FOLDER_NAME
			RemoteFolder.Archivable = false
			RemoteFolder.Parent = ReplicatedStorage

			RequestFunction = Instance.new("RemoteFunction")
			RequestFunction.Name = "Request"
			RequestFunction.Parent = RemoteFolder

			RequestFunction.OnServerInvoke = function(_, remoteName, remoteType)
				local remote = AllRemotes[remoteName]
				if remote then
					if remoteType == "Event" then
						return remote:_getEventServer()
					elseif remoteType == "Function" then
						return remote:_getFunctionServer()
					end
				end
			end
		end

		if AllRemotes[name] then
			return AllRemotes[name]
		end

		return Remote.new(name)
	end
else -- IS_CLIENT
	return function(name): Remote
		assert(type(name) == "string", "Invalid name '" .. tostring(name) .. "' - remote name must be a string")

		if not RemoteFolder then
			RemoteFolder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
		end

		if not RequestFunction then
			RequestFunction = RemoteFolder:WaitForChild("Request")
		end

		return Remote.new(name)
	end
end
