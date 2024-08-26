local SourceRcon = require('sourcercon')
local timer = require('timer')

local SourceRcon = SourceRcon.SourceRcon

local server = SourceRcon:new("127.0.0.1:27015")
server:LoginToServer("kakoyto-parol")

local function callback(callback)
	print(callback)
end

timer.setInterval(5000, function()
	server:Send("status", callback)
end)