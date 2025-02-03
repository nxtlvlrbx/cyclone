local datastorevalue = {
    Transform = function (text)
		if text == "true" then
            text = true
        elseif text == "false" then
            text = false
        elseif tonumber(text) then
            text = tonumber(text)
        end

        return text
	end,

	Validate = function (value)
		if typeof(value) == "string" then
            return true
        end

        if typeof(value) == "boolean" then
            return true
        end

        if typeof(value) == "number" then
            return true
        end

        return false
	end,

	Parse = function (value)
		return value
	end,
}

return function(cmdr): ()
	cmdr:RegisterType("datastorevalue", datastorevalue)
end
