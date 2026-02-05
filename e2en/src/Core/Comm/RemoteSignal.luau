--!strict

--[=[
	@class RemoteSignal
	@server

	Server-side signal for client-server communication.

	Created automatically when using `e2en.CreateSignal()` in a Service's
	Client table.

	```lua
	-- Server
	local MyService = e2en.CreateService({
		Name = "MyService",
		Client = {
			PlayerDied = e2en.CreateSignal(),
		},
	})

	-- Fire to one player
	self.Client.PlayerDied:Fire(player, data)

	-- Fire to all players
	self.Client.PlayerDied:FireAll(data)
	```
]=]

local Players = game:GetService("Players")

local Types = require(script.Parent.Parent.Parent.Types)

type Connection = {
	Disconnect: (self: Connection) -> (),
	Connected: boolean,
}

type OutboundMiddleware = Types.OutboundMiddleware

export type RemoteSignal<T...> = {
	Fire: (self: RemoteSignal<T...>, player: Player, T...) -> (),
	FireAll: (self: RemoteSignal<T...>, T...) -> (),
	FireFor: (self: RemoteSignal<T...>, players: { Player }, T...) -> (),
	FireExcept: (self: RemoteSignal<T...>, player: Player, T...) -> (),
	FireFilter: (self: RemoteSignal<T...>, predicate: (Player, T...) -> boolean, T...) -> (),
	Connect: (self: RemoteSignal<T...>, callback: (player: Player, T...) -> ()) -> Connection,
	Destroy: (self: RemoteSignal<T...>) -> (),
	_remote: RemoteEvent | UnreliableRemoteEvent,
	_unreliable: boolean,
	_serviceName: string,
	_signalName: string,
	_middleware: { OutboundMiddleware },
}

local RemoteSignal = {}
RemoteSignal.__index = RemoteSignal

local function RunOutboundMiddleware(
	middleware: { OutboundMiddleware },
	player: Player?,
	serviceName: string,
	signalName: string,
	args: { any }
): (boolean, { any })
	local currentArgs = args
	for _, mw in middleware do
		local shouldContinue, newArgs = mw(player, serviceName, signalName, currentArgs)
		if not shouldContinue then
			return false, {}
		end
		currentArgs = newArgs
	end
	return true, currentArgs
end

function RemoteSignal.new<T...>(
	parent: Instance,
	name: string,
	unreliable: boolean?,
	serviceName: string?,
	middleware: { OutboundMiddleware }?
): RemoteSignal<T...>
	local remoteEvent: Instance
	if unreliable then
		remoteEvent = Instance.new("UnreliableRemoteEvent")
	else
		remoteEvent = Instance.new("RemoteEvent")
	end
	remoteEvent.Name = name
	remoteEvent.Parent = parent

	local self = setmetatable({
		_remote = remoteEvent :: RemoteEvent | UnreliableRemoteEvent,
		_unreliable = unreliable or false,
		_serviceName = serviceName or "",
		_signalName = name,
		_middleware = middleware or {},
	}, RemoteSignal)

	return self :: any
end

--[=[
	Fires the signal to a specific player.

	@param player Player -- The target player
	@param ... T... -- Data to send
]=]
function RemoteSignal.Fire<T...>(self: RemoteSignal<T...>, player: Player, ...: T...)
	local args = table.pack(...)
	local shouldContinue, processedArgs = RunOutboundMiddleware(self._middleware, player, self._serviceName, self._signalName, args)
	if not shouldContinue then
		return
	end
	(self._remote :: RemoteEvent):FireClient(player, table.unpack(processedArgs))
end

--[=[
	Fires the signal to all players.

	@param ... T... -- Data to send
]=]
function RemoteSignal.FireAll<T...>(self: RemoteSignal<T...>, ...: T...)
	local args = table.pack(...)
	local shouldContinue, processedArgs = RunOutboundMiddleware(self._middleware, nil, self._serviceName, self._signalName, args)
	if not shouldContinue then
		return
	end
	(self._remote :: RemoteEvent):FireAllClients(table.unpack(processedArgs))
end

--[=[
	Fires the signal to a list of players.

	@param players {Player} -- The target players
	@param ... T... -- Data to send
]=]
function RemoteSignal.FireFor<T...>(self: RemoteSignal<T...>, players: { Player }, ...: T...)
	local remote = self._remote :: RemoteEvent
	local args = table.pack(...)
	for _, player in players do
		local shouldContinue, processedArgs = RunOutboundMiddleware(self._middleware, player, self._serviceName, self._signalName, args)
		if shouldContinue then
			remote:FireClient(player, table.unpack(processedArgs))
		end
	end
end

--[=[
	Fires the signal to all players except one.

	@param exceptPlayer Player -- The player to exclude
	@param ... T... -- Data to send
]=]
function RemoteSignal.FireExcept<T...>(self: RemoteSignal<T...>, exceptPlayer: Player, ...: T...)
	local remote = self._remote :: RemoteEvent
	local args = table.pack(...)
	for _, player in Players:GetPlayers() do
		if player ~= exceptPlayer then
			local shouldContinue, processedArgs = RunOutboundMiddleware(self._middleware, player, self._serviceName, self._signalName, args)
			if shouldContinue then
				remote:FireClient(player, table.unpack(processedArgs))
			end
		end
	end
end

--[=[
	Fires the signal to players matching a predicate.

	```lua
	self.Client.TeamUpdate:FireFilter(function(player)
		return player.Team == Teams.Red
	end, data)
	```

	@param predicate (Player, T...) -> boolean -- Filter function
	@param ... T... -- Data to send
]=]
function RemoteSignal.FireFilter<T...>(self: RemoteSignal<T...>, predicate: (Player, T...) -> boolean, ...: T...)
	local remote = self._remote :: RemoteEvent
	local args = table.pack(...)
	for _, player in Players:GetPlayers() do
		if predicate(player, ...) then
			local shouldContinue, processedArgs = RunOutboundMiddleware(self._middleware, player, self._serviceName, self._signalName, args)
			if shouldContinue then
				remote:FireClient(player, table.unpack(processedArgs))
			end
		end
	end
end

--[=[
	Connects a callback to listen for client fires.

	```lua
	self.Client.AttackRequest:Connect(function(player, target)
		handleAttack(player, target)
	end)
	```

	@param callback (player: Player, T...) -> () -- The callback function
	@return Connection -- The connection
]=]
function RemoteSignal.Connect<T...>(self: RemoteSignal<T...>, callback: (player: Player, T...) -> ()): Connection
	return (self._remote :: RemoteEvent).OnServerEvent:Connect(callback) :: any
end

--[=[
	Destroys the signal and its underlying RemoteEvent.
]=]
function RemoteSignal.Destroy<T...>(self: RemoteSignal<T...>)
	self._remote:Destroy()
end

return RemoteSignal
