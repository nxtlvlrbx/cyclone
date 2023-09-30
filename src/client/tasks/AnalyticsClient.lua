--[[
	AnalyticsClient.lua
	ChiefWildin
	Version: 1.0.1

	Description:
		Initializes the GameAnalytics SDK.
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
