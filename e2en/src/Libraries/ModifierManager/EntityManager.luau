local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local BaseModifierManager = require(script.Parent)
local Types = require(script.Parent.Types)

export type ModifierType = Types.ModifierType
export type StackingRule = Types.StackingRule
export type Modifier = Types.Modifier
export type StatStack = Types.StatStack
export type ModifierConfig = Types.ModifierConfig
export type StackMap = Types.StackMap
export type StackKey = Types.StackKey

type EntityModifierConfig = ModifierConfig & {
	entity: string,
}

type EntityModifierManagerImpl = Types.EntityModifierManagerData

local EntityModifierManager = setmetatable({}, BaseModifierManager)
EntityModifierManager.__index = EntityModifierManager

function EntityModifierManager.new(): EntityModifierManagerImpl
	local base = BaseModifierManager.new()
	local self: EntityModifierManagerImpl = setmetatable(base, EntityModifierManager) :: any

	if not RunService:IsServer() then
		error("EntityModifierManager can only be used on the server")
	end

	return self
end

function EntityModifierManager.Destroy(self: EntityModifierManagerImpl)
	BaseModifierManager.Destroy(self)
end

function EntityModifierManager.CleanupEntity(self: EntityModifierManagerImpl, entity: string)
	if self.stacks[entity] then
		self.stacks[entity] = nil
	end

	if self.signals[entity] then
		for _, signal in self.signals[entity] do
			signal:Destroy()
		end
		self.signals[entity] = nil
	end

	if self.tagIndex[entity] then
		self.tagIndex[entity] = nil
	end
end

function EntityModifierManager.CleanupExpiredModifiers(self: EntityModifierManagerImpl)
	BaseModifierManager.CleanupExpiredModifiers(self)
end

function EntityModifierManager.HasStack(self: EntityModifierManagerImpl, entity: string, statPath: string): boolean
	if type(entity) ~= "string" or entity == "" then
		error("Entity must be a non-empty string")
	end

	return self.stacks[entity] ~= nil and self.stacks[entity][statPath] ~= nil
end

function EntityModifierManager.GetStack(self: EntityModifierManagerImpl, entity: string, statPath: string): StatStack
	if type(entity) ~= "string" or entity == "" then
		error("Entity must be a non-empty string")
	end

	if not self.stacks[entity] then
		self.stacks[entity] = {}
		self.signals[entity] = {}
		self.tagIndex[entity] = {}
	end

	if not self.stacks[entity][statPath] then
		self.stacks[entity][statPath] = {
			baseValue = 0,
			modifiers = {},
			isDirty = true,
			cachedValue = nil,
		}
	end

	return self.stacks[entity][statPath]
end

function EntityModifierManager.SetBase(self: EntityModifierManagerImpl, entity: string, statPath: string, baseValue: number)
	BaseModifierManager.SetBase(self, entity, statPath, baseValue)
end

function EntityModifierManager.SetClamps(self: EntityModifierManagerImpl, entity: string, statPath: string, minValue: number?, maxValue: number?)
	if not EntityModifierManager.HasStack(self, entity, statPath) then
		error("Stack does not exist. Call SetBase first")
	end

	BaseModifierManager.SetClamps(self, entity, statPath, minValue, maxValue)
end

function EntityModifierManager.SetDecimalPlaces(self: EntityModifierManagerImpl, entity: string, statPath: string, decimalPlaces: number?)
	if not EntityModifierManager.HasStack(self, entity, statPath) then
		error("Stack does not exist. Call SetBase first")
	end

	BaseModifierManager.SetDecimalPlaces(self, entity, statPath, decimalPlaces)
end

function EntityModifierManager.AddModifier(self: EntityModifierManagerImpl, config: EntityModifierConfig): string
	if not config.entity or type(config.entity) ~= "string" or config.entity == "" then
		error("Entity must be a non-empty string")
	end

	BaseModifierManager.ValidateStatPath(self, config.path)

	if type(config.value) ~= "number" or config.value ~= config.value then
		error("Modifier value must be a valid number")
	end

	if not config.type or not BaseModifierManager.VALID_MODIFIER_TYPES[config.type] then
		error("Invalid modifier type. Must be 'Additive', 'Multiplicative', or 'Override'")
	end

	if config.stackingRule and not BaseModifierManager.VALID_STACKING_RULES[config.stackingRule] then
		error("Invalid stacking rule. Must be 'Stack', 'Replace', 'Highest', or 'Refresh'")
	end

	if not config.source or type(config.source) ~= "string" or config.source == "" then
		error("Source must be a non-empty string")
	end

	local stack = EntityModifierManager.GetStack(self, config.entity, config.path)

	if config.stackingRule then
		local handled = BaseModifierManager.HandleStackingRule(
			self,
			stack,
			config.stackingRule,
			config.source,
			config,
			config.entity
		)
		if handled then
			return handled
		end
	end

	local modifierId = HttpService:GenerateGUID(false)

	local modifier: Modifier = {
		id = modifierId,
		value = config.value,
		modifierType = config.type,
		source = config.source,
		priority = config.priority or 100,
		tags = config.tags or {},
		stackingRule = config.stackingRule,
		minValue = config.minValue,
		maxValue = config.maxValue,
	}

	if config.duration and config.duration > 0 then
		local expireTime = os.clock() + config.duration
		modifier.expireTime = expireTime
		BaseModifierManager.AddToExpirationQueue(self, config.entity, config.path, modifierId, expireTime)
	end

	local insertIndex = BaseModifierManager.FindInsertIndexBinarySearch(self, stack.modifiers, modifier.priority)
	table.insert(stack.modifiers, insertIndex, modifier)

	BaseModifierManager.AddModifierToTagIndex(self, config.entity, config.path, modifier)

	stack.isDirty = true
	EntityModifierManager.TriggerChange(self, config.path, config.entity)

	return modifierId
end

function EntityModifierManager.AddModifiers(self: EntityModifierManagerImpl, configs: { EntityModifierConfig }): { string }
	local modifierIds: { string } = {}

	for _, config in configs do
		local id = EntityModifierManager.AddModifier(self, config)
		table.insert(modifierIds, id)
	end

	return modifierIds
end

function EntityModifierManager.RemoveModifierById(self: EntityModifierManagerImpl, entity: string, statPath: string, modifierId: string): boolean
	return BaseModifierManager.RemoveModifierById(self, entity, statPath, modifierId)
end

function EntityModifierManager.RemoveBySource(self: EntityModifierManagerImpl, entity: string, statPath: string, source: string): number
	return BaseModifierManager.RemoveBySource(self, entity, statPath, source)
end

function EntityModifierManager.RemoveByTag(self: EntityModifierManagerImpl, entity: string, statPath: string, tag: string): number
	return BaseModifierManager.RemoveByTag(self, entity, statPath, tag)
end

function EntityModifierManager.RemoveAllBySource(self: EntityModifierManagerImpl, entity: string, source: string): number
	return BaseModifierManager.RemoveAllBySource(self, entity, source)
end

function EntityModifierManager.RemoveAllByTag(self: EntityModifierManagerImpl, entity: string, tag: string): number
	return BaseModifierManager.RemoveAllByTag(self, entity, tag)
end

function EntityModifierManager.Get(self: EntityModifierManagerImpl, entity: string, statPath: string): number
	return BaseModifierManager.Get(self, entity, statPath)
end

function EntityModifierManager.GetModifiers(self: EntityModifierManagerImpl, entity: string, statPath: string): { Modifier }
	return BaseModifierManager.GetModifiers(self, entity, statPath)
end

function EntityModifierManager.GetModifiersBySource(self: EntityModifierManagerImpl, entity: string, statPath: string, source: string): { Modifier }
	return BaseModifierManager.GetModifiersBySource(self, entity, statPath, source)
end

function EntityModifierManager.GetModifiersByTag(self: EntityModifierManagerImpl, entity: string, statPath: string, tag: string): { Modifier }
	return BaseModifierManager.GetModifiersByTag(self, entity, statPath, tag)
end

function EntityModifierManager.OnChanged(self: EntityModifierManagerImpl, entity: string, statPath: string, callback: (newValue: number) -> ()): any
	if type(entity) ~= "string" or entity == "" then
		error("Entity must be a non-empty string")
	end

	return BaseModifierManager.OnChanged(self, entity, statPath, callback)
end

function EntityModifierManager.TriggerChange(self: EntityModifierManagerImpl, statPath: string, entity: string)
	BaseModifierManager.TriggerChange(self, statPath, entity)
end

function EntityModifierManager.GetDebugInfo(self: EntityModifierManagerImpl, entity: string): { [string]: any }
	return BaseModifierManager.GetDebugInfo(self, entity)
end

function EntityModifierManager.GetAllEntities(self: EntityModifierManagerImpl): { string }
	local entities: { string } = {}

	for entity, _ in self.stacks do
		table.insert(entities, entity :: string)
	end

	return entities
end

function EntityModifierManager.GetEntityStats(self: EntityModifierManagerImpl, entity: string): { string }
	if not self.stacks[entity] then
		return {}
	end

	local stats: { string } = {}

	for statPath, _ in self.stacks[entity] do
		table.insert(stats, statPath)
	end

	return stats
end

return EntityModifierManager
