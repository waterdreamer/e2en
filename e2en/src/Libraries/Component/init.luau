--!strict

--[=[
	@class Component

	Binds Luau classes to Roblox instances via CollectionService tags.

	When an instance gains a tag, a component instance is created.
	When the tag is removed or instance destroyed, the component cleans up.

	```lua
	local Lava = Component.new({
		Tag = "Lava",
		Ancestors = { workspace },
	})

	Lava._prototype.Damage = 10

	function Lava._prototype:Construct()
		print("Lava on", self.Instance.Name)
	end

	function Lava._prototype:Start()
		self._trove:Connect(self.Instance.Touched, function(hit)
			-- Handle touch
		end)
	end

	Lava:Start()
	```
]=]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Dependencies = require(script.Parent.Parent.Dependencies)
local Trove = Dependencies.GetTrove()
local Signal = Dependencies.GetSignal()

type Trove = {
	Add: <T>(self: Trove, object: T, cleanupMethod: string?) -> T,
	Connect: (self: Trove, signal: RBXScriptSignal, callback: (...any) -> ()) -> RBXScriptConnection,
	Clean: (self: Trove) -> (),
	Destroy: (self: Trove) -> (),
	AttachToInstance: (self: Trove, instance: Instance) -> RBXScriptConnection,
}

type Signal<T...> = {
	Fire: (self: Signal<T...>, T...) -> (),
	Connect: (self: Signal<T...>, callback: (T...) -> ()) -> any,
	Destroy: (self: Signal<T...>) -> (),
}

export type ComponentConfig = {
	Tag: string,
	Ancestors: { Instance }?,
}

export type ComponentInstance<T> = T & {
	Instance: Instance,
	_trove: Trove,
}

type ComponentClassInternal<T> = {
	Tag: string,
	_ancestors: { Instance }?,
	_instances: { [Instance]: ComponentInstance<T> },
	_trove: Trove,
	_started: boolean,
	_destroyed: boolean,
	_heartbeatConnection: RBXScriptConnection?,
	_renderSteppedConnection: RBXScriptConnection?,
	_prototype: T,
	_hasHeartbeatUpdate: boolean,
	_hasRenderSteppedUpdate: boolean,
	ComponentAdded: Signal<ComponentInstance<T>>,
	ComponentRemoving: Signal<ComponentInstance<T>>,
}

local Component = {}
Component.__index = Component

local function IsDescendantOfAny(instance: Instance, ancestors: { Instance }): boolean
	for _, ancestor in ancestors do
		if instance:IsDescendantOf(ancestor) then
			return true
		end
	end
	return false
end

--[=[
	Creates a new component class.

	@param config ComponentConfig -- Configuration with Tag and optional Ancestors
	@return Component -- The component class
]=]
function Component.new<T>(config: ComponentConfig): T & {
	Tag: string,
	GetAll: (self: any) -> { ComponentInstance<T> },
	FromInstance: (self: any, instance: Instance) -> ComponentInstance<T>?,
	WaitForInstance: (self: any, instance: Instance, timeout: number?) -> ComponentInstance<T>?,
	Destroy: (self: any) -> (),
	ComponentAdded: Signal<ComponentInstance<T>>,
	ComponentRemoving: Signal<ComponentInstance<T>>,
}
	local self = setmetatable({
		Tag = config.Tag,
		_ancestors = config.Ancestors,
		_instances = {} :: { [Instance]: ComponentInstance<T> },
		_trove = Trove.new(),
		_started = false,
		_destroyed = false,
		_heartbeatConnection = nil,
		_renderSteppedConnection = nil,
		_prototype = {} :: T,
		_hasHeartbeatUpdate = false,
		_hasRenderSteppedUpdate = false,
		ComponentAdded = Signal.new(),
		ComponentRemoving = Signal.new(),
	}, Component)

	return self :: any
end

function Component._shouldTrack<T>(self: ComponentClassInternal<T>, instance: Instance): boolean
	if self._ancestors then
		return IsDescendantOfAny(instance, self._ancestors)
	end
	return true
end

function Component._createInstance<T>(self: ComponentClassInternal<T>, instance: Instance): ComponentInstance<T>
	local componentTrove = Trove.new()
	componentTrove:AttachToInstance(instance)

	local componentInstance = setmetatable({
		Instance = instance,
		_trove = componentTrove,
	}, { __index = self._prototype })

	for key, value in self._prototype :: any do
		if type(value) ~= "function" then
			(componentInstance :: any)[key] = value
		end
	end

	return componentInstance :: any
end

function Component._instanceAdded<T>(self: ComponentClassInternal<T>, instance: Instance)
	if self._destroyed then
		return
	end

	if self._instances[instance] then
		return
	end

	if not self:_shouldTrack(instance) then
		return
	end

	local componentInstance = self:_createInstance(instance)
	self._instances[instance] = componentInstance

	if (componentInstance :: any).Construct then
		(componentInstance :: any):Construct()
	end

	if self._started then
		if (componentInstance :: any).Start then
			task.spawn((componentInstance :: any).Start, componentInstance)
		end
	end

	self.ComponentAdded:Fire(componentInstance)
end

function Component._instanceRemoved<T>(self: ComponentClassInternal<T>, instance: Instance)
	local componentInstance = self._instances[instance]
	if not componentInstance then
		return
	end

	self.ComponentRemoving:Fire(componentInstance)

	if (componentInstance :: any).Stop then
		(componentInstance :: any):Stop()
	end

	componentInstance._trove:Destroy()
	self._instances[instance] = nil
end

function Component._setupUpdateLoops<T>(self: ComponentClassInternal<T>)
	if self._hasHeartbeatUpdate then
		self._heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
			for _, componentInstance in self._instances do
				if (componentInstance :: any).HeartbeatUpdate then
					(componentInstance :: any):HeartbeatUpdate(dt)
				end
			end
		end)
	end

	if self._hasRenderSteppedUpdate and RunService:IsClient() then
		self._renderSteppedConnection = RunService.RenderStepped:Connect(function(dt)
			for _, componentInstance in self._instances do
				if (componentInstance :: any).RenderSteppedUpdate then
					(componentInstance :: any):RenderSteppedUpdate(dt)
				end
			end
		end)
	end
end

--[=[
	Starts tracking tagged instances.

	Call this after defining the prototype to begin creating
	component instances for tagged objects.
]=]
function Component.Start<T>(self: ComponentClassInternal<T>)
	if self._started or self._destroyed then
		return
	end

	self._started = true

	self._hasHeartbeatUpdate = type((self._prototype :: any).HeartbeatUpdate) == "function"
	self._hasRenderSteppedUpdate = type((self._prototype :: any).RenderSteppedUpdate) == "function"

	self._trove:Connect(CollectionService:GetInstanceAddedSignal(self.Tag), function(instance)
		self:_instanceAdded(instance)
	end)

	self._trove:Connect(CollectionService:GetInstanceRemovedSignal(self.Tag), function(instance)
		self:_instanceRemoved(instance)
	end)

	for _, instance in CollectionService:GetTagged(self.Tag) do
		self:_instanceAdded(instance)
	end

	for _, componentInstance in self._instances do
		if (componentInstance :: any).Start then
			task.spawn((componentInstance :: any).Start, componentInstance)
		end
	end

	self:_setupUpdateLoops()
end

--[=[
	Gets all active component instances.

	@return {ComponentInstance} -- Array of active instances
]=]
function Component.GetAll<T>(self: ComponentClassInternal<T>): { ComponentInstance<T> }
	local result: { ComponentInstance<T> } = {}
	for _, componentInstance in self._instances do
		table.insert(result, componentInstance)
	end
	return result
end

--[=[
	Gets the component instance for a tagged Instance.

	@param instance Instance -- The tagged instance
	@return ComponentInstance? -- The component, or nil if not found
]=]
function Component.FromInstance<T>(self: ComponentClassInternal<T>, instance: Instance): ComponentInstance<T>?
	return self._instances[instance]
end

--[=[
	Waits for a component instance on a tagged Instance.

	@param instance Instance -- The instance to wait for
	@param timeout number? -- Optional timeout (default 10 seconds)
	@return ComponentInstance? -- The component, or nil if timed out
]=]
function Component.WaitForInstance<T>(self: ComponentClassInternal<T>, instance: Instance, timeout: number?): ComponentInstance<T>?
	local existing = self._instances[instance]
	if existing then
		return existing
	end

	local timeoutDuration = timeout or 10
	local startTime = os.clock()

	while os.clock() - startTime < timeoutDuration do
		local current = self._instances[instance]
		if current then
			return current
		end
		task.wait(0.1)
	end

	return nil
end

--[=[
	Stops tracking and destroys all component instances.
]=]
function Component.Destroy<T>(self: ComponentClassInternal<T>)
	if self._destroyed then
		return
	end

	self._destroyed = true

	if self._heartbeatConnection then
		self._heartbeatConnection:Disconnect()
		self._heartbeatConnection = nil
	end

	if self._renderSteppedConnection then
		self._renderSteppedConnection:Disconnect()
		self._renderSteppedConnection = nil
	end

	for instance in self._instances do
		self:_instanceRemoved(instance)
	end

	self._trove:Destroy()
	self.ComponentAdded:Destroy()
	self.ComponentRemoving:Destroy()
end

return Component
