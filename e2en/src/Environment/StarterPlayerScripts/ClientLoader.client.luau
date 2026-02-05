--!nocheck

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local e2en = require(ReplicatedStorage:WaitForChild("e2en"))
e2en.AddSystems(e2en.Systems)
e2en.Start()
