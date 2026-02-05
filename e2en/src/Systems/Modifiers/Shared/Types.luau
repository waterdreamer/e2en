local root = script.Parent.Parent.Parent.Parent
local ModifierManager = root.Libraries.ModifierManager
local ManagerTypes = require(ModifierManager.Types)

export type ModifierType = ManagerTypes.ModifierType
export type StackingRule = ManagerTypes.StackingRule
export type Modifier = ManagerTypes.Modifier
export type StatStack = ManagerTypes.StatStack
export type ModifierConfig = ManagerTypes.ModifierConfig
export type StatSyncData = ManagerTypes.StatSyncData

export type StatDefinition = {
	base: number,
	clamps: { number }?,
	decimals: number?,
}

return nil
