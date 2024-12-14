-- AnimData library by smokedoutlocedout
-- Check init script to see how to use this

local lib = {}

lib.PlayerData = {}
lib.PlayerState = {
	unused = "unused",
	writing = "writing",
	idle = "idle",
}
local waitTime = 0.2

local binary = {}
local packets = {}
local tracks = {}

local players = game:GetService("Players")
local localPlayer = players.LocalPlayer
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local animate = character:WaitForChild("Animate", 1)
local onMessageEvent = Instance.new("BindableEvent")
local onCloseEvent = Instance.new("BindableEvent")
local onMessageFinishedEvent = Instance.new("BindableEvent")
local identifier = 10
local heartbeatSetup
local heartbeatLoop
local connected = false


local specialPackets = {
	clear = 	"222222",
	submit = 	"333333"
}


-- Misc.
local function addPlayerData(player)
	lib.PlayerData[player.Name] = {
		state = lib.PlayerState.idle,
		lastPacket = "",
		byteCache = ""
	}
end

local function removePlayerData(player)
	lib.PlayerData[player.Name] = nil
end

local function getId()
	if identifier == 99 then
		identifier = 10
		return tostring(identifier) 
	end
	identifier += 1
	return tostring(identifier)
end


-- Tracks
function tracks:Get(hum)
	if not (typeof(hum) == "Instance" and hum:IsA("Humanoid")) then return warn("No valid Humanoid supplied") end
	return hum:GetPlayingAnimationTracks()
end

function tracks:SetSpeed(hum, speed)
	local animTracks = tracks:Get(hum)
	for i,v in pairs(animTracks) do
		v:AdjustSpeed(speed)
	end
end

function tracks:GetSpeed(hum)
	local animTracks = tracks:Get(hum)
	if not animTracks then return warn("No valid Humanoid supplied") end
	local track = animTracks[1]
	if not track then return warn("Humanoid has no AnimationTracks") end
	
	return track.Speed
end


-- Binary
function binary:Split(byteString)
	local bytes = {}
	local index = 1

	while index <= #byteString do
		local byte = byteString:sub(index, index + 7)
		if #byte < 8 then
			byte = string.rep("0", 8 - #byte) .. byte
		end
		table.insert(bytes, byte)
		index = index + 8
	end

	return bytes
end

function binary:Encode(str)
	local res = ""
	for i, Character in utf8.codes(str) do
		local binaryChar = ""
		local byte = Character
		while byte > 0 do
			binaryChar = tostring(byte % 2) .. binaryChar
			byte = math.modf(byte / 2)
		end
		res ..= string.format("%.8d", binaryChar)
	end
	return res
end

function binary:Decode(str)
	local res = ""
	pcall(function()
		for i, binaryChar in pairs(binary:Split(str)) do
			local byte = tonumber(binaryChar, 2)
			res ..= utf8.char(byte)
		end
	end)
	return res
end

function binary:Pack(bytes)
	local packedBytes = {}
	for i, byte in pairs(bytes) do
		local half1,half2 = byte:sub(1,4),byte:sub(5,8)
		local splitByte = {half1, half2}
		table.insert(packedBytes, splitByte)
	end

	return packedBytes
end


-- Packets
function packets:SendPacket(data)
	if not data then return warn("Missing data") end

	local data = tonumber(data)
	tracks:SetSpeed(humanoid, data)
end

function packets:Clear()
	packets:SendPacket(specialPackets.clear)
end

function packets:Submit()
	packets:SendPacket(specialPackets.submit)
end

function packets:IsSpecialPacket(packet)
	for packetName, specialPacket in pairs(specialPackets) do
		if packet ~= specialPacket then continue end
		return packetName, specialPacket 
	end
	return nil
end

local testByte
function packets:Stream(data)
	local byteEncoded = binary:Encode(data)
	local splitBytes = binary:Split(byteEncoded)
	local packedBytes = binary:Pack(splitBytes)	

	local oldSpeed = tracks:GetSpeed(humanoid)

	if animate then animate.Enabled = false end
	task.wait(waitTime)
	tracks:SetSpeed(humanoid, 0)
	task.wait()
	packets:Clear()
	task.wait(waitTime)

	for i,bytePair in pairs(packedBytes) do
		local half1, half2 = bytePair[1], bytePair[2]
		local padded1, padded2 = getId()..half1, getId()..half2
		packets:SendPacket(padded1)
		task.wait(waitTime)
		packets:SendPacket(padded2)
		task.wait(waitTime)
	end

	task.wait(waitTime)
	packets:Submit()
	task.wait(waitTime)

	tracks:SetSpeed(humanoid, oldSpeed)
	if animate then animate.Enabled = true end
	onMessageFinishedEvent:Fire()
end

-- Library
local socket = {}
socket.OnClose = onCloseEvent.Event
socket.OnMessage = onMessageEvent.Event
socket.OnMessageFinished = onMessageFinishedEvent.Event

function lib:SetDelay(delayInSeconds)
	assert(delayInSeconds, "SetDelay requires a number as argument #1")
	waitTime = delayInSeconds
end

function lib:Connect()
	assert(not connected, "Already called Connect")
	connected = true
	heartbeatSetup()
	return socket
end


function socket:Close()
	assert(heartbeatLoop, "Failed to Close, not connected")
	connected = false
	onCloseEvent:Fire()
	heartbeatLoop:Disconnect()
end

function socket:Send(message)
	assert(message,"Send requires a message as argument #1")
	local message = tostring(message)
	packets:Stream(message)
end

function socket:SendAsync(message)
	assert(message,"SendAsync requires a message as argument #1")
	local message = tostring(message)
	task.spawn(socket.Send, socket, message)
end


-- Init
for i,v in pairs(players:GetPlayers()) do
	addPlayerData(v)
end
players.PlayerAdded:Connect(addPlayerData)
players.PlayerRemoving:Connect(removePlayerData)

localPlayer.CharacterAdded:Connect(function(c)
	character = c
	humanoid = character:WaitForChild("Humanoid")
	animate = character:WaitForChild("Animate", 1)
end)

heartbeatSetup = function()
	heartbeatLoop = game:GetService("RunService").Heartbeat:Connect(function()
		if not connected then return end
		for i,v in pairs(players:GetPlayers()) do
			--if v == localPlayer then continue end
			local targetCharacter = v.Character
			if not targetCharacter then continue end
			local targetHumanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
			if not targetHumanoid then continue end

			local packet = tracks:GetSpeed(targetHumanoid)
			packet = tostring(math.floor(packet))
			
			
			if #packet < 6 or packet == "1" or packet == "0" then continue end

			local dataEntry = lib.PlayerData[v.Name]
			if not dataEntry then continue end
			local lastPacket = dataEntry.lastPacket
			local state = dataEntry.state

			if packet == lastPacket then continue end
			
			
			local specialPacket, specialPacketValue = packets:IsSpecialPacket(packet)
			if specialPacket then
				if specialPacket == "clear" then
					dataEntry.byteCache = ""
				elseif specialPacket == "submit" then
					if not connected then continue end
					local byteCache = dataEntry.byteCache
					onMessageEvent:Fire(v, binary:Decode(byteCache), binary:Split(byteCache))
					dataEntry.state = lib.PlayerState.idle
				end
				dataEntry.lastPacket = specialPacketValue
				continue
			end

			dataEntry.state = lib.PlayerState.writing

			dataEntry.lastPacket = packet
			local strippedByte = packet:sub(3,-1)
			dataEntry.byteCache ..= strippedByte
		end
	end)
end

return lib
