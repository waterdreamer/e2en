--!strict

--[=[
	@class Server
	Server framework root class.
]=]

--[=[
	@class e2enServer
	@server

	Server-side framework API for creating and managing services.

	Access via requiring e2en on the server:
	```lua
	local e2en: Types.e2enServer = require(ServerScriptService.e2en) :: any
	```
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Types = require(script.Parent.Parent.Types)
local Dependencies = require(script.Parent.Parent.Dependencies)
local Trove = Dependencies.GetTrove()
local Comm = require(script.Parent.Comm)

type Trove = Types.Trove
type InboundMiddleware = Types.InboundMiddleware
type OutboundMiddleware = Types.OutboundMiddleware

type ServiceDefinition = {
	Name: string,
	Client: { [string]: any }?,
	Dependencies: { string }?,
	[string]: any,
}

type Service = {
	Name: string,
	Client: { [string]: any },
	Dependencies: { string }?,
	_folder: Folder?,
	[string]: any,
}

local Server = {}

local services: { [string]: Service } = {}
local started = false
local startedComplete = false
local onStartedComplete = Instance.new("BindableEvent")

local inboundMiddleware: { InboundMiddleware } = {}
local outboundMiddleware: { OutboundMiddleware } = {}

local playerTroves: { [Player]: Trove } = {}
local characterTroves: { [Player]: Trove } = {}

local playerAddedCallbacks: { (player: Player, trove: Trove) -> () } = {}
local playerRemovingCallbacks: { (player: Player) -> () } = {}
local characterAddedCallbacks: { (player: Player, character: Model, trove: Trove) -> () } = {}
local characterRemovingCallbacks: { (player: Player, character: Model) -> () } = {}

local servicesFolder: Folder

local function RunInboundMiddleware(player: Player, serviceName: string, methodName: string, args: { any }): (boolean, { any })
	local currentArgs = args
	for _, middleware in inboundMiddleware do
		local shouldContinue, newArgs = middleware(player, serviceName, methodName, currentArgs)
		if not shouldContinue then
			return false, {}
		end
		currentArgs = newArgs
	end
	return true, currentArgs
end

local function SetupServicesFolder()
	servicesFolder = Instance.new("Folder")
	servicesFolder.Name = "e2enServices"
end

local function ExposeServicesToClients()
	servicesFolder.Parent = ReplicatedStorage
end

local function ReplicateClientFramework()
	local e2enRoot = script.Parent.Parent
	local e2enClient = e2enRoot:Clone()
	e2enClient.Name = "e2en"

	local serverModule = e2enClient:FindFirstChild("Core") and e2enClient.Core:FindFirstChild("Server")
	if serverModule then
		serverModule:Destroy()
	end

	local systemsFolder = e2enClient:FindFirstChild("Systems")
	if systemsFolder then
		for _, descendant in systemsFolder:GetDescendants() do
			if descendant:IsA("ModuleScript") and descendant.Name == "Service" then
				descendant:Destroy()
			end
		end
	end

	e2enClient.Parent = ReplicatedStorage
end

local function BindClientMethod(service: Service, methodName: string, method: (any, Player, ...any) -> ...any)
	local remoteFunction = Instance.new("RemoteFunction")
	remoteFunction.Name = methodName
	remoteFunction.Parent = service._folder

	remoteFunction.OnServerInvoke = function(player: Player, ...: any)
		local args = { ... }
		local shouldContinue, processedArgs = RunInboundMiddleware(player, service.Name, methodName, args)
		if not shouldContinue then
			return nil
		end
		local result = { method(service.Client, player, table.unpack(processedArgs)) }
		return table.unpack(result)
	end
end

local function ProcessClientTable(service: Service)
	local clientTable = service.Client
	if not clientTable then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = service.Name
	folder.Parent = servicesFolder
	service._folder = folder

	clientTable.Server = service

	for key, value in clientTable do
		if key == "Server" then
			continue
		end

		if type(value) == "function" then
			BindClientMethod(service, key, value)
		elseif Comm.IsSignalMarker(value) then
			local signal = Comm.RemoteSignal.new(folder, key, false, service.Name, outboundMiddleware)
			clientTable[key] = signal
		elseif Comm.IsUnreliableSignalMarker(value) then
			local signal = Comm.RemoteSignal.new(folder, key, true, service.Name, outboundMiddleware)
			clientTable[key] = signal
		elseif Comm.IsPropertyMarker(value) then
			local property = Comm.RemoteProperty.new(folder, key, value._initialValue, service.Name, outboundMiddleware)
			clientTable[key] = property
		end
	end
end

--[=[
	Creates a new service.

	Services are server-side singletons that handle game logic. The `Client` table
	defines what is exposed to clients (signals, properties, and methods).

	```lua
	local MyService = e2en.CreateService({
		Name = "MyService",
		Client = {
			DataChanged = e2en.CreateSignal(),
			CurrentData = e2en.CreateProperty(0),
		},
	})

	function MyService:Init()
		print("Initializing")
	end

	function MyService:Start()
		print("Starting")
	end
	```

	@param definition ServiceDefinition -- The service definition table
	@return Service -- The created service
]=]
function Server.CreateService<T>(definition: ServiceDefinition & T): Service & T
	assert(not started, "Cannot create services after framework has started")

	local name = definition.Name
	assert(name, "Service must have a Name")
	assert(not services[name], `Service '{name}' already exists`)

	local service: Service = definition :: any
	service.Client = service.Client or {}

	services[name] = service

	return service :: any
end

--[=[
	Gets a service by name.

	```lua
	local DataService = e2en.GetService("DataService")
	```

	@param serviceName string -- The name of the service
	@return Service -- The service instance
	@error "Service not found" -- If no service with the given name exists
]=]
function Server.GetService(serviceName: string): Service
	local service = services[serviceName]
	assert(service, `Service '{serviceName}' not found`)
	return service
end

--[=[
	Gets all registered services.

	@return {[string]: Service} -- Dictionary of service name to service instance
]=]
function Server.GetServices(): { [string]: Service }
	return services
end

--[=[
	Loads services from direct children ModuleScripts.

	@param parent Instance -- Parent container to search
	@return {Service} -- Array of loaded services
]=]
function Server.AddServices(parent: Instance): { Service }
	local added: { Service } = {}
	for _, child in parent:GetChildren() do
		if child:IsA("ModuleScript") then
			local service = require(child) :: Service
			table.insert(added, service)
		end
	end
	return added
end

--[=[
	Loads services from all descendant ModuleScripts.

	@param parent Instance -- Parent container to search
	@return {Service} -- Array of loaded services
]=]
function Server.AddServicesDeep(parent: Instance): { Service }
	local added: { Service } = {}
	for _, descendant in parent:GetDescendants() do
		if descendant:IsA("ModuleScript") then
			local service = require(descendant) :: Service
			table.insert(added, service)
		end
	end
	return added
end

--[=[
	Loads services from `Service.luau` files in direct child folders.

	This is the recommended way to organize services. Each system folder
	contains a `Service.luau` file.

	```
	Systems/
	├── Combat/
	│   └── Service.luau  ← Loaded
	├── Inventory/
	│   └── Service.luau  ← Loaded
	```

	@param parent Instance -- Parent container with system folders
	@return {Service} -- Array of loaded services
]=]
function Server.AddSystems(parent: Instance): { Service }
	local added: { Service } = {}
	for _, systemFolder in parent:GetChildren() do
		if systemFolder:IsA("Folder") then
			local serviceModule = systemFolder:FindFirstChild("Service")
			if serviceModule and serviceModule:IsA("ModuleScript") then
				local service = require(serviceModule) :: Service?
				if service then
					table.insert(added, service)
				end
			end
		end
	end
	return added
end

--[=[
	Loads services from `Service.luau` files in all descendant folders.

	@param parent Instance -- Parent container to search recursively
	@return {Service} -- Array of loaded services
]=]
function Server.AddSystemsDeep(parent: Instance): { Service }
	local added: { Service } = {}
	for _, descendant in parent:GetDescendants() do
		if descendant:IsA("Folder") then
			local serviceModule = descendant:FindFirstChild("Service")
			if serviceModule and serviceModule:IsA("ModuleScript") then
				local service = require(serviceModule) :: Service?
				if service then
					table.insert(added, service)
				end
			end
		end
	end
	return added
end

--[=[
	Creates a signal marker for use in a Service's Client table.

	The marker is replaced with a RemoteSignal when the service is processed.

	```lua
	Client = {
		PlayerDied = e2en.CreateSignal(),
	}
	```

	@return SignalMarker
]=]
function Server.CreateSignal()
	return Comm.CreateSignalMarker()
end

--[=[
	Creates an unreliable signal marker for high-frequency, loss-tolerant data.

	Uses UnreliableRemoteEvent under the hood for lower latency.

	```lua
	Client = {
		PositionUpdate = e2en.CreateUnreliableSignal(),
	}
	```

	@return UnreliableSignalMarker
]=]
function Server.CreateUnreliableSignal()
	return Comm.CreateUnreliableSignalMarker()
end

--[=[
	Creates a property marker for replicated state.

	The marker is replaced with a RemoteProperty when the service is processed.
	Properties support per-player overrides.

	```lua
	Client = {
		Coins = e2en.CreateProperty(0),
		Inventory = e2en.CreateProperty({}),
	}
	```

	@param initialValue T -- The initial value for the property
	@return PropertyMarker<T>
]=]
function Server.CreateProperty<T>(initialValue: T)
	return Comm.CreatePropertyMarker(initialValue)
end

--[=[
	Registers a callback for when players join.

	The callback fires immediately for players already in the game.
	The trove auto-cleans when the player leaves.

	```lua
	e2en.OnPlayerAdded(function(player, trove)
		print(player.Name, "joined")
		trove:Add(createPlayerState(player))
	end)
	```

	@param callback (player: Player, trove: Trove) -> () -- The callback function
]=]
function Server.OnPlayerAdded(callback: (player: Player, trove: Trove) -> ())
	table.insert(playerAddedCallbacks, callback)

	for _, player in Players:GetPlayers() do
		local trove = playerTroves[player]
		if trove then
			task.spawn(callback, player, trove)
		end
	end
end

--[=[
	Registers a callback for when players leave.

	Use this for saving data before the player is removed.

	```lua
	e2en.OnPlayerRemoving(function(player)
		savePlayerData(player)
	end)
	```

	@param callback (player: Player) -> () -- The callback function
]=]
function Server.OnPlayerRemoving(callback: (player: Player) -> ())
	table.insert(playerRemovingCallbacks, callback)
end

--[=[
	Registers a callback for when characters spawn.

	The callback fires immediately for existing characters.
	The trove auto-cleans when the character is removed.

	```lua
	e2en.OnCharacterAdded(function(player, character, trove)
		local humanoid = character:WaitForChild("Humanoid")
		trove:Connect(humanoid.Died, function()
			print(player.Name, "died")
		end)
	end)
	```

	@param callback (player: Player, character: Model, trove: Trove) -> () -- The callback function
]=]
function Server.OnCharacterAdded(callback: (player: Player, character: Model, trove: Trove) -> ())
	table.insert(characterAddedCallbacks, callback)

	for _, player in Players:GetPlayers() do
		local character = player.Character
		local trove = characterTroves[player]
		if character and trove then
			task.spawn(callback, player, character, trove)
		end
	end
end

--[=[
	Registers a callback for when characters are removed.

	```lua
	e2en.OnCharacterRemoving(function(player, character)
		print(player.Name, "character removing")
	end)
	```

	@param callback (player: Player, character: Model) -> () -- The callback function
]=]
function Server.OnCharacterRemoving(callback: (player: Player, character: Model) -> ())
	table.insert(characterRemovingCallbacks, callback)
end

--[=[
	Gets the trove associated with a player.

	Returns nil if the player is not in the game.

	@param player Player -- The player
	@return Trove? -- The player's trove, or nil
]=]
function Server.GetPlayerTrove(player: Player): Trove?
	return playerTroves[player]
end

--[=[
	Gets the trove associated with a player's current character.

	Returns nil if the player has no character.

	@param player Player -- The player
	@return Trove? -- The character's trove, or nil
]=]
function Server.GetCharacterTrove(player: Player): Trove?
	return characterTroves[player]
end

local function HandleCharacterAdded(player: Player, character: Model)
	local trove = Trove.new()
	characterTroves[player] = trove

	for _, callback in characterAddedCallbacks do
		task.spawn(callback, player, character, trove)
	end
end

local function HandleCharacterRemoving(player: Player, character: Model)
	for _, callback in characterRemovingCallbacks do
		task.spawn(callback, player, character)
	end

	local trove = characterTroves[player]
	if trove then
		trove:Clean()
		characterTroves[player] = nil
	end
end

local function HandlePlayerAdded(player: Player)
	local trove = Trove.new()
	playerTroves[player] = trove

	trove:Add(player.CharacterAdded:Connect(function(character)
		HandleCharacterAdded(player, character)
	end))

	trove:Add(player.CharacterRemoving:Connect(function(character)
		HandleCharacterRemoving(player, character)
	end))

	if player.Character then
		HandleCharacterAdded(player, player.Character)
	end

	for _, callback in playerAddedCallbacks do
		task.spawn(callback, player, trove)
	end
end

local function HandlePlayerRemoving(player: Player)
	local characterTrove = characterTroves[player]
	if characterTrove then
		characterTrove:Clean()
		characterTroves[player] = nil
	end

	for _, callback in playerRemovingCallbacks do
		task.spawn(callback, player)
	end

	local trove = playerTroves[player]
	if trove then
		trove:Clean()
		playerTroves[player] = nil
	end
end

local function SetupPlayerLifecycle()
	Players.PlayerAdded:Connect(HandlePlayerAdded)
	Players.PlayerRemoving:Connect(HandlePlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(HandlePlayerAdded, player)
	end
end

local function TopologicalSort(): { Service }
	local sorted: { Service } = {}
	local visited: { [string]: boolean } = {}
	local visiting: { [string]: boolean } = {}

	local function visit(serviceName: string)
		if visited[serviceName] then
			return
		end
		if visiting[serviceName] then
			error(`Circular dependency detected involving '{serviceName}'`)
		end

		local service = services[serviceName]
		if not service then
			error(`Dependency '{serviceName}' not found`)
		end

		visiting[serviceName] = true

		if service.Dependencies then
			for _, depName in service.Dependencies do
				visit(depName)
			end
		end

		visiting[serviceName] = nil
		visited[serviceName] = true
		table.insert(sorted, service)
	end

	for name in services do
		visit(name)
	end

	return sorted
end

--[=[
	Starts the framework manually.

	Most users should use `e2en.Run()` instead, which handles environment
	allocation and system discovery automatically.

	@param config RunConfig? -- Optional configuration with middleware
]=]
function Server.Start(config: Types.RunConfig?): ()
	assert(not started, "Framework has already started")
	assert(RunService:IsServer(), "Server.Start can only be called on the server")

	started = true

	if config and config.Middleware then
		if config.Middleware.Inbound then
			inboundMiddleware = config.Middleware.Inbound
		end
		if config.Middleware.Outbound then
			outboundMiddleware = config.Middleware.Outbound
		end
	end

	ReplicateClientFramework()

	SetupServicesFolder()

	local sortedServices = TopologicalSort()

	for _, service in sortedServices do
		ProcessClientTable(service)
	end

	for _, service in sortedServices do
		if service.Init then
			service:Init()
		end
	end

	SetupPlayerLifecycle()

	for _, service in sortedServices do
		if service.Start then
			task.spawn(service.Start, service)
		end
	end

	ExposeServicesToClients()

	startedComplete = true
	onStartedComplete:Fire()
	onStartedComplete:Destroy()
end

--[=[
	Yields until the framework has finished starting.

	```lua
	e2en.OnStart()
	print("Framework is ready!")
	```
]=]
function Server.OnStart(): ()
	if startedComplete then
		return
	end
	onStartedComplete.Event:Wait()
end

--[=[
	Checks if the framework has finished starting.

	@return boolean -- True if the framework has started
]=]
function Server.IsStarted(): boolean
	return startedComplete
end

return Server
