local Players = game:GetService("Players")

export type RateLimiter = {
	CanProceed: (self: RateLimiter, player: Player) -> boolean,
	Reset: (self: RateLimiter, player: Player) -> (),
	Destroy: (self: RateLimiter) -> (),
}

local RateLimiter = {}
RateLimiter.__index = RateLimiter

function RateLimiter.new(cooldownSeconds: number): RateLimiter
	local self = setmetatable({
		_cooldown = cooldownSeconds,
		_lastRequest = {},
		_playerRemovingConnection = nil :: RBXScriptConnection?,
	}, RateLimiter)

	self._playerRemovingConnection = Players.PlayerRemoving:Connect(function(player: Player)
		self._lastRequest[player] = nil
	end)

	return self :: any
end

function RateLimiter:CanProceed(player: Player): boolean
	local currentTime = os.clock()
	local lastTime = self._lastRequest[player]

	if lastTime and (currentTime - lastTime) < self._cooldown then
		return false
	end

	self._lastRequest[player] = currentTime
	return true
end

function RateLimiter:Reset(player: Player)
	self._lastRequest[player] = nil
end

function RateLimiter:Destroy()
	local connection = self._playerRemovingConnection
	if connection then
		connection:Disconnect()
	end
	table.clear(self._lastRequest)
end

return RateLimiter
