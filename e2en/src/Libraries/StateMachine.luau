local Signal = require(script.Parent.Signal)

export type StateMachine<S> = {
	GetState: (self: StateMachine<S>) -> S?,
	GetPreviousState: (self: StateMachine<S>) -> S?,
	HasState: (self: StateMachine<S>, state: S) -> boolean,
	IsDestroyed: (self: StateMachine<S>) -> boolean,
	SetState: (self: StateMachine<S>, state: S) -> boolean,
	ForceSetState: (self: StateMachine<S>, state: S) -> boolean,
	Update: (self: StateMachine<S>, dt: number) -> (),
	SetData: (self: StateMachine<S>, key: string, value: any) -> (),
	GetData: (self: StateMachine<S>, key: string) -> any,
	ClearData: (self: StateMachine<S>) -> (),
	OnStateChanged: Signal.Signal<S?, S>,
	Destroy: (self: StateMachine<S>) -> (),
}

export type StateContext<S> = {
	machine: StateMachine<S>,
	previousState: S?,
	data: { [string]: any },
	owner: any?,
}

export type StateBuilder<S> = (owner: any, ...any) -> StateDefinition<S>

export type StateDefinition<S> = {
	OnEnter: ((context: StateContext<S>) -> ())?,
	OnUpdate: ((context: StateContext<S>, dt: number) -> ())?,
	OnExit: ((context: StateContext<S>, to: S?) -> ())?,
	CanEnter: ((context: StateContext<S>, from: S?) -> boolean)?,
	CanExit: ((context: StateContext<S>, to: S) -> boolean)?,
}

type StateMachineImpl<S> = {
	_states: { [S]: StateDefinition<S> },
	_currentState: S?,
	_previousState: S?,
	_data: { [string]: any },
	_context: StateContext<S>,
	_destroyed: boolean,
	OnStateChanged: Signal.Signal<S?, S>,
}

local StateMachine = {}
StateMachine.__index = StateMachine

local function updateContext<S>(impl: StateMachineImpl<S>): ()
	impl._context.previousState = rawget(impl, "_previousState")
end

local function transitionState<S>(self: any, state: S, force: boolean): boolean
	local impl = self :: StateMachineImpl<S>
	if impl._destroyed then
		return false
	end

	local stateDefinition = impl._states[state]
	if not stateDefinition then
		return false
	end

	local currentState = rawget(impl, "_currentState")
	if currentState == state then
		return true
	end

	local currentDefinition: StateDefinition<S>? = nil
	if currentState then
		currentDefinition = impl._states[currentState]
	end

	local context = impl._context
	context.previousState = currentState

	if not force then
		if currentDefinition then
			local canExit = currentDefinition.CanExit
			if canExit then
				if not canExit(context, state) then
					return false
				end
			end
		end

		local canEnter = stateDefinition.CanEnter
		if canEnter then
			if not canEnter(context, currentState) then
				return false
			end
		end
	end

	if currentDefinition then
		local onExit = currentDefinition.OnExit
		if onExit then
			onExit(context, state)
		end
	end

	impl._previousState = currentState
	impl._currentState = state
	updateContext(impl)

	local onEnter = stateDefinition.OnEnter
	if onEnter then
		onEnter(context)
	end

	impl.OnStateChanged:Fire(currentState, state)

	return true
end

function StateMachine.new<S>(states: { [S]: StateDefinition<S> }, owner: any?): StateMachine<S>
	local self = setmetatable({}, StateMachine)

	local context: StateContext<S> = {
		machine = self :: any,
		previousState = nil,
		data = {},
		owner = owner,
	}

	self._states = states
	self._currentState = nil
	self._previousState = nil
	self._data = context.data
	self._context = context
	self._destroyed = false
	self.OnStateChanged = Signal.new()

	return self :: any
end

function StateMachine.fromFolder<S>(folder: Instance, owner: any?, ...: any): StateMachine<S>
	local states: { [S]: StateDefinition<S> } = {}

	for _, child in folder:GetChildren() do
		if not child:IsA("ModuleScript") then
			continue
		end

		local stateModule = require(child)
		local stateDefinition: StateDefinition<S>

		if type(stateModule) == "function" then
			stateDefinition = stateModule(owner, ...)
		else
			stateDefinition = stateModule
		end

		states[child.Name :: any] = stateDefinition
	end

	return StateMachine.new(states, owner)
end

function StateMachine.Is(object: any): boolean
	return type(object) == "table" and getmetatable(object) == StateMachine
end

function StateMachine:GetState()
	local impl = self :: StateMachineImpl<any>
	if impl._destroyed then
		return nil
	end
	return rawget(impl, "_currentState")
end

function StateMachine:GetPreviousState()
	local impl = self :: StateMachineImpl<any>
	if impl._destroyed then
		return nil
	end
	return rawget(impl, "_previousState")
end

function StateMachine:HasState(state): boolean
	local impl = self :: StateMachineImpl<any>
	if impl._destroyed then
		return false
	end
	return impl._states[state] ~= nil
end

function StateMachine:IsDestroyed(): boolean
	local impl = self :: StateMachineImpl<any>
	return impl._destroyed
end

function StateMachine:SetState(state): boolean
	return transitionState(self, state, false)
end

function StateMachine:ForceSetState(state): boolean
	return transitionState(self, state, true)
end

function StateMachine:Update(dt: number): ()
	local impl = self :: StateMachineImpl<any>
	if impl._destroyed then
		return
	end

	local currentState = rawget(impl, "_currentState")
	if not currentState then
		return
	end

	local stateDefinition = impl._states[currentState]
	if not stateDefinition then
		return
	end

	local onUpdate = stateDefinition.OnUpdate
	if not onUpdate then
		return
	end

	onUpdate(impl._context, dt)
end

function StateMachine:SetData(key: string, value: any): ()
	local impl = self :: StateMachineImpl<any>
	if impl._destroyed then
		return
	end
	impl._data[key] = value
end

function StateMachine:GetData(key: string): any
	local impl = self :: StateMachineImpl<any>
	if impl._destroyed then
		return nil
	end
	return impl._data[key]
end

function StateMachine:ClearData(): ()
	local impl = self :: StateMachineImpl<any>
	if impl._destroyed then
		return
	end
	table.clear(impl._data)
end

function StateMachine:Destroy(): ()
	local impl = self :: StateMachineImpl<any>
	if impl._destroyed then
		return
	end

	impl._destroyed = true

	local currentState = rawget(impl, "_currentState")
	if currentState then
		local stateDefinition = impl._states[currentState]
		if stateDefinition then
			local onExit = stateDefinition.OnExit
			if onExit then
				onExit(impl._context, nil)
			end
		end
	end

	impl.OnStateChanged:Destroy()
	impl._context.machine = nil :: any
	table.clear(impl._states)
	table.clear(impl._data)
	impl._currentState = nil
	impl._previousState = nil
end

setmetatable(StateMachine, {
	__index = function(_table, key)
		error(("Attempt to get StateMachine::%s (not a valid member)"):format(tostring(key)), 2)
	end,
	__newindex = function(_table, key, _value)
		error(("Attempt to set StateMachine::%s (not a valid member)"):format(tostring(key)), 2)
	end,
})

return table.freeze({
	new = StateMachine.new,
	fromFolder = StateMachine.fromFolder,
	Is = StateMachine.Is,
})
