return {
	Name = "setdata",
	Aliases = {"set"},
	Description = "Sets the player data key with the value you provide.",
	Group = "DefaultAdmin",
	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "The players to set the data on.",
		},
        {
			Type = "string",
			Name = "key",
			Description = "The key to set with the value. Must be a path \".\" separated string. Case sensitive!",
		},
        {
			Type = "datastorevalue",
			Name = "value",
			Description = "The value that will be set.",
		},
	},
}
