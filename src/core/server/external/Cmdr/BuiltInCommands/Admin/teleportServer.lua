return function (_, fromPlayers, destination)
	local cframe
	local destinationType = typeof(destination)

	if destinationType == "Instance" then
		if destination.Character and destination.Character.PrimaryPart then
			cframe = destination.Character:GetPivot()
		else
			return `{destination.Name} has no valid character.`
		end
	elseif destinationType == "Vector3" then
		cframe = CFrame.new(destination)
	else
		return `Invalid destination type ({destinationType}) specified.`
	end

	for _, player in ipairs(fromPlayers) do
		if player.Character and player.Character.PrimaryPart then
			player.Character:PivotTo(cframe)
		end
	end

	return `Teleported {#fromPlayers} players.`
end
