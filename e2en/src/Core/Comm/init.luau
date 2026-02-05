--!strict

local RemoteSignal = require(script.RemoteSignal)
local ClientRemoteSignal = require(script.ClientRemoteSignal)
local RemoteProperty = require(script.RemoteProperty)
local ClientRemoteProperty = require(script.ClientRemoteProperty)

export type RemoteSignal<T...> = RemoteSignal.RemoteSignal<T...>
export type ClientRemoteSignal<T...> = ClientRemoteSignal.ClientRemoteSignal<T...>
export type RemoteProperty<T> = RemoteProperty.RemoteProperty<T>
export type ClientRemoteProperty<T> = ClientRemoteProperty.ClientRemoteProperty<T>

local Comm = {}

Comm.RemoteSignal = RemoteSignal
Comm.ClientRemoteSignal = ClientRemoteSignal
Comm.RemoteProperty = RemoteProperty
Comm.ClientRemoteProperty = ClientRemoteProperty

function Comm.CreateSignalMarker(): { _marker: "Signal" }
	return { _marker = "Signal" }
end

function Comm.CreateUnreliableSignalMarker(): { _marker: "UnreliableSignal" }
	return { _marker = "UnreliableSignal" }
end

function Comm.CreatePropertyMarker<T>(initialValue: T): { _marker: "Property", _initialValue: T }
	return { _marker = "Property", _initialValue = initialValue }
end

function Comm.IsSignalMarker(value: any): boolean
	return type(value) == "table" and value._marker == "Signal"
end

function Comm.IsUnreliableSignalMarker(value: any): boolean
	return type(value) == "table" and value._marker == "UnreliableSignal"
end

function Comm.IsPropertyMarker(value: any): boolean
	return type(value) == "table" and value._marker == "Property"
end

return Comm
