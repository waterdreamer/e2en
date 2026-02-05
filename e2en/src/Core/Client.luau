--!strict

--[=[
	@class Client
	Client framework root class.
]=]

--[=[
	@class e2enClient
	@client

	Client-side framework API for creating and managing controllers.

	Access via requiring e2en on the client:
	```lua
	local e2en: Types.e2enClient = require(ReplicatedStorage.e2en) :: any
	```
]=]

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Types = require(script.Parent.Parent.Types)
local Dependencies = require(script.Parent.Parent.Dependencies)
local Trove = Dependencies.GetTrove()
local Comm = require(script.Parent.Comm)

type Trove = Types.Trove

type ControllerDefinition = {
	Name: string,
	Dependencies: { string }?,
	[string]: any,
}

type Controller = {
	Name: string,
	Dependencies: { string }?,
	[string]: any,
}

type ServiceProxy = {
	[string]: any,
}

local Client = {}

Client.Player = Players.LocalPlayer :: Player

local controllers: { [string]: Controller } = {}
local serviceProxies: { [string]: ServiceProxy } = {}
local started = false
local startedComplete = false
local onStartedComplete = Instance.new("BindableEvent")

local characterTrove: Trove? = nil

local characterAddedCallbacks: { (character: Model, trove: Trove) -> () } = {}
local characterRemovingCallbacks: { (character: Model) -> () } = {}

local servicesFolder: Folder? = nil

local function GetServicesFolder(): Folder
	if servicesFolder then
		return servicesFolder
	end
	local folder = ReplicatedStorage:WaitForChild("e2enServices") :: Folder
	servicesFolder = folder
	return folder
end

local function BuildServiceProxy(serviceName: string): ServiceProxy
	local folder = GetServicesFolder():WaitForChild(serviceName) :: Folder
	local proxy: ServiceProxy = {}

	for _, child in folder:GetChildren() do
		if child:IsA("RemoteFunction") then
			if child.Name:match("_Get$") then
				continue
			end
			proxy[child.Name] = function(_self: any, ...: any)
				return child:InvokeServer(...)
			end
		elseif child:IsA("RemoteEvent") or child:IsA("UnreliableRemoteEvent") then
			local getRemote = folder:FindFirstChild(child.Name .. "_Get") :: RemoteFunction?
			if getRemote then
				-- RemoteProperty only uses RemoteEvent (not unreliable)
				proxy[child.Name] = Comm.ClientRemoteProperty.new(child :: RemoteEvent, getRemote)
			else
				-- RemoteSignal can be either RemoteEvent or UnreliableRemoteEvent
				proxy[child.Name] = Comm.ClientRemoteSignal.new(child :: RemoteEvent | UnreliableRemoteEvent)
			end
		end
	end

	return proxy
end

--[=[
	Creates a new controller.

	Controllers are client-side singletons that handle local game logic and UI.

	```lua
	local MyController = e2en.CreateController({
		Name = "MyController",
	})

	function MyController:Init()
		print("Initializing")
	end

	function MyController:Start()
		print("Starting")
	end
	```

	@param definition ControllerDefinition -- The controller definition table
	@return Controller -- The created controller
]=]
function Client.CreateController<T>(definition: ControllerDefinition & T): Controller & T
	assert(not started, "Cannot create controllers after framework has started")

	local name = definition.Name
	assert(name, "Controller must have a Name")
	assert(not controllers[name], `Controller '{name}' already exists`)

	local controller: Controller = definition :: any
	controllers[name] = controller

	return controller :: any
end

--[=[
	Gets a controller by name.

	Can only be called after the framework has started.

	```lua
	local UIController = e2en.GetController("UIController")
	```

	@param controllerName string -- The name of the controller
	@return Controller -- The controller instance
	@error "Controller not found" -- If no controller with the given name exists
]=]
function Client.GetController(controllerName: string): Controller
	assert(started, "Cannot get controllers before framework has started")
	local controller = controllers[controllerName]
	assert(controller, `Controller '{controllerName}' not found`)
	return controller
end

--[=[
	Gets all registered controllers.

	@return {[string]: Controller} -- Dictionary of controller name to instance
]=]
function Client.GetControllers(): { [string]: Controller }
	return controllers
end

--[=[
	Loads controllers from direct children ModuleScripts.

	@param parent Instance -- Parent container to search
	@return {Controller} -- Array of loaded controllers
]=]
function Client.AddControllers(parent: Instance): { Controller }
	local added: { Controller } = {}
	for _, child in parent:GetChildren() do
		if child:IsA("ModuleScript") then
			local controller = require(child) :: Controller
			table.insert(added, controller)
		end
	end
	return added
end

--[=[
	Loads controllers from all descendant ModuleScripts.

	@param parent Instance -- Parent container to search
	@return {Controller} -- Array of loaded controllers
]=]
function Client.AddControllersDeep(parent: Instance): { Controller }
	local added: { Controller } = {}
	for _, descendant in parent:GetDescendants() do
		if descendant:IsA("ModuleScript") then
			local controller = require(descendant) :: Controller
			table.insert(added, controller)
		end
	end
	return added
end

--[=[
	Loads controllers from `Controller.luau` files in direct child folders.

	@param parent Instance -- Parent container with system folders
	@return {Controller} -- Array of loaded controllers
]=]
function Client.AddSystems(parent: Instance): { Controller }
	local added: { Controller } = {}
	for _, systemFolder in parent:GetChildren() do
		if systemFolder:IsA("Folder") then
			local controllerModule = systemFolder:FindFirstChild("Controller")
			if controllerModule and controllerModule:IsA("ModuleScript") then
				local controller = require(controllerModule) :: Controller?
				if controller then
					table.insert(added, controller)
				end
			end
		end
	end
	return added
end

--[=[
	Loads controllers from `Controller.luau` files in all descendant folders.

	@param parent Instance -- Parent container to search recursively
	@return {Controller} -- Array of loaded controllers
]=]
function Client.AddSystemsDeep(parent: Instance): { Controller }
	local added: { Controller } = {}
	for _, descendant in parent:GetDescendants() do
		if descendant:IsA("Folder") then
			local controllerModule = descendant:FindFirstChild("Controller")
			if controllerModule and controllerModule:IsA("ModuleScript") then
				local controller = require(controllerModule) :: Controller?
				if controller then
					table.insert(added, controller)
				end
			end
		end
	end
	return added
end

--[=[
	Gets a proxy to a server service.

	The proxy provides access to the service's Client table:
	signals, properties, and methods.

	```lua
	local ShopService = e2en.GetService("ShopService")

	-- Call methods
	local items = ShopService:GetItems()

	-- Listen to signals
	ShopService.ItemAdded:Connect(function(item)
		print("Got item:", item)
	end)

	-- Observe properties
	ShopService.Coins:Observe(function(coins)
		print("Coins:", coins)
	end)
	```

	@param serviceName string -- The name of the service
	@return ServiceProxy -- Proxy to the service's Client table
]=]
function Client.GetService(serviceName: string): ServiceProxy
	assert(started, "Cannot get services before framework has started")

	local existingProxy = serviceProxies[serviceName]
	if existingProxy then
		return existingProxy
	end

	local newProxy = BuildServiceProxy(serviceName)
	serviceProxies[serviceName] = newProxy
	return newProxy
end

--[=[
	Registers a callback for when the local player's character spawns.

	The callback fires immediately if a character already exists.
	The trove auto-cleans when the character is removed.

	```lua
	e2en.OnCharacterAdded(function(character, trove)
		local humanoid = character:WaitForChild("Humanoid")
		trove:Connect(humanoid.Died, function()
			print("Died")
		end)
	end)
	```

	@param callback (character: Model, trove: Trove) -> () -- The callback function
]=]
function Client.OnCharacterAdded(callback: (character: Model, trove: Trove) -> ())
	table.insert(characterAddedCallbacks, callback)

	local character = Client.Player.Character
	if character and characterTrove then
		task.spawn(callback, character, characterTrove)
	end
end

--[=[
	Registers a callback for when the local player's character is removed.

	```lua
	e2en.OnCharacterRemoving(function(character)
		print("Character removing")
	end)
	```

	@param callback (character: Model) -> () -- The callback function
]=]
function Client.OnCharacterRemoving(callback: (character: Model) -> ())
	table.insert(characterRemovingCallbacks, callback)
end

--[=[
	Gets the trove associated with the current character.

	Returns nil if no character exists.

	@return Trove? -- The character's trove, or nil
]=]
function Client.GetCharacterTrove(): Trove?
	return characterTrove
end

--[=[
	Gets the local player's current character.

	Returns nil if no character exists.

	@return Model? -- The character, or nil
]=]
function Client.GetCharacter(): Model?
	return Client.Player.Character
end

local function HandleCharacterAdded(character: Model)
	characterTrove = Trove.new()

	for _, callback in characterAddedCallbacks do
		task.spawn(callback, character, characterTrove :: Trove)
	end
end

local function HandleCharacterRemoving(character: Model)
	for _, callback in characterRemovingCallbacks do
		task.spawn(callback, character)
	end

	if characterTrove then
		characterTrove:Clean()
		characterTrove = nil
	end
end

local function SetupCharacterLifecycle()
	Client.Player.CharacterAdded:Connect(HandleCharacterAdded)
	Client.Player.CharacterRemoving:Connect(HandleCharacterRemoving)

	if Client.Player.Character then
		HandleCharacterAdded(Client.Player.Character)
	end
end

local function TopologicalSort(): { Controller }
	local sorted: { Controller } = {}
	local visited: { [string]: boolean } = {}
	local visiting: { [string]: boolean } = {}

	local function visit(controllerName: string)
		if visited[controllerName] then
			return
		end
		if visiting[controllerName] then
			error(`Circular dependency detected involving '{controllerName}'`)
		end

		local controller = controllers[controllerName]
		if not controller then
			error(`Dependency '{controllerName}' not found`)
		end

		visiting[controllerName] = true

		if controller.Dependencies then
			for _, depName in controller.Dependencies do
				visit(depName)
			end
		end

		visiting[controllerName] = nil
		visited[controllerName] = true
		table.insert(sorted, controller)
	end

	for name in controllers do
		visit(name)
	end

	return sorted
end

local function CollectPreloadableAssets(folder: Instance): { Instance }
	local assets: { Instance } = {}

	for _, descendant in folder:GetDescendants() do
		if descendant:IsA("Animation")
			or descendant:IsA("Sound")
			or descendant:IsA("Decal")
			or descendant:IsA("Texture")
			or descendant:IsA("ParticleEmitter")
			or descendant:IsA("Beam")
			or descendant:IsA("Trail")
		then
			table.insert(assets, descendant)
		end
	end

	return assets
end

local function PreloadCommonAssets()
	local root = script.Parent.Parent
	local common = root:FindFirstChild("Shared")
	if not common then
		return
	end
	common = common:FindFirstChild("common")
	if not common then
		return
	end

	local assets = CollectPreloadableAssets(common)
	if #assets > 0 then
		ContentProvider:PreloadAsync(assets)
	end
end

--[=[
	Starts the client framework.

	This is called automatically by the ClientLoader script.
	Most users don't need to call this directly.
]=]
function Client.Start(): ()
	assert(not started, "Framework has already started")
	assert(RunService:IsClient(), "Client.Start can only be called on the client")

	started = true

	PreloadCommonAssets()

	GetServicesFolder()

	local sortedControllers = TopologicalSort()

	for _, controller in sortedControllers do
		if controller.Init then
			controller:Init()
		end
	end

	SetupCharacterLifecycle()

	for _, controller in sortedControllers do
		if controller.Start then
			task.spawn(controller.Start, controller)
		end
	end

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
function Client.OnStart(): ()
	if startedComplete then
		return
	end
	onStartedComplete.Event:Wait()
end

--[=[
	Checks if the framework has finished starting.

	@return boolean -- True if the framework has started
]=]
function Client.IsStarted(): boolean
	return startedComplete
end

return Client
