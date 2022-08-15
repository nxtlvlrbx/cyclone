--[[
	SpringCity.lua
	ChiefWildin
	Created: 07/10/2022 @ 14:43:31

	Description:
		Dedicated to Larry. He is a good man that has no love for Tweentown. But
		everybody needs a home. So I built a new city for him. SpringCity.

	Dependencies:
		Server:
		Shared:
		Client:
		Children:
			Spring

	Documentation:
		SpringInfo
			A dictionary of spring properties to property values. There no
			required elements.

		SpringChain
			An object that allows chaining of multiple final callbacks. Use
			:AndThen() on the SpringChain to link a callback to be run when the
			spring comes to rest.
			Ex.
				SpringCity:Impulse(textButton, {Speed = 30, Damper = 0.1}, {Rotation = 30}):AndThen(function()
					textButton.Text = "Hello"
				end)

		.Register(springName: string, springInfo: SpringInfo): Spring
			Registers a new spring in SpringCity. Returns the new spring created.

		::Inquire(springName: string): Spring
			Returns the spring with the provided name. If it does not exist,
			errors or warns based on policy and returns nil.

		::Get(springName: string): Spring
			Alias for :Inquire().

		::Impulse(object: Instance, springInfo: SpringInfo, properties: {}, waitToKill: boolean?): SpringChain
			Behaves like Tweentown:Tween(), using springs instead of tweens.
			If springs are already influencing the provided object, they are
			adjusted to match the new SpringInfo and reused.
			Ex.
				SpringCity:Impulse(textButton, {Speed = 30, Damper = 0.1}, {Rotation = 30})
--]]

-- Main job table
local SpringCity = {}

-- Dependencies
---@module Spring
local Blueprint = require(script:WaitForChild("Spring"))

-- Constants
local ERROR_POLICY: "Warn" | "Error" = "Warn"
local EPSILON = 1e-4

-- Overloads
local StdError = error
local function error(message: string)
	if ERROR_POLICY == "Warn" then
		warn(message)
	else
		StdError(message)
	end
end

-- Classes and types
type Arithmetic = number | Vector2 | Vector3

export type Spring = {
	Position: Arithmetic,
	Velocity: number,
	Target: Arithmetic,
	Damper: number,
	Speed: number,
	TimeSkip: (Spring, deltaTime: number) -> (),
	Impulse: (Spring, velocity: Arithmetic) -> (),
}

-- Taken from Quenty's SpringUtils
local function springAnimating(spring, epsilon)
	epsilon = epsilon or EPSILON

	local position = spring.Position
	local target = spring.Target

	local animating
	local targetType = typeof(target)
	if targetType == "number" then
		animating = math.abs(spring.Position - spring.Target) > epsilon or math.abs(spring.Velocity) > epsilon
	elseif targetType == "Vector3" or targetType == "Vector2" then
		animating = (spring.Position - spring.Target).Magnitude > epsilon or spring.Velocity.Magnitude > epsilon
	else
		error("Unknown type")
	end

	if animating then
		return true, position
	else
		-- We need to return the target so we use the actual target value (i.e. pretend like the spring is asleep)
		return false, target
	end
end

export type SpringInfo = {
	Position: Arithmetic?,
	Velocity: number?,
	Target: Arithmetic?,
	Damper: number?,
	Speed: number?,
	Initial: Arithmetic?,
	Clock: (() -> number)?,
}

export type SpringChain = {
	_spring: Spring,
	AndThen: (SpringChain, callback: () -> ()) -> SpringChain
}

local SpringChain: SpringChain = {}
SpringChain.__index = SpringChain

function SpringChain.new(originalSpring: Spring?): SpringChain
	local this = setmetatable({}, SpringChain)
	this._spring = originalSpring

	return this
end

function SpringChain:AndThen(callback: () -> ()): SpringChain
	if self._spring then
		task.spawn(function()
			while springAnimating(self._spring) do task.wait() end
			callback()
		end)
	end
	return self :: SpringChain
end

-- Global variables
local Directory: {[string]: Spring} = {}
local Events: {[Instance]: {[string]: Spring}} = {}

-- Objects

-- Private functions
local function createSpringFromInfo(springInfo: SpringInfo): Spring
	local spring = Blueprint.new(springInfo.Initial, springInfo.Clock)
	for key, value in pairs(springInfo) do
		if key ~= "Initial" and key ~= "Clock" then
			spring[key] = value
		end
	end
	return spring
end

local function updateSpringFromInfo(spring: Spring, springInfo: SpringInfo): Spring
	for key, value in pairs(springInfo) do
		if key ~= "Initial" and key ~= "Clock" and key ~= "Position" then
			spring[key] = value
		end
	end
end

local function cleanObjectSprings(object: Instance)
	if Events[object] then
		for property, spring in pairs(Events[object]) do
			while springAnimating(spring) do task.wait() end
			Events[object][property] = nil
		end
		Events[object] = nil
	end
end

-- Public functions
function SpringCity.Register(springName: string, springInfo: SpringInfo): Spring
	local newSpring = createSpringFromInfo(springInfo)
	Directory[springName] = newSpring
	return newSpring
end

function SpringCity:Inquire(springName: string): Spring?
	if Directory[springName] then
		return Directory[springName]
	else
		error(string.format("Spring '%s' does not exist", springName))
	end
end

function SpringCity:Impulse(object: Instance, springInfo: SpringInfo, properties: {}, waitToKill: boolean?): SpringChain
	if not object then
		warn("Spring failure - invalid object passed\n" .. debug.traceback())
		return SpringChain.new()
	end

	local springChain
	for property, impulse in pairs(properties) do
		local impulseType = typeof(impulse)
		if impulseType == "Vector3" or impulseType == "Vector2" or impulseType == "number" then
			springInfo.Initial = object[property]

			if not Events[object] then
				Events[object] = {}
			end
			if not Events[object][property] then
				Events[object][property] = createSpringFromInfo(springInfo)
			else
				updateSpringFromInfo(Events[object][property], springInfo)
			end

			local newSpring = Events[object][property]

			if not springChain then
				springChain = SpringChain.new(newSpring)
			end

			newSpring:Impulse(impulse)
			task.spawn(function()
				local animating, position = springAnimating(newSpring)
				while animating do
					object[property] = position
					task.wait()
					animating, position = springAnimating(newSpring)
				end
			end)
		else
			error(string.format("Spring failure - invalid impulse type '%s' for property '%s'", impulseType, property))
		end
	end

	if waitToKill and springChain then
		cleanObjectSprings()
	else
		task.spawn(cleanObjectSprings)
	end

	return springChain :: SpringChain
end

-- Aliases
SpringCity.Get = SpringCity.Inquire

return SpringCity
