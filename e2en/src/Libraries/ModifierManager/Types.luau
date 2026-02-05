--!strict
export type ModifierType = "Additive" | "Multiplicative" | "Override"
export type StackingRule = "Stack" | "Replace" | "Highest" | "Refresh"

export type Modifier = {
	id: string,
	value: number,
	modifierType: ModifierType,
	source: string,
	priority: number,
	tags: { string },
	stackingRule: StackingRule?,
	expireTime: number?,
	minValue: number?,
	maxValue: number?,
}

export type StatStack = {
	baseValue: number,
	modifiers: { Modifier },
	cachedValue: number?,
	isDirty: boolean,
	minClamp: number?,
	maxClamp: number?,
	decimalPlaces: number?,
}

export type StackKey = string | Player

export type ExpirationEntry = {
	expireTime: number,
	stackKey: StackKey,
	statPath: string,
	modifierId: string,
}

export type ModifierConfig = {
	path: string,
	value: number,
	type: ModifierType,
	source: string,
	priority: number?,
	tags: { string }?,
	duration: number?,
	stackingRule: StackingRule?,
	minValue: number?,
	maxValue: number?,
}

export type StatSyncData = {
	baseValue: number,
	modifiers: { Modifier },
	minClamp: number?,
	maxClamp: number?,
	decimalPlaces: number?,
}

export type StackMap = { [string]: StatStack }
export type SignalMap = { [string]: any }
export type TagMap = { [string]: { [string]: boolean } }

export type BaseModifierManagerData = {
	stacks: { [StackKey]: StackMap },
	signals: { [StackKey]: SignalMap },
	tagIndex: { [StackKey]: { [string]: TagMap } },
	expirationQueue: { ExpirationEntry },
	pendingRemovals: { [string]: boolean },
	trove: any,
	scheduledCleanupThread: thread?,
}

export type EntityModifierManagerData = BaseModifierManagerData

export type PlayerModifierManagerData = BaseModifierManagerData & {
	pendingSyncs: { [Player]: { [string]: boolean } },
	onSyncRequired: ((player: Player, statPath: string, syncData: StatSyncData) -> ())?,
}

return nil
