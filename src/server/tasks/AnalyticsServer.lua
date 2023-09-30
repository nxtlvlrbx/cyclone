--[[
	AnalyticsServer.lua
	ChiefWildin
    Version: 1.0.1

	Description:
		Configures and initializes the GameAnalytics SDK.
--]]

-- Main job table

local AnalyticsServer = {}

-- Dependencies

local GameAnalytics = shared("gameanalytics-sdk") ---@module gameanalytics-sdk

-- Constants

-- Global variables

-- Objects

-- Private functions

-- Public functions

-- Framework callbacks

function AnalyticsServer:Prep()
    GameAnalytics:setEnabledInfoLog(false)
    GameAnalytics:setEnabledVerboseLog(false)
    GameAnalytics:configureBuild(tostring(game.PlaceVersion))

    GameAnalytics:initialize({
        gameKey = "5c6bcb5402204249437fb5a7a80a4959", -- Sandbox key, replace with your own
        secretKey = "16813a12f718bc5c620f56944e1abc3ea13ccbac", -- Sandbox key, replace with your own
        automaticSendBusinessEvents = true,
        enableDebugLog = false,
    })
end

return AnalyticsServer
