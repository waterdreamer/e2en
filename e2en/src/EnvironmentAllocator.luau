--!strict

local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local Lighting = game:GetService("Lighting")

local EnvironmentAllocator = {}

function EnvironmentAllocator.Allocate(root: Instance)
	local starterGuiFolder = root:FindFirstChild("StarterGui")
	if starterGuiFolder then
		for _, child in starterGuiFolder:GetChildren() do
			child.Parent = StarterGui
		end
	end

	local starterPlayerScriptsFolder = root:FindFirstChild("StarterPlayerScripts")
	if starterPlayerScriptsFolder then
		for _, child in starterPlayerScriptsFolder:GetChildren() do
			child.Parent = StarterPlayer.StarterPlayerScripts
		end
	end

	local starterCharacterScriptsFolder = root:FindFirstChild("StarterCharacterScripts")
	if starterCharacterScriptsFolder then
		for _, child in starterCharacterScriptsFolder:GetChildren() do
			child.Parent = StarterPlayer.StarterCharacterScripts
		end
	end

	local lightingFolder = root:FindFirstChild("Lighting")
	if lightingFolder then
		for _, child in lightingFolder:GetChildren() do
			child.Parent = Lighting
		end
	end
end

return EnvironmentAllocator
