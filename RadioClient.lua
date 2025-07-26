local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

-- GUI references
local radioMain = script.Parent
local chatter = radioMain:WaitForChild("Chatter")
local template = chatter:WaitForChild("template")
local messageTemplate = template:WaitForChild("message")
local panicTemplate = template:WaitForChild("panicMessage")
local titleBar = radioMain:WaitForChild("TitleBar")
local micButton = titleBar:WaitForChild("Mic")
local unitLabel = titleBar:WaitForChild("Unit")
local panicButton = titleBar:WaitForChild("Panic")
local channelSelector = titleBar:WaitForChild("Channel")
local loadingFrame = radioMain.Parent:WaitForChild("Loading")
local callsignFrame = loadingFrame:WaitForChild("CallSign")
local callsignText = callsignFrame:WaitForChild("CallsignText")
local selectButton = callsignFrame:WaitForChild("Select")

local allowedTeams = {
	["Police"] = true,
	["Fire Department"] = true,
	["SWAT"] = true,
}

local radioEvent = ReplicatedStorage:WaitForChild("RadioEvent")
local panicEvent = ReplicatedStorage:WaitForChild("PanicEvent")

local callsign = nil
local currentChannel = player.Team and player.Team.Name or "Police"
local chatConnection = nil
local micActive = false

-- Callsign selection logic
selectButton.MouseButton1Click:Connect(function()
	local input = callsignText.Text
	if input:match("^%d%d%d%d?$") then
		callsign = input
		unitLabel.Text = "- " .. callsign
		loadingFrame.Visible = false
		radioMain.Visible = true
		radioEvent:FireServer("SetCallsign", callsign)
		radioEvent:FireServer("ChangeChannel", currentChannel)
	else
		callsignFrame.TextLabel.Text = "Enter a 3-4 digit number"
	end
end)

radioMain.Visible = false
loadingFrame.Visible = true

local function updateVisibility()
	radioMain.Visible = allowedTeams[player.Team and player.Team.Name or ""] and not loadingFrame.Visible
end
player:GetPropertyChangedSignal("Team"):Connect(updateVisibility)

-- Channel selector logic (cycle channels on click)
local channels = {"Police", "Fire", "SWAT"}
local channelIdx = table.find(channels, currentChannel) or 1
channelSelector.Text = channels[channelIdx]
channelSelector.MouseButton1Click:Connect(function()
	channelIdx = channelIdx % #channels + 1
	currentChannel = channels[channelIdx]
	channelSelector.Text = currentChannel
	if callsign then
		radioEvent:FireServer("ChangeChannel", currentChannel)
	end
end)

-- Mic button toggle & chat logic
local function onChatted(msg)
	if micActive and msg and msg ~= "" then
		radioEvent:FireServer("SendMessage", msg, currentChannel)
	end
end

local function activateMic()
	micActive = true
	micButton.BackgroundColor3 = Color3.fromRGB(0, 35, 0)
	micButton.Text = "ACTIVE"
	if not chatConnection then
		chatConnection = player.Chatted:Connect(onChatted)
	end
end

local function deactivateMic()
	micActive = false
	micButton.BackgroundColor3 = Color3.fromRGB(42, 42, 42)
	micButton.Text = "INACTIVE"
	if chatConnection then
		chatConnection:Disconnect()
		chatConnection = nil
	end
end

micButton.MouseButton1Click:Connect(function()
	if micActive then
		deactivateMic()
	else
		activateMic()
	end
end)

-- Panic button (networked)
panicButton.MouseButton1Click:Connect(function()
	panicEvent:FireServer(currentChannel)
end)

-- Display networked radio messages
radioEvent.OnClientEvent:Connect(function(action, data)
	if action == "ReceiveMessage" and data then
		if currentChannel == data.channel and allowedTeams[player.Team and player.Team.Name or ""] then
			local msgFrame = messageTemplate:Clone()
			msgFrame.Visible = true
			if msgFrame:FindFirstChild("color") then
				msgFrame.color.BackgroundColor3 = data.teamColor or Color3.fromRGB(255,255,255)
			elseif msgFrame:FindFirstChild("teamColor") then
				msgFrame.teamColor.BackgroundColor3 = data.teamColor or Color3.fromRGB(255,255,255)
			end
			if msgFrame:FindFirstChild("messageText") then
				msgFrame.messageText.Text = string.format("%s - %s", data.callsign or "???", data.message)
			end
			msgFrame.Parent = chatter
			if chatter:FindFirstChildOfClass("UIListLayout") then
				chatter.CanvasSize = UDim2.new(0,0,0,chatter.UIListLayout.AbsoluteContentSize.Y)
			end
		end
	end
end)

-- Display networked panic messages
panicEvent.OnClientEvent:Connect(function(data)
	if currentChannel == data.channel and allowedTeams[player.Team and player.Team.Name or ""] then
		local panicFrame = panicTemplate:Clone()
		panicFrame.Visible = true
		if panicFrame:FindFirstChild("messageText") then
			panicFrame.messageText.Text = string.format("[%s] ***PANIC ACTIVATED***", data.callsign or "???")
		end
		panicFrame.Parent = chatter
		if chatter:FindFirstChildOfClass("UIListLayout") then
			chatter.CanvasSize = UDim2.new(0,0,0,chatter.UIListLayout.AbsoluteContentSize.Y)
		end
	end
end)

updateVisibility()