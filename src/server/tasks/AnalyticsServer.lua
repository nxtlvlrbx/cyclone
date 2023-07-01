--[[
	AnalyticsServer.lua
	ChiefWildin
	Created: 05/28/2022

	Description:
		Configures and initializes the GameAnalytics SDK.

	Documentation:
		No public API available at this time.
--]]

-- Main job table

local AnalyticsServer = {}

-- Dependencies

---@module gameanalytics-sdk
local GameAnalytics = shared("gameanalytics-sdk")

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
        gameKey = "COPY GAME KEY HERE",
        secretKey = "COPY SECRET KEY HERE",
        automaticSendBusinessEvents = true,
        enableDebugLog = false,
    })
end

return AnalyticsServer
