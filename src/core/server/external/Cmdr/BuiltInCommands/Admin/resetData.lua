return {
	Name = "resetdata";
	Aliases = {"reset"};
	Description = "Resets the player data fully.";
	Group = "DefaultAdmin";
	Args = {
		{
			Type = "players";
			Name = "players";
			Description = "All of the players that you want to hard reset";
		},
	};
}
