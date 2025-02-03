local TeleportService = game:GetService("TeleportService")

local rcall = shared("rcall") ---@module rcall

return function(context, players, placeId, jobId)
	players = players or { context.Executor }

	if placeId <= 0 then
		return "Invalid place ID"
	elseif jobId == "-" then
		return "Invalid job ID"
	end

	context:Reply("Teleporting...")

	local options: TeleportOptions?
	if jobId then
		options = Instance.new("TeleportOptions")
		options.ServerInstanceId = jobId
	end

	local result = rcall({retryLimit = 2, retryDelay = 3}, TeleportService.TeleportAsync, TeleportService, placeId, players, options)

	if options then
		options:Destroy()
	end

	if result then
		if jobId then
			return `Teleported {#players} players to place {placeId} (job ID {jobId})`
		else
			return `Teleported {#players} players to place {placeId}`
		end
	else
		return "Teleport failed."
	end
end
