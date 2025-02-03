--[[ File Info

	Author(s): ChiefWildin
	Module: DebugRaycast.lua
	Version: 1.0.0

]]

-- Services

local Debris = game:GetService("Debris")

-- Module Declaration

local DebugRaycast = {}

-- Constants

local DEFAULT_HIT_COLOR = Color3.fromRGB(0, 255, 0)
local DEFAULT_MISS_COLOR = Color3.fromRGB(255, 0, 0)

-- Global Variables

local Container: Folder?

-- Private Functions

local function getContainer()
	if not Container then
		Container = Instance.new("Folder")
		Container.Name = "DebugRaycast"
		Container.Parent = workspace
	end

	return Container
end

local function createDebugPart(
	color: Color3,
	cframe: CFrame,
	size: Vector3,
	shape: Enum.PartType,
	transparency: number?,
	duration: number?
)
	local debugPart = Instance.new("Part")
	debugPart.Anchored = true
	debugPart.CanCollide = false
	debugPart.CanQuery = false
	debugPart.CanTouch = false
	debugPart.CastShadow = false
	debugPart.Color = color
	debugPart.Material = Enum.Material.Neon
	debugPart.CFrame = cframe
	debugPart.Shape = shape
	debugPart.Size = size
	debugPart.Transparency = transparency or 0.5
	debugPart.Parent = getContainer()

	if duration then
		Debris:AddItem(debugPart, duration)
	end

	return debugPart
end

-- Public Functions

function DebugRaycast:Spherecast(
	position: Vector3,
	radius: number,
	direction: Vector3,
	params: RaycastParams?,
	hitColor: Color3?,
	missColor: Color3?,
	transparency: number?,
	duration: number?
)
	local raycastResult = workspace:Spherecast(position, radius, direction, params)
	hitColor = hitColor or DEFAULT_HIT_COLOR
	missColor = missColor or DEFAULT_MISS_COLOR
	local color = raycastResult and hitColor or missColor
	local endPos = raycastResult and raycastResult.Position or position + direction

	-- Start
	createDebugPart(
		color,
		CFrame.new(position),
		Vector3.new(radius * 2, radius * 2, radius * 2),
		Enum.PartType.Ball,
		transparency,
		duration
	)
	-- Middle
	createDebugPart(
		color,
		CFrame.new(position:Lerp(endPos, 0.5))
			* CFrame.new(position, endPos).Rotation
			* CFrame.Angles(0, math.pi / 2, 0),
		Vector3.new((position - endPos).Magnitude, radius * 2, radius * 2),
		Enum.PartType.Cylinder,
		transparency,
		duration
	)
	-- End
	createDebugPart(
		color,
		CFrame.new(endPos),
		Vector3.new(radius * 2, radius * 2, radius * 2),
		Enum.PartType.Ball,
		transparency,
		duration
	)

	return raycastResult
end

function DebugRaycast:Blockcast(
	cframe: CFrame,
	size: Vector3,
	direction: Vector3,
	params: RaycastParams?,
	hitColor: Color3?,
	missColor: Color3?,
	transparency: number?,
	duration: number?
)
	local raycastResult = workspace:Blockcast(cframe, size, direction, params)
	hitColor = hitColor or DEFAULT_HIT_COLOR
	missColor = missColor or DEFAULT_MISS_COLOR
	local color = raycastResult and hitColor or missColor
	local endPos = raycastResult and raycastResult.Position or cframe.Position + direction

	createDebugPart(
		color,
		CFrame.new(cframe.Position:Lerp(endPos, 0.5)) * CFrame.new(cframe.Position, endPos).Rotation,
		Vector3.new(size.X, size.Y, (cframe.Position - endPos).Magnitude),
		Enum.PartType.Block,
		transparency,
		duration
	)

	return raycastResult
end

function DebugRaycast:Raycast(
	origin: Vector3,
	direction: Vector3,
	raycastParams: RaycastParams?,
	hitColor: Color3?,
	missColor: Color3?,
	thickness: number?,
	transparency: number?,
	duration: number?
): RaycastResult?
	local raycastResult = workspace:Raycast(origin, direction, raycastParams)
	hitColor = hitColor or DEFAULT_HIT_COLOR
	missColor = missColor or DEFAULT_MISS_COLOR
	local color = raycastResult and hitColor or missColor
	local endPos = raycastResult and raycastResult.Position or origin + direction

	createDebugPart(
		color,
		CFrame.new(origin:Lerp(endPos, 0.5)) * CFrame.new(origin, endPos).Rotation,
		Vector3.new(thickness, thickness, (origin - endPos).Magnitude),
		Enum.PartType.Block,
		transparency,
		duration
	)

	return raycastResult
end

return DebugRaycast
