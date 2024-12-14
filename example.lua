-- AnimData example script

local lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/someunknowndude/AnimData/refs/heads/main/AnimData.lua"))()

lib:SetDelay(0.4) -- default is 0.2, data may get corrupted for low fps users if this is set to low values. set to .4-.5 if this happens to you

local lp = game:GetService("Players").LocalPlayer
local socket = lib:Connect()

socket.OnMessage:Connect(function(player, message, bytes)
	print(`{player.Name}: {message}`)
	print(`raw bytes: {table.concat(bytes, " ")}`)
end)

socket.OnClose:Connect(function()
	print("closed :3")
end)

socket:Send("hello :3")
print("finished sending")

socket:SendAsync("this will take a bit")
task.wait(.5)
print(`current state: {lib.PlayerData[lp.Name].state}`)

socket.OnMessageFinished:Wait()
print("message finished sending")

socket:Close()
