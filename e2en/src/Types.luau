--!strict
--[[
	Types - Type definitions for the Framework
	These are pure type definitions for intellisense support.
]]

export type Connection = {
	Disconnect: (self: Connection) -> (),
	Connected: boolean,
}

export type Signal<T...> = {
	Fire: (self: Signal<T...>, T...) -> (),
	Connect: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Wait: (self: Signal<T...>) -> T...,
	Destroy: (self: Signal<T...>) -> (),
}

export type Trove = {
	Add: <T>(self: Trove, object: T, cleanupMethod: string?) -> T,
	Connect: (self: Trove, signal: RBXScriptSignal, callback: (...any) -> ()) -> RBXScriptConnection,
	Clean: (self: Trove) -> (),
	Destroy: (self: Trove) -> (),
	AttachToInstance: (self: Trove, instance: Instance) -> RBXScriptConnection,
}

export type ServiceDefinition = {
	Name: string,
	Client: { [string]: any }?,
	Dependencies: { string }?,
	[string]: any,
}

export type Service = {
	Name: string,
	Client: ServiceClient,
	Dependencies: { string }?,
	Init: ((self: Service) -> ())?,
	Start: ((self: Service) -> ())?,
	[string]: any,
}

export type ServiceClient = {
	Server: Service,
	[string]: any,
}

export type ControllerDefinition = {
	Name: string,
	Dependencies: { string }?,
	[string]: any,
}

export type Controller = {
	Name: string,
	Dependencies: { string }?,
	Init: ((self: Controller) -> ())?,
	Start: ((self: Controller) -> ())?,
	[string]: any,
}

export type RemoteSignal<T...> = {
	Fire: (self: RemoteSignal<T...>, player: Player, T...) -> (),
	FireAll: (self: RemoteSignal<T...>, T...) -> (),
	FireFor: (self: RemoteSignal<T...>, players: { Player }, T...) -> (),
	FireExcept: (self: RemoteSignal<T...>, player: Player, T...) -> (),
	FireFilter: (self: RemoteSignal<T...>, predicate: (Player, T...) -> boolean, T...) -> (),
	Connect: (self: RemoteSignal<T...>, callback: (player: Player, T...) -> ()) -> Connection,
	Destroy: (self: RemoteSignal<T...>) -> (),
}

export type ClientRemoteSignal<T...> = {
	Fire: (self: ClientRemoteSignal<T...>, T...) -> (),
	Connect: (self: ClientRemoteSignal<T...>, callback: (T...) -> ()) -> Connection,
	Destroy: (self: ClientRemoteSignal<T...>) -> (),
}

export type RemoteProperty<T> = {
	Get: (self: RemoteProperty<T>) -> T,
	Set: (self: RemoteProperty<T>, value: T) -> (),
	SetTop: (self: RemoteProperty<T>, value: T) -> (),
	SetFor: (self: RemoteProperty<T>, player: Player, value: T) -> (),
	SetForList: (self: RemoteProperty<T>, players: { Player }, value: T) -> (),
	SetFilter: (self: RemoteProperty<T>, predicate: (Player) -> boolean, value: T) -> (),
	ClearFor: (self: RemoteProperty<T>, player: Player) -> (),
	ClearForList: (self: RemoteProperty<T>, players: { Player }) -> (),
	GetFor: (self: RemoteProperty<T>, player: Player) -> T,
	Observe: (self: RemoteProperty<T>, callback: (value: T) -> ()) -> Connection,
	Destroy: (self: RemoteProperty<T>) -> (),
}

export type ClientRemoteProperty<T> = {
	Get: (self: ClientRemoteProperty<T>) -> T,
	IsReady: (self: ClientRemoteProperty<T>) -> boolean,
	OnReady: (self: ClientRemoteProperty<T>, timeout: number?) -> T?,
	Observe: (self: ClientRemoteProperty<T>, callback: (value: T) -> ()) -> Connection,
	Destroy: (self: ClientRemoteProperty<T>) -> (),
}

export type SignalMarker = {
	_marker: "Signal",
}

export type UnreliableSignalMarker = {
	_marker: "UnreliableSignal",
}

export type PropertyMarker<T> = {
	_marker: "Property",
	_initialValue: T,
}

export type PlayerCallbackServer = (player: Player, playerTrove: Trove) -> ()
export type CharacterCallbackServer = (player: Player, character: Model, characterTrove: Trove) -> ()
export type CharacterCallbackClient = (character: Model, characterTrove: Trove) -> ()

-- PerformanceEntry with name (for reports/sorting)
export type PerformanceEntry = {
	name: string,
	calls: number,
	totalTime: number,
	avgTime: number,
	peakTime: number,
	lastCall: number,
	source: string?,
}

-- PerformanceDataEntry without name (for dictionary values where name is the key)
export type PerformanceDataEntry = {
	calls: number,
	totalTime: number,
	avgTime: number,
	peakTime: number,
	lastCall: number,
	source: string?,
}

-- Util module type
export type Util = {
	ForEach: <K, V>(tbl: { [K]: V }, callback: (value: V, key: K) -> (), trackingName: string?) -> (),
	ForEachAsync: <K, V>(tbl: { [K]: V }, callback: (value: V, key: K) -> (), trackingName: string?) -> (),
	Map: <K, V, R>(tbl: { [K]: V }, callback: (value: V, key: K) -> R, trackingName: string?) -> { [K]: R },
	Filter: <K, V>(tbl: { [K]: V }, predicate: (value: V, key: K) -> boolean, trackingName: string?) -> { V },
	Find: <K, V>(tbl: { [K]: V }, predicate: (value: V, key: K) -> boolean, trackingName: string?) -> V?,
	Reduce: <K, V, R>(tbl: { [K]: V }, reducer: (accumulator: R, value: V, key: K) -> R, initial: R, trackingName: string?) -> R,
	Every: <K, V>(tbl: { [K]: V }, predicate: (value: V, key: K) -> boolean, trackingName: string?) -> boolean,
	Some: <K, V>(tbl: { [K]: V }, predicate: (value: V, key: K) -> boolean, trackingName: string?) -> boolean,
	Reverse: <V>(tbl: { V }) -> { V },
	Shuffle: <V>(tbl: { V }) -> { V },
	Copy: <K, V>(tbl: { [K]: V }, deep: boolean?) -> { [K]: V },
	Keys: <K, V>(tbl: { [K]: V }) -> { K },
	Values: <K, V>(tbl: { [K]: V }) -> { V },
	Count: <K, V>(tbl: { [K]: V }) -> number,
	Flat: <V>(tbl: { any }, depth: number?) -> { V },
	Step: (name: string, callback: (dt: number) -> (), renderStepped: boolean?) -> RBXScriptConnection,
	StopStep: (name: string) -> (),
	GetActiveSteps: () -> { string },
	Defer: <T...>(callback: (T...) -> (), T...) -> (),
	Delay: <T...>(duration: number, callback: (T...) -> (), T...) -> (),
	WaitFor: <T>(predicate: () -> T?, timeout: number?, interval: number?) -> T?,
	EnablePerformanceTracking: (enabled: boolean) -> (),
	GetPerformanceData: () -> { [string]: PerformanceDataEntry },
	ClearPerformanceData: () -> (),
	PrintPerformanceReport: () -> (),
	EstimateMemoryUsage: (...any) -> number,
}

-- Middleware types
export type InboundMiddleware = (player: Player, serviceName: string, methodName: string, args: { any }) -> (boolean, { any })
export type OutboundMiddleware = (player: Player?, serviceName: string, signalName: string, args: { any }) -> (boolean, { any })

export type MiddlewareConfig = {
	Inbound: { InboundMiddleware }?,
	Outbound: { OutboundMiddleware }?,
}

export type RunConfig = {
	Middleware: MiddlewareConfig?,
}

-- Shared e2en API (available on both server and client)
export type e2enShared = {
	Util: Util,
	Comm: any,
	Systems: Instance,

	-- Util shortcuts
	ForEach: <K, V>(tbl: { [K]: V }, callback: (value: V, key: K) -> (), trackingName: string?) -> (),
	ForEachAsync: <K, V>(tbl: { [K]: V }, callback: (value: V, key: K) -> (), trackingName: string?) -> (),
	Map: <K, V, R>(tbl: { [K]: V }, callback: (value: V, key: K) -> R, trackingName: string?) -> { [K]: R },
	Filter: <K, V>(tbl: { [K]: V }, predicate: (value: V, key: K) -> boolean, trackingName: string?) -> { V },
	Find: <K, V>(tbl: { [K]: V }, predicate: (value: V, key: K) -> boolean, trackingName: string?) -> V?,
	Reduce: <K, V, R>(tbl: { [K]: V }, reducer: (accumulator: R, value: V, key: K) -> R, initial: R, trackingName: string?) -> R,
	Every: <K, V>(tbl: { [K]: V }, predicate: (value: V, key: K) -> boolean, trackingName: string?) -> boolean,
	Some: <K, V>(tbl: { [K]: V }, predicate: (value: V, key: K) -> boolean, trackingName: string?) -> boolean,
	Reverse: <V>(tbl: { V }) -> { V },
	Shuffle: <V>(tbl: { V }) -> { V },
	Copy: <K, V>(tbl: { [K]: V }, deep: boolean?) -> { [K]: V },
	Keys: <K, V>(tbl: { [K]: V }) -> { K },
	Values: <K, V>(tbl: { [K]: V }) -> { V },
	Count: <K, V>(tbl: { [K]: V }) -> number,
	Flat: <V>(tbl: { any }, depth: number?) -> { V },
	Step: (name: string, callback: (dt: number) -> (), renderStepped: boolean?) -> RBXScriptConnection,
	StopStep: (name: string) -> (),
	GetActiveSteps: () -> { string },
	Defer: <T...>(callback: (T...) -> (), T...) -> (),
	Delay: <T...>(duration: number, callback: (T...) -> (), T...) -> (),
	WaitFor: <T>(predicate: () -> T?, timeout: number?, interval: number?) -> T?,
	EnablePerformanceTracking: (enabled: boolean) -> (),
	GetPerformanceData: () -> { [string]: PerformanceDataEntry },
	ClearPerformanceData: () -> (),
	PrintPerformanceReport: () -> (),
	EstimateMemoryUsage: (...any) -> number,
}

-- Server-specific e2en API
export type e2enServer = e2enShared & {
	Run: (config: RunConfig?) -> (),

	CreateService: <T>(definition: ServiceDefinition & T) -> Service & T,
	GetService: (serviceName: string) -> Service,
	GetServices: () -> { [string]: Service },
	AddServices: (parent: Instance) -> { Service },
	AddServicesDeep: (parent: Instance) -> { Service },
	AddSystems: (parent: Instance) -> { Service },
	AddSystemsDeep: (parent: Instance) -> { Service },

	CreateSignal: () -> SignalMarker,
	CreateUnreliableSignal: () -> UnreliableSignalMarker,
	CreateProperty: <T>(initialValue: T) -> PropertyMarker<T>,

	OnPlayerAdded: (callback: PlayerCallbackServer) -> (),
	OnPlayerRemoving: (callback: (player: Player) -> ()) -> (),
	OnCharacterAdded: (callback: CharacterCallbackServer) -> (),
	OnCharacterRemoving: (callback: (player: Player, character: Model) -> ()) -> (),
	GetPlayerTrove: (player: Player) -> Trove?,
	GetCharacterTrove: (player: Player) -> Trove?,

	Start: () -> (),
	OnStart: () -> (),
	IsStarted: () -> boolean,
}

-- Client-specific e2en API
export type e2enClient = e2enShared & {
	CreateController: <T>(definition: ControllerDefinition & T) -> Controller & T,
	GetController: (controllerName: string) -> Controller,
	GetControllers: () -> { [string]: Controller },
	AddControllers: (parent: Instance) -> { Controller },
	AddControllersDeep: (parent: Instance) -> { Controller },
	AddSystems: (parent: Instance) -> { Controller },
	AddSystemsDeep: (parent: Instance) -> { Controller },

	GetService: (serviceName: string) -> { [string]: any },

	OnCharacterAdded: (callback: CharacterCallbackClient) -> (),
	OnCharacterRemoving: (callback: (character: Model) -> ()) -> (),
	GetCharacterTrove: () -> Trove?,
	GetCharacter: () -> Model?,
	Player: Player,

	Start: () -> (),
	OnStart: () -> (),
	IsStarted: () -> boolean,
}

return nil
