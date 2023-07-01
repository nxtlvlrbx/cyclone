--[[
	AnalyticsClient.lua
	ChiefWildin
	Created: 05/28/2022

	Description:
		Initializes the GameAnalytics SDK.

	Documentation:
		No public API available at this time.
--]]

-- Main job table

local AnalyticsClient = {}

-- Dependencies

---@module gameanalytics-sdk
local GameAnalytics = shared("gameanalytics-sdk")

-- Constants

-- Global variables

-- Objects

-- Private functions

-- Public functions

-- Framework callbacks

function AnalyticsClient:Init()
    GameAnalytics:initClient()
end

return AnalyticsClient
