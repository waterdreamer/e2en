local root = script.Parent.Parent.Parent
local Types = require(root.Types)

--we cast to Types.e2enServer for intellisense since the framework returns `any`
local e2en: Types.e2enServer = require(root) :: any

--the Client table is what gets exposed to clients (remotes get created automatically)
local ExampleService = e2en.CreateService({
	Name = "ExampleService",
	Client = {
		--creates a RemoteEvent, can fire to clients or listen for client fires
		CoinsChanged = e2en.CreateSignal(),

		--creates replicated state that syncs to clients automatically
		--use SetFor(player, value) to set per-player values
		Coins = e2en.CreateProperty(0),
	},

	--anything outside Client is server-only
	_coins = {} :: { [Player]: number },
})

--client methods use this syntax, player gets injected automatically by the framework
function ExampleService.Client:GetCoins(player: Player): number
	return ExampleService:GetCoins(player)
end

--client input is untrusted so we validate everything
--use `any` type for params you need to validate
function ExampleService.Client:AddCoins(player: Player, amount: any): boolean
	if typeof(amount) ~= "number" then
		return false
	end
	if amount <= 0 or amount ~= math.floor(amount) then
		return false
	end
	if amount > 1000 then
		return false
	end
	ExampleService:AddCoins(player, amount)
	return true
end

--Init runs synchronously in dependency order, before any Start calls
function ExampleService:Init()
	--fires for existing players too, not just new ones
	--the trove cleans up automatically when player leaves
	e2en.OnPlayerAdded(function(player: Player, trove: Types.Trove)
		self._coins[player] = 0
		self.Client.Coins:SetFor(player, 0)

		trove:Add(function()
			self._coins[player] = nil
		end)
	end)
end

--Start runs async after all Init calls are done
function ExampleService:Start() end

--these aren't in Client so clients can't call them directly
function ExampleService:GetCoins(player: Player): number
	return self._coins[player] or 0
end

function ExampleService:SetCoins(player: Player, amount: number)
	local previousAmount = self._coins[player] or 0
	self._coins[player] = amount
	self.Client.Coins:SetFor(player, amount)
	--Fire sends to one player, FireAll sends to everyone
	self.Client.CoinsChanged:Fire(player, amount, previousAmount)
end

function ExampleService:AddCoins(player: Player, amount: number)
	local currentCoins = self:GetCoins(player)
	self:SetCoins(player, currentCoins + amount)
end

function ExampleService:RemoveCoins(player: Player, amount: number): boolean
	local currentCoins = self:GetCoins(player)
	if currentCoins < amount then
		return false
	end
	self:SetCoins(player, currentCoins - amount)
	return true
end

function ExampleService:HasCoins(player: Player, amount: number): boolean
	return self:GetCoins(player) >= amount
end

return ExampleService
