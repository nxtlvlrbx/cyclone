-- Services
local TeleportService = game:GetService("TeleportService")

-- Dependencies
local GetBranches = shared("GetBranches") ---@module GetBranches

return function(_, branch: string, players: {Player})
	if not branch then
		return
	end

	local branches = GetBranches()

	local branchId = nil
	for _, b in branches do
		if string.lower(b.Name) == branch:lower() then
			branchId = b.Id
			break
		end
	end

	if not branchId then
		return "Invalid branch"
	end

	TeleportService:TeleportAsync(branchId, players)

	return `Teleporting {#players} players to branch {branch}`
end