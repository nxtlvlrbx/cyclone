local PlayerData = shared("PlayerData") ---@module PlayerData

return function(context, players, key, value)
	for _, player in pairs(players) do
		PlayerData:SetValue(player, string.split(key, "."), value)
	end

	return `Set data for {#players} players.`
end
