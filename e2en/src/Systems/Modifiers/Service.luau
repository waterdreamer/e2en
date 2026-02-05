local root = script.Parent.Parent.Parent
local Types = require(root.Types)
local SharedTypes = require(script.Parent.Shared.Types)

local ModifierManager = root.Libraries.ModifierManager
local EntityManager = require(ModifierManager.EntityManager)
local PlayerManager = require(ModifierManager.PlayerManager)

local e2en: Types.e2enServer = require(root) :: any

type ModifierConfig = SharedTypes.ModifierConfig
type StatSyncData = SharedTypes.StatSyncData
type Modifier = SharedTypes.Modifier
type StatDefinition = SharedTypes.StatDefinition

local ModifiersService = e2en.CreateService({
	Name = "ModifiersService",
	Client = {
		StatSynced = e2en.CreateSignal(),
	},
})

local entityManager: any
local playerManager: any

local statDefinitions: { [string]: StatDefinition } = {}

local OperatorMap = {
	["+"] = "Additive",
	["*"] = "Multiplicative",
	["="] = "Override",
}

function ModifiersService:DefineStats(definitions: { [string]: StatDefinition })
	for path, definition in definitions do
		statDefinitions[path] = definition
	end
end

function ModifiersService:SetPlayerBase(player: Player, statPath: string, baseValue: number)
	playerManager:SetBase(player, statPath, baseValue)
end

function ModifiersService:SetPlayerClamps(player: Player, statPath: string, minValue: number?, maxValue: number?)
	playerManager:SetClamps(player, statPath, minValue, maxValue)
end

function ModifiersService:SetPlayerDecimalPlaces(player: Player, statPath: string, decimalPlaces: number?)
	playerManager:SetDecimalPlaces(player, statPath, decimalPlaces)
end

function ModifiersService:AddPlayerModifier(player: Player, config: ModifierConfig): string
	return playerManager:AddModifier({
		player = player,
		path = config.path,
		value = config.value,
		type = config.type,
		source = config.source,
		priority = config.priority,
		tags = config.tags,
		duration = config.duration,
		stackingRule = config.stackingRule,
		minValue = config.minValue,
		maxValue = config.maxValue,
	})
end

function ModifiersService:AddPlayerModifiers(player: Player, configs: { ModifierConfig }): { string }
	local playerConfigs = {}
	for _, config in configs do
		table.insert(playerConfigs, {
			player = player,
			path = config.path,
			value = config.value,
			type = config.type,
			source = config.source,
			priority = config.priority,
			tags = config.tags,
			duration = config.duration,
			stackingRule = config.stackingRule,
			minValue = config.minValue,
			maxValue = config.maxValue,
		})
	end
	return playerManager:AddModifiers(playerConfigs)
end

function ModifiersService:RemovePlayerModifier(player: Player, statPath: string, modifierId: string): boolean
	return playerManager:RemoveModifierById(player, statPath, modifierId)
end

function ModifiersService:RemovePlayerModifiersBySource(player: Player, statPath: string, source: string): number
	return playerManager:RemoveBySource(player, statPath, source)
end

function ModifiersService:RemovePlayerModifiersByTag(player: Player, statPath: string, tag: string): number
	return playerManager:RemoveByTag(player, statPath, tag)
end

function ModifiersService:RemoveAllPlayerModifiersBySource(player: Player, source: string): number
	return playerManager:RemoveAllBySource(player, source)
end

function ModifiersService:RemoveAllPlayerModifiersByTag(player: Player, tag: string): number
	return playerManager:RemoveAllByTag(player, tag)
end

function ModifiersService:GetPlayerStat(player: Player, statPath: string): number
	return playerManager:Get(player, statPath)
end

function ModifiersService:GetPlayerModifiers(player: Player, statPath: string): { Modifier }
	return playerManager:GetModifiers(player, statPath)
end

function ModifiersService:GetPlayerModifiersBySource(player: Player, statPath: string, source: string): { Modifier }
	return playerManager:GetModifiersBySource(player, statPath, source)
end

function ModifiersService:GetPlayerModifiersByTag(player: Player, statPath: string, tag: string): { Modifier }
	return playerManager:GetModifiersByTag(player, statPath, tag)
end

function ModifiersService:GetPlayerStats(player: Player): { string }
	return playerManager:GetAllStats(player)
end

function ModifiersService:HasPlayerStat(player: Player, statPath: string): boolean
	return playerManager:HasStack(player, statPath)
end

function ModifiersService:OnPlayerStatChanged(player: Player, statPath: string, callback: (newValue: number) -> ()): any
	return playerManager:OnChanged(player, statPath, callback)
end

function ModifiersService:GetPlayerDebugInfo(player: Player): { [string]: any }
	return playerManager:GetDebugInfo(player)
end

function ModifiersService:SetEntityBase(entityId: string, statPath: string, baseValue: number)
	entityManager:SetBase(entityId, statPath, baseValue)
end

function ModifiersService:SetEntityClamps(entityId: string, statPath: string, minValue: number?, maxValue: number?)
	entityManager:SetClamps(entityId, statPath, minValue, maxValue)
end

function ModifiersService:SetEntityDecimalPlaces(entityId: string, statPath: string, decimalPlaces: number?)
	entityManager:SetDecimalPlaces(entityId, statPath, decimalPlaces)
end

function ModifiersService:AddEntityModifier(entityId: string, config: ModifierConfig): string
	return entityManager:AddModifier({
		entity = entityId,
		path = config.path,
		value = config.value,
		type = config.type,
		source = config.source,
		priority = config.priority,
		tags = config.tags,
		duration = config.duration,
		stackingRule = config.stackingRule,
		minValue = config.minValue,
		maxValue = config.maxValue,
	})
end

function ModifiersService:AddEntityModifiers(entityId: string, configs: { ModifierConfig }): { string }
	local entityConfigs = {}
	for _, config in configs do
		table.insert(entityConfigs, {
			entity = entityId,
			path = config.path,
			value = config.value,
			type = config.type,
			source = config.source,
			priority = config.priority,
			tags = config.tags,
			duration = config.duration,
			stackingRule = config.stackingRule,
			minValue = config.minValue,
			maxValue = config.maxValue,
		})
	end
	return entityManager:AddModifiers(entityConfigs)
end

function ModifiersService:RemoveEntityModifier(entityId: string, statPath: string, modifierId: string): boolean
	return entityManager:RemoveModifierById(entityId, statPath, modifierId)
end

function ModifiersService:RemoveEntityModifiersBySource(entityId: string, statPath: string, source: string): number
	return entityManager:RemoveBySource(entityId, statPath, source)
end

function ModifiersService:RemoveEntityModifiersByTag(entityId: string, statPath: string, tag: string): number
	return entityManager:RemoveByTag(entityId, statPath, tag)
end

function ModifiersService:RemoveAllEntityModifiersBySource(entityId: string, source: string): number
	return entityManager:RemoveAllBySource(entityId, source)
end

function ModifiersService:RemoveAllEntityModifiersByTag(entityId: string, tag: string): number
	return entityManager:RemoveAllByTag(entityId, tag)
end

function ModifiersService:GetEntityStat(entityId: string, statPath: string): number
	return entityManager:Get(entityId, statPath)
end

function ModifiersService:GetEntityModifiers(entityId: string, statPath: string): { Modifier }
	return entityManager:GetModifiers(entityId, statPath)
end

function ModifiersService:GetEntityModifiersBySource(entityId: string, statPath: string, source: string): { Modifier }
	return entityManager:GetModifiersBySource(entityId, statPath, source)
end

function ModifiersService:GetEntityModifiersByTag(entityId: string, statPath: string, tag: string): { Modifier }
	return entityManager:GetModifiersByTag(entityId, statPath, tag)
end

function ModifiersService:GetEntityStats(entityId: string): { string }
	return entityManager:GetEntityStats(entityId)
end

function ModifiersService:HasEntityStat(entityId: string, statPath: string): boolean
	return entityManager:HasStack(entityId, statPath)
end

function ModifiersService:OnEntityStatChanged(entityId: string, statPath: string, callback: (newValue: number) -> ()): any
	return entityManager:OnChanged(entityId, statPath, callback)
end

function ModifiersService:CleanupEntity(entityId: string)
	entityManager:CleanupEntity(entityId)
end

function ModifiersService:GetAllEntities(): { string }
	return entityManager:GetAllEntities()
end

function ModifiersService:GetEntityDebugInfo(entityId: string): { [string]: any }
	return entityManager:GetDebugInfo(entityId)
end

function ModifiersService:Register(player: Player, statPath: string)
	local definition = statDefinitions[statPath]
	if not definition then
		warn(`Cannot register undefined stat path: {statPath}`)
		return
	end
	playerManager:SetBase(player, statPath, definition.base)
	if definition.clamps then
		playerManager:SetClamps(player, statPath, definition.clamps[1], definition.clamps[2])
	end
	if definition.decimals then
		playerManager:SetDecimalPlaces(player, statPath, definition.decimals)
	end
end

function ModifiersService:Add(player: Player, statPath: string, value: number, operator: string, source: string, duration: number?): string
	local modifierType = OperatorMap[operator]
	if not modifierType then
		warn(`Invalid operator: {operator}. Use "+", "*", or "="`)
		modifierType = "Additive"
	end
	return playerManager:AddModifier({
		player = player,
		path = statPath,
		value = value,
		type = modifierType,
		source = source,
		duration = duration,
	})
end

function ModifiersService:Remove(player: Player, source: string): number
	return playerManager:RemoveAllBySource(player, source)
end

function ModifiersService:RemoveFrom(player: Player, statPath: string, source: string): number
	return playerManager:RemoveBySource(player, statPath, source)
end

function ModifiersService:Get(player: Player, statPath: string): number
	return playerManager:Get(player, statPath)
end

function ModifiersService:RegisterEntity(entityId: string, statPath: string)
	local definition = statDefinitions[statPath]
	if not definition then
		warn(`Cannot register undefined stat path: {statPath}`)
		return
	end
	entityManager:SetBase(entityId, statPath, definition.base)
	if definition.clamps then
		entityManager:SetClamps(entityId, statPath, definition.clamps[1], definition.clamps[2])
	end
	if definition.decimals then
		entityManager:SetDecimalPlaces(entityId, statPath, definition.decimals)
	end
end

function ModifiersService:AddEntity(entityId: string, statPath: string, value: number, operator: string, source: string, duration: number?): string
	local modifierType = OperatorMap[operator]
	if not modifierType then
		warn(`Invalid operator: {operator}. Use "+", "*", or "="`)
		modifierType = "Additive"
	end
	return entityManager:AddModifier({
		entity = entityId,
		path = statPath,
		value = value,
		type = modifierType,
		source = source,
		duration = duration,
	})
end

function ModifiersService:RemoveEntity(entityId: string, source: string): number
	return entityManager:RemoveAllBySource(entityId, source)
end

function ModifiersService:RemoveFromEntity(entityId: string, statPath: string, source: string): number
	return entityManager:RemoveBySource(entityId, statPath, source)
end

function ModifiersService:GetEntity(entityId: string, statPath: string): number
	return entityManager:Get(entityId, statPath)
end

function ModifiersService.Client:GetAllStats(player: Player): { [string]: StatSyncData }
	return playerManager:GetAllSyncData(player)
end

function ModifiersService:Init()
	entityManager = EntityManager.new()
	playerManager = PlayerManager.new()

	playerManager.onSyncRequired = function(player: Player, statPath: string, syncData: StatSyncData)
		ModifiersService.Client.StatSynced:Fire(player, statPath, syncData)
	end

	e2en.OnPlayerAdded(function(player: Player, trove: Types.Trove)
		trove:Add(function()
			playerManager:CleanupPlayer(player)
		end)
	end)
end

function ModifiersService:Start()
end

return ModifiersService
