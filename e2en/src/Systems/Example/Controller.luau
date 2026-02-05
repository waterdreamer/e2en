local root = script.Parent.Parent.Parent
local Types = require(root.Types)

local e2en: Types.e2enClient = require(root) :: any

--define what the service proxy looks like for intellisense
--this should match whatever you put in the Service's Client table
type ExampleServiceProxy = {
	CoinsChanged: Types.ClientRemoteSignal<number, number>,
	Coins: Types.ClientRemoteProperty<number>,
	GetCoins: (self: ExampleServiceProxy) -> number,
	AddCoins: (self: ExampleServiceProxy, amount: number) -> boolean,
}

local ExampleController = e2en.CreateController({
	Name = "ExampleController",

	_exampleService = nil :: ExampleServiceProxy?,
})

function ExampleController:Init()
	--this gives you a proxy to the service's Client table
	--methods become RemoteFunctions, signals become RemoteEvents, etc
	self._exampleService = e2en.GetService("ExampleService") :: ExampleServiceProxy
end

function ExampleController:Start()
	local exampleService = self._exampleService :: ExampleServiceProxy

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
	local exampleService = self._exampleService :: ExampleServiceProxy
	--Get() returns the cached value instantly, no network call
	return exampleService.Coins:Get()
end

function ExampleController:RequestAddCoins(amount: number): boolean
	local exampleService = self._exampleService :: ExampleServiceProxy
	--calling methods on the proxy invokes a RemoteFunction (yields)
	return exampleService:AddCoins(amount)
end

return ExampleController
