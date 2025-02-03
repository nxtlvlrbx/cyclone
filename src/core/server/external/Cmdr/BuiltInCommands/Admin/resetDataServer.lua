local PlayerData = shared("PlayerData") ---@module PlayerData

return function(context, players, key, value)
	for _, player in pairs(players) do
		task.spawn(PlayerData.ResetData, PlayerData, player)
	end

	return `Reset data for {#players} players.`
end
