--[[ File Info
	Author: ChiefWildin
	Module: TagGroup.lua
	Version: 1.5.0

	TagGroup is a module that allows you to easily manage a group of instances
	with a specific tag.
]]

--[[ API
	.Instances: { [Instance]: true }
	    The set of all instances with the given tag. Can be iterated on with the
		following loop structure:
		```lua
			for instance in TagGroup.Instances do
				-- ...
			end
		```

	.InstanceAdded: RBXScriptSignal
	    A signal that fires whenever an instance is added to the group.

	.InstanceRemoved: RBXScriptSignal
	    A signal that fires whenever an instance is removed from the group.

	.new(tag: string): TagGroup
		Creates a new TagGroup object based on the given tag.

	:GiveSetup(callback: (instance: Instance) -> ())
		Assigns a callback function to be called on all instances in the group
	    as they are added to the group. Also applies retroactively to all
	    instances already in the group.

	:GiveCleanup(callback: (instance: Instance) -> ())
	    Assigns a callback function to be called on any instance removed from
	    the group.

	:RemoveSetup(callback: (instance: Instance) -> ())
	    Removes the given setup callback from the group.

	:RemoveCleanup(callback: (instance: Instance) -> ())
	    Removes the given cleanup callback from the group.

	:GetCount(): number
		Returns the number of instances in the group.

	:GetArray(): { Instance }
	    Returns an array of all instances in the group, as opposed to .Instances
	    which is a set.

	:GetOne(): Instance?
	    Returns the first instance from the group. Not always guaranteed to be
	    the same on repeated calls.

	:GetRandom(): Instance?
		Returns a random instance from the group.

	:WaitForOne(): Instance
		Waits for and returns the first instance from the group. Not always
	    guaranteed to be the same on repeated calls.

	:GetTaggedDescendantsIn(container: Instance): { Instance }
		Returns a table of all descendant instances of the container that are
	    also in the TagGroup (have the associated tag).
]]

-- Services

local CollectionService = game:GetService("CollectionService")

-- Types

export type TagGroup = {
	Instances: { [Instance]: true },

	InstanceAdded: RBXScriptSignal,
	InstanceRemoved: RBXScriptSignal,

	GiveSetup: (self: TagGroup, callback: (instance: Instance) -> ()) -> (),
	GiveCleanup: (self: TagGroup, callback: (instance: Instance) -> ()) -> (),
	RemoveSetup: (self: TagGroup, callback: (instance: Instance) -> ()) -> (),
	RemoveCleanup: (self: TagGroup, callback: (instance: Instance) -> ()) -> (),
	GetCount: (self: TagGroup) -> number,
	GetArray: (self: TagGroup) -> { Instance },
	GetOne: (self: TagGroup) -> Instance?,
	GetRandom: (self: TagGroup) -> Instance?,
	WaitForOne: (self: TagGroup) -> Instance,
	GetTaggedDescendantsIn: (self: TagGroup, container: Instance) -> { Instance? },

	new: (tag: string) -> TagGroup,
}

-- Module Declaration

local TagGroup: TagGroup = {}
TagGroup.__index = TagGroup

-- Public Functions

-- Assigns a callback function to be called on all instances in the group
-- as they are added to the group. Also applies retroactively to all
-- instances already in the group.
function TagGroup:GiveSetup(callback: (instance: Instance) -> ())
	for instance in self.Instances do
		task.spawn(callback, instance)
	end
	self._setup[callback] = true
end

-- Removes the given setup callback from the group.
function TagGroup:RemoveSetup(callback: (instance: Instance) -> ())
	self._setup[callback] = nil
end

-- Assigns a callback function to be called on any instance removed from
-- the group.
function TagGroup:GiveCleanup(callback: (instance: Instance) -> ())
	self._cleanup[callback] = true
end

-- Removes the given cleanup callback from the group.
function TagGroup:RemoveCleanup(callback: (instance: Instance) -> ())
	self._cleanup[callback] = nil
end

-- Returns the number of instances in the group.
function TagGroup:GetCount(): number
	local count = 0
	for _ in self.Instances do
		count += 1
	end
	return count
end

-- Returns an array of all instances in the group, as opposed to .Instances
-- which is a set.
function TagGroup:GetArray(): { Instance }
	local array = {}
	for instance in self.Instances do
		table.insert(array, instance)
	end
	return array
end

-- Returns the first instance from the group. Not always guaranteed to be the
-- same on repeated calls.
function TagGroup:GetOne(): Instance?
	local one: Instance?
	for instance in self.Instances do
		one = instance
		break
	end
	return one
end

-- Returns a random instance from the group.
function TagGroup:GetRandom(): Instance?
	local array = self:GetArray()
	return array[math.random(1, #array)]
end

-- Waits for and returns the first instance from the group. Not always
-- guaranteed to be the same on repeated calls.
function TagGroup:WaitForOne(): Instance
	local item = self:GetOne()

	if item then
		return item
	end

	return self.InstanceAdded:Wait()
end

-- Returns a table of all descendant instances of the container that are also in
-- the TagGroup (have the associated tag).
function TagGroup:GetTaggedDescendantsIn(container: Instance): { Instance }
	local tagged = {}

	for _, descendant in container:GetDescendants() do
		if self.Instances[descendant] then
			table.insert(tagged, descendant)
		end
	end

	return tagged
end

-- Creates a new TagGroup object based on the given tag.
function TagGroup.new(tag: string): TagGroup
	local self = setmetatable({
		Instances = {},
		_instanceAddedEvent = Instance.new("BindableEvent"),
		_instanceRemovedEvent = Instance.new("BindableEvent"),
		_setup = {},
		_cleanup = {},
	}, TagGroup)

	self.InstanceAdded = self._instanceAddedEvent.Event
	self.InstanceRemoved = self._instanceRemovedEvent.Event

	if typeof(tag) ~= "string" then
		warn("Attempt to create TagGroup with invalid tag:", tag, "\n" .. debug.traceback())
		return self
	end

	local function setupInstance(instance: Instance)
		self.Instances[instance] = true
		self._instanceAddedEvent:Fire(instance)
		for callback in pairs(self._setup) do
			task.spawn(callback, instance)
		end
	end

	local function cleanupInstance(instance: Instance)
		self.Instances[instance] = nil
		self._instanceRemovedEvent:Fire(instance)
		for callback in pairs(self._cleanup) do
			task.spawn(callback, instance)
		end
	end

	CollectionService:GetInstanceAddedSignal(tag):Connect(setupInstance)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(cleanupInstance)

	for _, instance in pairs(CollectionService:GetTagged(tag)) do
		setupInstance(instance)
	end

	return self
end

-- Aliases

TagGroup.AssignSetup = TagGroup.GiveSetup
TagGroup.StreamedIn = TagGroup.GiveSetup
TagGroup.AssignCleanup = TagGroup.GiveCleanup
TagGroup.StreamedOut = TagGroup.GiveCleanup

return TagGroup :: TagGroup
