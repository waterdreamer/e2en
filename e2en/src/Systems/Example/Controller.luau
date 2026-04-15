local root = script.Parent.Parent.Parent
local Types = require(root.Types)
local ClientTypes = require(script.Parent.Shared.ClientTypes)

local e2en: Types.e2enClient = require(root) :: any

local ExampleController = e2en.CreateController({
	Name = "ExampleController",
})

--typed service proxy gives full autocomplete on signals, properties, and methods
local exampleService: ClientTypes.ExampleServiceProxy

function ExampleController:Init()
	--this gives you a proxy to the service's Client table
	--methods become RemoteFunctions, signals become RemoteEvents, etc
	exampleService = e2en.GetService("ExampleService") :: ClientTypes.ExampleServiceProxy
end

function ExampleController:Start()
	--Observe fires immediately with current value, then again on every change
	exampleService.Coins:Observe(function(newCoins: number)
		self:OnCoinsUpdated(newCoins)
	end)

	--Connect only fires when the server actually fires the signal
	exampleService.CoinsChanged:Connect(function(newCoins: number, previousCoins: number)
		self:OnCoinsChanged(newCoins, previousCoins)
	end)
end

--stub methods, override these or hook into them from your UI controller
function ExampleController:OnCoinsUpdated(_coins: number)
end

function ExampleController:OnCoinsChanged(newCoins: number, previousCoins: number)
	local difference = newCoins - previousCoins
	if difference > 0 then
		self:OnCoinsGained(difference)
	elseif difference < 0 then
		self:OnCoinsSpent(math.abs(difference))
	end
end

function ExampleController:OnCoinsGained(_amount: number)
end

function ExampleController:OnCoinsSpent(_amount: number)
end

function ExampleController:GetCoins(): number
	--Get() returns the cached value instantly, no network call
	return exampleService.Coins:Get()
end

function ExampleController:RequestAddCoins(amount: number): boolean
	--calling methods on the proxy invokes a RemoteFunction (yields)
	return exampleService:AddCoins(amount)
end

return ExampleController
