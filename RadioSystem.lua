local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local Players = game:GetService("Players")

-- RemoteEvents
local radioEvent = ReplicatedStorage:FindFirstChild("RadioEvent") or Instance.new("RemoteEvent")
radioEvent.Name = "RadioEvent"
radioEvent.Parent = ReplicatedStorage

local panicEvent = ReplicatedStorage:FindFirstChild("PanicEvent") or Instance.new("RemoteEvent")
panicEvent.Name = "PanicEvent"
panicEvent.Parent = ReplicatedStorage

local allowed = {
	["Police"] = true,
	["Fire Department"] = true,
	["SWAT"] = true,
}

local callsigns = {} -- [player] = callsign
local channels = {}  -- [player] = channel

local function getTeamColor(plr)
	if plr.Team and plr.Team.TeamColor then
		return plr.Team.TeamColor.Color
	end
	return Color3.fromRGB(255,255,255)
end

radioEvent.OnServerEvent:Connect(function(player, action, ...)
	print("IssueAC")
	if not allowed[player.Team and player.Team.Name or ""] then return end
	local args = {...}
	if action == "SetCallsign" then
		callsigns[player] = args[1]
		print("IssueBC")
	elseif action == "SendMessage" then
		print("IssueCC")
		local msg, channel = args[1], args[2]
		print("DEBUG: msg =", msg, "type:", typeof(msg))
		if typeof(msg) ~= "string" or msg == "" then return end
		channel = channel or (player.Team and player.Team.Name)
		local teamColor = getTeamColor(player)
		local playerCallsign = callsigns[player] or ""
		print("IssueDC")

		-- Filter once for all recipients
		local success, textObject = pcall(function()
			return TextService:FilterStringAsync(msg, player.UserId)
		end)
		if not success or not textObject then return end
		print("IssueEC")
		for _, other in ipairs(Players:GetPlayers()) do
			local otherChannel = channels[other] or (other.Team and other.Team.Name)
			if allowed[other.Team and other.Team.Name or ""] and otherChannel == channel then
				local filtered
				local ok, result = pcall(function()
					return textObject:GetChatForUserAsync(other.UserId)
				end)
				if ok then
					filtered = result
				else
					filtered = "[Content failed to filter]"
				end

				-- Send the formatted message to the client
				radioEvent:FireClient(other, "ReceiveMessage", {
					sender = player.Name,
					callsign = playerCallsign,
					message = filtered,
					channel = channel,
					teamColor = teamColor,
					formatType = "message" -- tells the client to use callMessage template
				})
			end
		end
	elseif action == "ChangeChannel" then
		channels[player] = args[1]
	end
end)

panicEvent.OnServerEvent:Connect(function(player, channel)
	channel = channel or channels[player] or (player.Team and player.Team.Name)
	for _, other in ipairs(Players:GetPlayers()) do
		local otherChannel = channels[other] or (other.Team and other.Team.Name)
		if allowed[other.Team and other.Team.Name or ""] and otherChannel == channel then
			panicEvent:FireClient(other, {
				sender = player.Name,
				callsign = callsigns[player] or "",
				channel = channel,
				text = "PANIC ACTIVATED!"
			})
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	callsigns[player] = nil
	channels[player] = nil
end)