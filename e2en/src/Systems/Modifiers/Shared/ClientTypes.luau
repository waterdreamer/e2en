local root = script.Parent.Parent.Parent.Parent
local Types = require(root.Types)
local SharedTypes = require(script.Parent.Types)

type StatSyncData = SharedTypes.StatSyncData

export type ModifiersServiceProxy = {
	StatSynced: Types.ClientRemoteSignal<string, StatSyncData>,
	GetAllStats: (self: ModifiersServiceProxy) -> { [string]: StatSyncData },
}

return nil
