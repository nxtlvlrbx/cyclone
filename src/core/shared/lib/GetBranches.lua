local AssetService = game:GetService("AssetService")

local rcall = shared("rcall") ---@module rcall

local FirstRun = false
local BranchCache = {}

return function(resetCache: boolean?)
	local function cacheBranches()
		local places: StandardPages =
			rcall({ retryLimit = 3, retryDelay = 5, silent = true }, AssetService.GetGamePlacesAsync, AssetService)
		if not places then
			return
		end

		while true do
			for _, place in places:GetCurrentPage() do
				table.insert(BranchCache, {
					Name = place.Name,
					Id = place.PlaceId,
				})
			end

			if places.IsFinished then
				break
			end

			places:AdvanceToNextPageAsync()
			task.wait()
		end
	end

	if resetCache or not FirstRun then
		BranchCache = {}
		FirstRun = true
		cacheBranches()
	end

	return BranchCache
end
