# AnimData
universal Client-Server-Client data transfer using AnimationTrack speeds

[Showcase video](https://gyazo.com/56c634d9cc5494cb8596802a4439b3a3)

[Uncopylocked Roblox place](https://www.roblox.com/games/15062388889/Animation-speed-data-transfer)

## API Reference 

```lua
-- AnimData example script
local lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/someunknowndude/AnimData/refs/heads/main/AnimData.lua"))()

lib:SetDelay(0.4) -- default is 0.2, data may get corrupted for low fps users if this is set to low values. set to .4-.5 if this happens to you

local lp = game:GetService("Players").LocalPlayer
local socket = lib:Connect() -- connect to the "socket"

socket.OnMessage:Connect(function(player, message, bytes)
	print(`{player.Name}: {message}`)
	print(`raw bytes: {table.concat(bytes, " ")}`)
end)

socket.OnClose:Connect(function()
	print("closed :3")
end)

socket:Send("hello :3") -- send message synchronously
print("finished sending")

socket:SendAsync("this will take a bit") -- send message asynchronously
task.wait(.5)
print(`current state: {lib.PlayerData[lp.Name].state}`)

socket.OnMessageFinished:Wait() -- fires when currently sending message is done sending
print("message finished sending")

socket:Close() -- closes the "socket"
```
