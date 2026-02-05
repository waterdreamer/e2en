--!strict

--[=[
	@class ClientRemoteSignal
	@client

	Client-side signal for client-server communication.

	Obtained via `e2en.GetService()`:

	```lua
	local MyService = e2en.GetService("MyService")

	-- Listen for server fires
	MyService.PlayerDied:Connect(function(data)
		print("Received:", data)
	end)

	-- Fire to server
	MyService.PlayerDied:Fire(someData)
	```
]=]

type Connection = {
	Disconnect: (self: Connection) -> (),
	Connected: boolean,
}

export type ClientRemoteSignal<T...> = {
	Fire: (self: ClientRemoteSignal<T...>, T...) -> (),
	Connect: (self: ClientRemoteSignal<T...>, callback: (T...) -> ()) -> Connection,
	Destroy: (self: ClientRemoteSignal<T...>) -> (),
	_remote: RemoteEvent | UnreliableRemoteEvent,
}

local ClientRemoteSignal = {}
ClientRemoteSignal.__index = ClientRemoteSignal

function ClientRemoteSignal.new<T...>(remoteEvent: RemoteEvent | UnreliableRemoteEvent): ClientRemoteSignal<T...>
	local self = setmetatable({
		_remote = remoteEvent,
	}, ClientRemoteSignal)

	return self :: any
end

--[=[
	Fires the signal to the server.

	@param ... T... -- Data to send
]=]
function ClientRemoteSignal.Fire<T...>(self: ClientRemoteSignal<T...>, ...: T...)
	(self._remote :: RemoteEvent):FireServer(...)
end

--[=[
	Connects a callback to listen for server fires.

	@param callback (T...) -> () -- The callback function
	@return Connection -- The connection
]=]
function ClientRemoteSignal.Connect<T...>(self: ClientRemoteSignal<T...>, callback: (T...) -> ()): Connection
	return (self._remote :: RemoteEvent).OnClientEvent:Connect(callback) :: any
end

function ClientRemoteSignal.Destroy<T...>(_self: ClientRemoteSignal<T...>)
	-- Client doesn't own the remote, nothing to destroy
end

return ClientRemoteSignal
