--!strict
--[[
	Dependencies - Internal library references for e2en
]]

local Types = require(script.Parent.Types)
local Libraries = script.Parent.Libraries

-- Type definitions for library constructors
type Connection = Types.Connection

type Signal<T...> = Types.Signal<T...>

type SignalConstructor = {
	new: <T...>() -> Signal<T...>,
	Wrap: <T...>(rbxScriptSignal: RBXScriptSignal) -> Signal<T...>,
	Is: (obj: any) -> boolean,
}

type Trove = Types.Trove

type TroveConstructor = {
	new: () -> Trove,
}

local Dependencies = {}

function Dependencies.GetSignal(): SignalConstructor
	return require(Libraries.Signal) :: any
end

function Dependencies.GetTrove(): TroveConstructor
	return require(Libraries.Trove) :: any
end

return Dependencies
