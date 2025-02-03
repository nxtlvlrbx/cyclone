return {
	Name = "ban",
	Aliases = {},
	Group = "DefaultAdmin",
	Description = "Bans a player using Roblox's BanService",
	Args = {
		{
			Type = "players",
			Name = "Players",
			Description = "The player or group of players to ban."
		},
		{
			Type = "number",
			Name = "Duration",
			Description = "How long to ban the user for in days. Set to 0 for a permanent ban."
		},
		{
			Type = "string",
			Name = "PublicReason",
			Description = "The reason for the ban that will be shown to the user. (make sure to type this in quotes)"
		},
		{
			Type = "string",
			Name = "PrivateReason",
			Description = "The reason for the ban for our internal notes. (make sure to type this in quotes)"
		},
		{
			Type = "boolean",
			Name = "AlsoBanAlts",
			Description = "Whether to ban the user's known alt accounts as well."
		}
	}
}