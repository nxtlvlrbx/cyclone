--[[ File Info
	Author: ChiefWildin
	Module: TagGroup.lua
	Created: 02/22/2023
	Version: 1.2.1

	TagGroup is a module that allows you to easily manage a group of instances
	with a specific tag.
--]]

--[[ API
	.Instances: { [Instance]: true }
	    The set of all instances with the given tag. Can be iterated on with the
		following loop structure:
		```lua
			for instance in TagGroup.Instances do
				-- ...
			end
		```

	.new(tag: string): TagGroup
		Creates a new TagGroup object based on the given tag.

	:AssignSetup(callback: (instance: Instance) -> ())
		Assigns a callback function to be called on all instances in the group
	    as they are added to the group. Also applies retroactively to all
	    instances already in the group.

	:AssignCleanup(callback: (instance: Instance) -> ())
	    Assigns a callback function to be called on any instance removed from
	    the group.

	:GetCount(): number
		Returns the number of instances in the group.

	:GetArray(): { Instance }
	    Returns an array of all instances in the group, as opposed to .Instances
	    which is a set.
--]]

-- Services

local CollectionService = game:GetService("CollectionService")

-- Types

export type TagGroup = {
	Instances: { [Instance]: true },
	AssignSetup: (self: TagGroup, callback: (instance: Instance) -> ()) -> (),
	AssignCleanup: (self: TagGroup, callback: (instance: Instance) -> ()) -> (),
	GetCount: (self: TagGroup) -> number,
	GetArray: (self: TagGroup) -> { Instance },
	new: (tag: string) -> TagGroup,
}

-- Module Declaration

local TagGroup = {}
TagGroup.__index = TagGroup

-- Public Functions

-- Assigns a callback function to be called on all instances in the group
-- as they are added to the group. Also applies retroactively to all
-- instances already in the group.
function TagGroup:AssignSetup(callback: (instance: Instance) -> ())
	for instance in self.Instances do
		callback(instance)
	end
	self._setup = callback
end

-- Assigns a callback function to be called on any instance removed from
-- the group.
function TagGroup:AssignCleanup(callback: (instance: Instance) -> ())
	self._cleanup = callback
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

-- Creates a new TagGroup object based on the given tag.
function TagGroup.new(tag: string): TagGroup
	local self = setmetatable({
		Instances = {},
		_setup = nil,
		_cleanup = nil,
	}, TagGroup)

	if typeof(tag) ~= "string" then
		warn("Attempt to create TagGroup with invalid tag:", tag, "\n" .. debug.traceback())
		return self
	end

	CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
		self.Instances[instance] = true
		if self._setup then
			self._setup(instance)
		end
	end)

	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
		self.Instances[instance] = nil
		if self._cleanup then
			self._cleanup(instance)
		end
	end)

	for _, instance in pairs(CollectionService:GetTagged(tag)) do
		self.Instances[instance] = true
		if self._setup then
			self._setup(instance)
		end
	end

	return self
end

-- Aliases

TagGroup.StreamedIn = TagGroup.AssignSetup
TagGroup.StreamedOut = TagGroup.AssignCleanup

return TagGroup :: TagGroup
