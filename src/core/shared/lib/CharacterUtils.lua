--[[ File Info

	CharacterUtils.lua
	@TactBacon
	Version: 1.6.1

	Provides utility functions for working with characters.  Adds callbacks for
	character spawning and provides a maid for cleaning up when the character is
	destroyed.

	Any function with the keyword `Local` in it will only work on the client and
	should not be called from the server.

]]

--[[ API

	::GetCharacter(player: Player | string, shouldYield: boolean?): Model?
		Get the character of a player and optionally yield until it exists
		Example:
		```lua
			local character = CharacterUtils:GetCharacter(player, true)
		```

	::GetLocalCharacter(shouldYield: boolean?): Model?
		Get the character of the local player and optionally yield until it
		exists.
		Example:
		```lua
			local character = CharacterUtils:GetLocalCharacter(true)
		```

	::GetAllCharacters(): {Model}
		Get all characters in the game.
		Example:
		```lua
			local characters = CharacterUtils:GetAllCharacters()
		```

	::GetAllNonLocalCharacters(): {Model}
		Get all characters in the game, except for the local player's character.
		Example:
		```lua
			local characters = CharacterUtils:GetAllNonLocalCharacters()
		```

	::OnCharacterSpawned(player: Player, callback: (character: Model, characterMaid: Maid) -> (), callbackName: string)
		Add a callback for when the player spawns that receives the character
	    model and a maid which will clean up any connections or running
	    functions when the player dies.

		This will run the callback immediately if the player is already spawned.
		Example:
		```lua
			CharacterUtils:OnCharacterSpawned(Players.OnlyTwentyCharacters, function(character: Model, characterMaid: Maid)
				print("Character spawned!")

				characterMaid:Add(function()
					print("Character died!")
				end)
			end, "MySpawnCallback")
		```

	::OnAnyCharacterSpawned(callback: (character: Model, characterMaid: Maid) -> (), callbackName: string)
		Add a callback for any player, existing and future, that spawns.

		This will run the callback immediately for all existing players.
		Example:
		```lua
			CharacterUtils:OnAnyCharacterSpawned(function(character: Model, characterMaid: Maid)
				print("Character spawned!")

				characterMaid:Add(function()
					print("Character died!")
				end)
			end, "MySpawnCallback")
		```

	::OnLocalCharacterSpawned(callback: (character: Model, characterMaid: Maid) -> (), callbackName: string)
		Add a callback for when the local player spawns that receives the
	    character model and a maid which will clean up any connections or
	    running functions when the player dies.

		This will run the callback immediately if the player is already spawned.
		Example:
		```lua
			CharacterUtils:OnLocalCharacterSpawned(function(character: Model, characterMaid: Maid)
				print("Character spawned!")

				characterMaid:Add(function()
					print("Character died!")
				end)
			end, "MySpawnCallback")
		```

	::RemoveOnSpawnedCallback(player: Player, callbackName: string)
		Remove a spawn callback by name from the given player.
		Example:
		```lua
			CharacterUtils:RemoveOnSpawnedCallback(Players.OnlyTwentyCharacters, "MySpawnCallback")
		```

	::RemoveOnAnySpawnedCallback(callbackName: string)
		Remove a spawn callback by name from all players.
		Example:
		```lua
			CharacterUtils:RemoveOnAnySpawnedCallback("MySpawnCallback")
		```

	::RemoveLocalOnSpawnedCallback(callbackName: string)
		Remove a spawn callback by name from the local player.
		Example:
		```lua
			CharacterUtils:RemoveLocalOnSpawnedCallback("MySpawnCallback")
		```

	::RemoveAllCallbacksForPlayer(player: Player)
		Remove all spawn callbacks for the given player.
		Example:
		```lua
			CharacterUtils:RemoveAllCallbacksForPlayer(Players.OnlyTwentyCharacters)
		```

	::RemoveAllLocalCallbacks()
		Remove all spawn callbacks for the local player.
		Example:
		```lua
			CharacterUtils:RemoveAllLocalCallbacks()
		```

	::GetCharacterMaid(player: Player): Maid
	    Get the maid for the given player.  This will create a new maid if one
	    does not already exist.
		Example:
		```lua
			local characterMaid = CharacterUtils:GetCharacterMaid(Players.OnlyTwentyCharacters)
		```

	::GetLocalCharacterMaid(): Maid
	    Get the maid for the local player.  This will create a new maid if one
	    does not already exist.
		Example:
		```lua
			local characterMaid = CharacterUtils:GetLocalCharacterMaid()
		```

	::GetChildFromCharacter(player: Player | character: Model, childName: string, shouldYield: boolean?): Instance?
		Get a child from the given player's character.  This will yield until
		the child exists if shouldYield is true.
		Example:
		```lua
			local theirHumanoid = CharacterUtils:GetChildFromCharacter(otherPlayer, "Humanoid", true)
		```

	::GetChildFromLocalCharacter(childName: string, shouldYield: boolean?): Instance?
		Get a child from the local player's character.  This will yield until
		the child exists if shouldYield is true.
		Example:
		```lua
			local myHumanoid = CharacterUtils:GetChildFromLocalCharacter("Humanoid", true)
		```

	::PlayAnimationOnCharacter(character: Model | Player, animationId: string | number, animTrackOptions: AnimTrackOptions?, shouldYield: boolean?): AnimationTrack?
		Play an animation on the given character.  This will yield until the
		character exists if shouldYield is true.
		Example:
		```lua
			local animationTrack = CharacterUtils:PlayAnimationOnCharacter(otherPlayer, 1234567890, {
				fadeTime = 0.1,
				weight = 1,
				speed = 1,
				shouldNotCache = false,
			}, true)
		```

	::PlayAnimationOnLocalCharacter(animationId: string | number, animTrackOptions: AnimTrackOptions?, shouldYield: boolean?): AnimationTrack?
		Play an animation on the local player's character.  This will yield
		until the character exists if shouldYield is true.
		Example:
		```lua
			local animationTrack = CharacterUtils:PlayAnimationOnLocalCharacter("rbxassetid://1234567890", {
				fadeTime = 0.1,
				weight = 1,
				speed = 1,
				shouldNotCache = false,
			}, true)
		```

	::GetCharacterFromPart(part: BasePart): Model?
		Get the character from a part if one exists.  Will also return NPCs.
		Example:
		```lua
			local character = CharacterUtils:GetCharacterFromPart(part)
		```
]]

-- Services

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Dependencies

local Maid = shared("Maid") ---@module Maid

-- Typing

type Maid = Maid.Maid
export type AnimTrackOptions = {
	fadeTime: number?,
	weight: number?,
	speed: number?,
	shouldNotCache: boolean?,
}

-- Main Module

local CharacterUtils = {}

-- Constants

local IS_CLIENT = RunService:IsClient()

-- Global Variables

local SpawnCallbacks = {} :: { [Player]: {} }
local AnySpawnCallbackConnections = {} :: { [string | number]: RBXScriptConnection }
local CharacterMaids = {} :: { [Player]: { Maid } }
local LocalPlayer = Players.LocalPlayer

-- Public Functions

---Get the character of a player and optionally yield until it exists
---@param player Player | string The player to get the character of or the name of the player
---@param shouldYield boolean? Whether or not to yield until the character exists (will still return nil if the player leaves the game)
---@return Model Character The character of the player if it exists
function CharacterUtils:GetCharacter(player: Player | string, shouldYield: boolean?): Model?
	if typeof(player) == "string" then
		player = Players:FindFirstChild(player)
	end

	if not player then
		return
	end

	if shouldYield then
		-- Wait for the character to exist
		while player and player.Parent and not player.Character do
			task.wait()
		end

		-- Wait for the character to be parented
		while player and player.Parent and not player.Character.Parent do
			task.wait()
		end

		-- The player left the game while we were waiting
		if not player then
			return
		end

		if not player.Parent then
			return
		end
	end

	return if player.Character and player.Character.Parent ~= nil then player.Character else nil :: Model?
end

---Get the character of the local player and optionally yield until it exists
---@param shouldYield boolean? Whether or not to yield until the character exists
---@return Model Character The character of the local player if it exists
function CharacterUtils:GetLocalCharacter(shouldYield: boolean?): Model?
	if IS_CLIENT then
		return self:GetCharacter(LocalPlayer, shouldYield)
	else
		warn(
			"GetLocalCharacter can only be called from the client, attempted to call from server.\n"
				.. debug.traceback()
		)
		return nil
	end
end

---Get all characters of players
---@return table Characters The characters of all players
function CharacterUtils:GetAllCharacters(): { Model }
	local characters = {}

	for _, player in Players:GetPlayers() do
		local character = CharacterUtils:GetCharacter(player)
		if not character then
			continue
		end

		table.insert(characters, character)
	end

	return characters
end

---Get all characters of players
---@return table Characters The characters of all players
function CharacterUtils:GetAllNonLocalCharacters(): { Model }
	local characters = {}

	for _, player in Players:GetPlayers() do
		if player == LocalPlayer then
			continue
		end

		local character = CharacterUtils:GetCharacter(player)
		if not character then
			continue
		end

		table.insert(characters, character)
	end

	return characters
end

---Add a callback for when the player spawns and provide a maid for
---cleaning up any connections or running functions when the player dies.
---
---This will run the callback immediately if the player is already spawned.
---@param player Player The player to add the callback for
---@param callback function The callback to run when the player spawns
---@param callbackName string The name of the callback to add (optional)
function CharacterUtils:OnCharacterSpawned(
	player: Player,
	callback: (character: Model, characterMaid: Maid) -> (),
	callbackName: string?
)
	if not SpawnCallbacks[player] then
		SpawnCallbacks[player] = {}
	end

	if not callbackName then
		table.insert(SpawnCallbacks[player], callback)
	else
		if SpawnCallbacks[player][callbackName] then
			warn(
				`Attempt to add OnCharacterSpawned for {player} but callback with name {callbackName} already exists\n{debug.traceback()}`
			)
			return
		end
		SpawnCallbacks[player][callbackName] = callback
	end

	if player.Character and player.Character.Parent then
		local characterMaid = CharacterUtils:GetCharacterMaid(player)
		task.spawn(callback, player.Character, characterMaid)
	end
end

---Adds a callback for any player, existing and future, that spawns.
---@param callback function (character: Model, characterMaid: Maid) -> ()
---@param callbackName string? The name of the callback to add (optional)
function CharacterUtils:OnAnyCharacterSpawned(
	callback: (character: Model, characterMaid: Maid) -> (),
	callbackName: string?
)
	for _, player: Player in pairs(Players:GetPlayers()) do
		self:OnCharacterSpawned(player, callback, callbackName)
	end

	if callbackName then
		AnySpawnCallbackConnections[callbackName] = Players.PlayerAdded:Connect(function(player: Player)
			self:OnCharacterSpawned(player, callback, callbackName)
		end)
	else
		table.insert(
			AnySpawnCallbackConnections,
			Players.PlayerAdded:Connect(function(player: Player)
				self:OnCharacterSpawned(player, callback, callbackName)
			end)
		)
	end
end

---Add a callback for when the local player spawns and provide a maid for
---cleaning up any connections or running functions when the player dies.
---@param callback function(character: Model, characterMaid: Maid) -> () The callback to run when the player spawns
---@param callbackName string? The name of the callback to add (optional)
function CharacterUtils:OnLocalCharacterSpawned(
	callback: (character: Model, characterMaid: Maid) -> (),
	callbackName: string?
)
	if IS_CLIENT then
		self:OnCharacterSpawned(LocalPlayer, callback, callbackName)
	else
		warn(
			"OnLocalCharacterSpawned can only be called from the client, attempted to call from server.\n"
				.. debug.traceback()
		)
	end
end

---Remove a callback for when the player spawns
---@param player Player The player to remove the callback for
---@param callbackName string The name of the callback to remove
function CharacterUtils:RemoveOnSpawnedCallback(player: Player, callbackName: string)
	if not SpawnCallbacks[player] then
		warn(
			`Attempt to remove CharacterSpawnCallback ({callbackName}) for {player} but no callbacks exist\n{debug.traceback()}`
		)
		return
	end
	SpawnCallbacks[player][callbackName] = nil
end

---Remove a callback for when the local player spawns
---@param callbackName string The name of the callback to remove
function CharacterUtils:RemoveLocalOnSpawnedCallback(callbackName: string)
	if IS_CLIENT then
		self:RemoveOnSpawnedCallback(LocalPlayer, callbackName)
	else
		warn(
			"RemoveLocalOnSpawnedCallback can only be called from the client, attempted to call from server.\n"
				.. debug.traceback()
		)
	end
end

---Remove a callback for all players when they spawn, future and existing
---@param callbackName string The name of the callback to remove
function CharacterUtils:RemoveOnAnySpawnedCallback(callbackName: string)
	for _, player: Player in (Players:GetPlayers()) do
		self:RemoveOnSpawnedCallback(player, callbackName)
	end

	if AnySpawnCallbackConnections[callbackName] then
		AnySpawnCallbackConnections[callbackName]:Disconnect()
		AnySpawnCallbackConnections[callbackName] = nil
	end
end

---Remove all callbacks for when the player spawns
---@param player Player The player to remove the callbacks for
function CharacterUtils:RemoveAllCallbacksForPlayer(player: Player)
	SpawnCallbacks[player] = {}
end

---Remove all callbacks for when the local player spawns
function CharacterUtils:RemoveAllLocalCallbacks()
	if IS_CLIENT then
		self:RemoveAllCallbacksForPlayer(LocalPlayer)
	else
		warn(
			"RemoveAllLocalCallbacks can only be called from the client, attempted to call from server.\n"
				.. debug.traceback()
		)
	end
end

---Get the maid for the player's character
---@param player Player The player to get the CharacterMaid for
---@return table Maid The CharacterMaid for the player
function CharacterUtils:GetCharacterMaid(player: Player): Maid
	if not player then
		return
	end
	if not CharacterMaids[player] then
		CharacterMaids[player] = Maid.new()
	end
	return CharacterMaids[player]
end

---Get the maid for the local player's character
---@return table Maid The CharacterMaid for the local player
function CharacterUtils:GetLocalCharacterMaid(): Maid
	if IS_CLIENT then
		return self:GetCharacterMaid(LocalPlayer)
	else
		warn(
			"GetLocalCharacterMaid can only be called from the client, attempted to call from server.\n"
				.. debug.traceback()
		)
		return nil
	end
end

---Retrieves a child from a player's character
---@param player | Model Player The player to get the child from or alternatively their character
---@param childName string The name of the child to get
---@return Instance? Instance The child if it exists
function CharacterUtils:GetChildFromCharacter(
	player: Player | Model,
	childName: string,
	shouldYield: boolean?
): Instance?
	local character
	if typeof(player) == "Instance" and player:IsA("Model") then
		character = player
	else
		character = CharacterUtils:GetCharacter(player, shouldYield)
	end
	if not character then
		return
	end
	return if shouldYield then character:WaitForChild(childName) else character:FindFirstChild(childName)
end

---Retrieves a child from the local player's character
---@param childName string The name of the child to get
---@return Instance? Instance The child if it exists
function CharacterUtils:GetChildFromLocalCharacter(childName: string, shouldYield: boolean?): Instance?
	if IS_CLIENT then
		return CharacterUtils:GetChildFromCharacter(LocalPlayer, childName, shouldYield)
	else
		warn(
			"GetChildFromLocalCharacter can only be called from the client, attempted to call from server.\n"
				.. debug.traceback()
		)
		return nil
	end
end

---Plays an animation on a character
---@param character Model | Player The character to play the animation on (can pass a player to play the animation on their character)
---@param animationId string | number The id of the animation to play, can be a string or number
---@param animTrackOptions table? The options to pass to the animation track on play as well as whether or not to cache the animation track
---@param shouldYield boolean? Whether or not to yield until the character exists
---@return AnimationTrack? AnimationTrack The animation track if it was successfully played
function CharacterUtils:PlayAnimationOnCharacter(
	character: Model | Player,
	animationId: string | number,
	animTrackOptions: AnimTrackOptions?,
	shouldYield: boolean?
): AnimationTrack?
	assert(typeof(character) == "Instance", "character must be an Instance, given: " .. typeof(character))
	assert(
		character:IsA("Model") or character:IsA("Player"),
		"character must be a Model or a Player, given: " .. character.ClassName
	)

	local playerObject
	if character:IsA("Player") then
		playerObject = character
		character = CharacterUtils:GetCharacter(character, shouldYield)
	else
		playerObject = Players:GetPlayerFromCharacter(character)
	end

	if not character then
		warn("Could not play animation, character not found")
		return
	end

	if not character:IsDescendantOf(workspace) then
		warn("Could not play animation, character is not a descendant of workspace")
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
		or character:FindFirstChildOfClass("AnimationController")
	if shouldYield and not humanoid then
		humanoid = character:WaitForChild("Humanoid")
	end
	if not humanoid then
		warn(`Could not play animation, Humanoid/AnimationController not found in {character}`)
		return
	end

	animTrackOptions = animTrackOptions or {}
	animationId = string.match(animationId, "%d+") or animationId

	if not animationId then
		warn(`Cannot play animation, invalid animationId, given: {animationId}`)
		return
	end

	local characterMaid
	if playerObject then
		characterMaid = CharacterUtils:GetCharacterMaid(playerObject)
		if characterMaid[`Anim.{animationId}`] then
			characterMaid[`Anim.{animationId}`]:Play()
			return characterMaid[`Anim.{animationId}`]
		end
	end

	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local animation = Instance.new("Animation")
	animation.AnimationId = `rbxassetid://{animationId}`
	local animationTrack = animator:LoadAnimation(animation)

	if characterMaid and not animTrackOptions.shouldNotCache then
		characterMaid[`Anim.{animationId}`] = animationTrack
	end

	animationTrack:Play(animTrackOptions.fadeTime, animTrackOptions.weight, animTrackOptions.speed)

	if animTrackOptions.shouldNotCache then
		animationTrack.Ended:Once(function()
			animationTrack:Destroy()
		end)
	end

	return animationTrack
end

---Plays an animation on the local player's character
---@param animationId string | number The id of the animation to play, can be a string or number
---@param animTrackOptions table? The options to pass to the animation track on play as well as whether or not to cache the animation track
---@param shouldYield boolean? Whether or not to yield until the character exists
---@return AnimationTrack? AnimationTrack The animation track if it was successfully played
---Example:
---```lua
---local animationTrack = CharacterUtils:PlayAnimationOnLocalCharacter("rbxassetid://1234567890", {
---	fadeTime = 0.1,
---	weight = 1,
---	speed = 1,
---	shouldNotCache = false,
---}, true)
---```
function CharacterUtils:PlayAnimationOnLocalCharacter(
	animationId: string | number,
	animTrackOptions: AnimTrackOptions?,
	shouldYield: boolean?
): AnimationTrack?
	if IS_CLIENT then
		return self:PlayAnimationOnCharacter(LocalPlayer, animationId, animTrackOptions, shouldYield)
	else
		warn(
			"PlayAnimationOnLocalCharacter can only be called from the client, attempted to call from server.\n"
				.. debug.traceback()
		)
		return nil
	end
end

---Gets the character from a part if one exists.  Will also return NPCs.
---@param part BasePart The part to get the character from
---@return Model? Character The character if one exists
function CharacterUtils:GetCharacterFromPart(part: BasePart): Model?
	local character = part:FindFirstAncestorOfClass("Model")
	local humanoid
	while character and not humanoid do
		humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			break
		end
		character = character:FindFirstAncestorOfClass("Model")
	end
	return character
end

-- Initialization

do
	local function onPlayerAdded(player: Player)
		local characterMaid = CharacterUtils:GetCharacterMaid(player)

		player.CharacterAdded:Connect(function(character)
			if not SpawnCallbacks[player] then
				SpawnCallbacks[player] = {}
			end

			for _, callback in SpawnCallbacks[player] do
				task.spawn(callback, character, characterMaid)
			end
		end)

		player.CharacterRemoving:Connect(function(_)
			characterMaid:DoCleaning()
		end)

		if player.Character and SpawnCallbacks[player] then
			for _, callback in SpawnCallbacks[player] do
				task.spawn(callback, player.Character, characterMaid)
			end
		end
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		if CharacterMaids[player] then
			CharacterMaids[player]:DoCleaning()
			CharacterMaids[player] = nil
		end
		SpawnCallbacks[player] = nil
	end)
end

-- Return

return CharacterUtils
