--[[
	Author(s): ChiefWildin
	Module: Permissions.lua
	Version: 1.1.0

	Determines who is allowed to run commands with cmdr.
]]

-- Dependencies

local PermissionService = shared("PermissionService") ---@module PermissionService

-- Constants

-- Contractor allowed commands
local CONTRACTOR_COMMANDS = {
	"weapon",
	"branch",
}

-- Moderator allowed commands
local MOD_COMMANDS = {
	"kick",
	"boot",
	"ban",
	"banid",
	"banuser",
	"unban",
	"unbanid",
	"unbanuser",
}

-- Public Functions

return function(registry)
	registry:RegisterHook("BeforeRun", function(context)
		local hasPermission: boolean = PermissionService:HasPermission(context.Executor, "cmdr")
			or (table.find(CONTRACTOR_COMMANDS, context.Alias) ~= nil and PermissionService:HasPermission(
				context.Executor,
				"contractor"
			))
			or (
				table.find(MOD_COMMANDS, context.Alias) ~= nil
				and PermissionService:HasPermission(context.Executor, "mod")
			)
		if not hasPermission then
			return "You don't have permission to run this command"
		end

		return nil
	end)
end
