--!strict

local RunService = game:GetService("RunService")

local Core = {}

if RunService:IsServer() then
	Core.Server = require(script.Server)
else
	Core.Client = require(script.Client)
end

return Core
