local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local BaseModifierManager = require(script.Parent)
local Types = require(script.Parent.Types)
local Signal = require(script.Parent.Parent.Signal)

export type ModifierType = Types.ModifierType
export type StackingRule = Types.StackingRule
export type Modifier = Types.Modifier
export type StatStack = Types.StatStack
export type ModifierConfig = Types.ModifierConfig
export type StatSyncData = Types.StatSyncData
export type StackMap = Types.StackMap
export type StackKey = Types.StackKey

type PlayerModifierConfig = ModifierConfig & {
	player: Player,
}

type PlayerModifierManagerImpl = Types.PlayerModifierManagerData

local MODIFIER_SYNC_INTERVAL = 0.1

local PlayerModifierManager = setmetatable({}, BaseModifierManager)
PlayerModifierManager.__index = PlayerModifierManager

function PlayerModifierManager.new(): PlayerModifierManagerImpl
	local base = BaseModifierManager.new()
	local self: PlayerModifierManagerImpl = setmetatable(base, PlayerModifierManager) :: any

	if not RunService:IsServer() then
		error("PlayerModifierManager can only be used on the server")
	end

	self.pendingSyncs = {}
	self.onSyncRequired = nil

	PlayerModifierManager.InitializeServerSystems(self)

	return self
end

function PlayerModifierManager.InitializeServerSystems(self: PlayerModifierManagerImpl)
	self.trove:Add(Players.PlayerRemoving:Connect(function(player: Player)
		PlayerModifierManager.CleanupPlayer(self, player)
	end))

	self.trove:Add(task.spawn(function()
		while true do
			task.wait(MODIFIER_SYNC_INTERVAL)
			PlayerModifierManager.ProcessPendingSyncs(self)
		end
	end))
end

function PlayerModifierManager.Destroy(self: PlayerModifierManagerImpl)
	BaseModifierManager.Destroy(self)
	self.pendingSyncs = {}
	self.onSyncRequired = nil
end

function PlayerModifierManager.CleanupPlayer(self: PlayerModifierManagerImpl, player: Player)
	if self.stacks[player] then
		self.stacks[player] = nil
	end

	if self.signals[player] then
		for _, signal in self.signals[player] do
			signal:Destroy()
		end
		self.signals[player] = nil
	end

	if self.tagIndex[player] then
		self.tagIndex[player] = nil
	end

	self.pendingSyncs[player] = nil
end

function PlayerModifierManager.CleanupExpiredModifiers(self: PlayerModifierManagerImpl)
	local currentTime = os.clock()
	local affectedPaths: { [Player]: { [string]: boolean } } = {}

	while #self.expirationQueue > 0 do
		local entry = self.expirationQueue[1]
		if currentTime < entry.expireTime then
			break
		end

		table.remove(self.expirationQueue, 1)

		if self.pendingRemovals[entry.modifierId] then
			self.pendingRemovals[entry.modifierId] = nil
			continue
		end

		local player = entry.stackKey
		if typeof(player) ~= "Instance" or not player:IsA("Player") then
			continue
		end

		local stackKeyStacks = self.stacks[player]
		if not stackKeyStacks then
			continue
		end

		local stack = stackKeyStacks[entry.statPath]
		if not stack then
			continue
		end

		for index = #stack.modifiers, 1, -1 do
			local modifier = stack.modifiers[index]
			if modifier.id == entry.modifierId then
				BaseModifierManager.RemoveModifierFromTagIndex(self :: any, player, entry.statPath, modifier)
				table.remove(stack.modifiers, index)
				stack.isDirty = true
				PlayerModifierManager.TriggerChange(self, entry.statPath, player)

				if not affectedPaths[player] then
					affectedPaths[player] = {}
				end
				affectedPaths[player][entry.statPath] = true
				break
			end
		end
	end

	for player, paths in affectedPaths do
		if player.Parent then
			for statPath, _ in paths do
				PlayerModifierManager.QueueSync(self, player, statPath)
			end
		end
	end
end

function PlayerModifierManager.HasStack(self: PlayerModifierManagerImpl, player: Player, statPath: string): boolean
	return self.stacks[player] ~= nil and self.stacks[player][statPath] ~= nil
end

function PlayerModifierManager.GetStack(self: PlayerModifierManagerImpl, player: Player, statPath: string): StatStack
	if not player then
		error("Player parameter is required")
	end

	if not self.stacks[player] then
		self.stacks[player] = {}
		self.signals[player] = {}
		self.tagIndex[player] = {}
	end

	if not self.stacks[player][statPath] then
		self.stacks[player][statPath] = {
			baseValue = 0,
			modifiers = {},
			isDirty = true,
			cachedValue = nil,
		}
	end

	return self.stacks[player][statPath]
end

function PlayerModifierManager.SetBase(self: PlayerModifierManagerImpl, player: Player, statPath: string, baseValue: number)
	BaseModifierManager.SetBase(self :: any, player, statPath, baseValue)
	PlayerModifierManager.QueueSync(self, player, statPath)
end

function PlayerModifierManager.SetClamps(self: PlayerModifierManagerImpl, player: Player, statPath: string, minValue: number?, maxValue: number?)
	if not PlayerModifierManager.HasStack(self, player, statPath) then
		error("Stack does not exist. Call SetBase first")
	end

	BaseModifierManager.SetClamps(self :: any, player, statPath, minValue, maxValue)
	PlayerModifierManager.QueueSync(self, player, statPath)
end

function PlayerModifierManager.SetDecimalPlaces(self: PlayerModifierManagerImpl, player: Player, statPath: string, decimalPlaces: number?)
	if not PlayerModifierManager.HasStack(self, player, statPath) then
		error("Stack does not exist. Call SetBase first")
	end

	BaseModifierManager.SetDecimalPlaces(self :: any, player, statPath, decimalPlaces)
	PlayerModifierManager.QueueSync(self, player, statPath)
end

function PlayerModifierManager.AddModifierInternal(self: PlayerModifierManagerImpl, config: PlayerModifierConfig, shouldSync: boolean): string
	if not config.player then
		error("Player is required for AddModifier")
	end

	BaseModifierManager.ValidateStatPath(self :: any, config.path)

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

	local stack = PlayerModifierManager.GetStack(self, config.player, config.path)

	if config.stackingRule then
		local handled = BaseModifierManager.HandleStackingRule(
			self :: any,
			stack,
			config.stackingRule,
			config.source,
			config,
			config.player
		)
		if handled then
			if shouldSync then
				PlayerModifierManager.QueueSync(self, config.player, config.path)
			end
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
		BaseModifierManager.AddToExpirationQueue(self :: any, config.player, config.path, modifierId, expireTime)
	end

	local insertIndex = BaseModifierManager.FindInsertIndexBinarySearch(self :: any, stack.modifiers, modifier.priority)
	table.insert(stack.modifiers, insertIndex, modifier)

	BaseModifierManager.AddModifierToTagIndex(self :: any, config.player, config.path, modifier)

	stack.isDirty = true
	PlayerModifierManager.TriggerChange(self, config.path, config.player)

	if shouldSync then
		PlayerModifierManager.QueueSync(self, config.player, config.path)
	end

	return modifierId
end

function PlayerModifierManager.AddModifier(self: PlayerModifierManagerImpl, config: PlayerModifierConfig): string
	return PlayerModifierManager.AddModifierInternal(self, config, true)
end

function PlayerModifierManager.AddModifiers(self: PlayerModifierManagerImpl, configs: { PlayerModifierConfig }): { string }
	local modifierIds: { string } = {}
	local affectedPaths: { [Player]: { [string]: boolean } } = {}

	for _, config in configs do
		local id = PlayerModifierManager.AddModifierInternal(self, config, false)
		table.insert(modifierIds, id)

		if not affectedPaths[config.player] then
			affectedPaths[config.player] = {}
		end
		affectedPaths[config.player][config.path] = true
	end

	for player, paths in affectedPaths do
		for path, _ in paths do
			PlayerModifierManager.QueueSync(self, player, path)
		end
	end

	return modifierIds
end

function PlayerModifierManager.RemoveModifierById(self: PlayerModifierManagerImpl, player: Player, statPath: string, modifierId: string): boolean
	local result = BaseModifierManager.RemoveModifierById(self :: any, player, statPath, modifierId)
	if result then
		PlayerModifierManager.QueueSync(self, player, statPath)
	end
	return result
end

function PlayerModifierManager.RemoveBySource(self: PlayerModifierManagerImpl, player: Player, statPath: string, source: string): number
	local count = BaseModifierManager.RemoveBySource(self :: any, player, statPath, source)
	if count > 0 then
		PlayerModifierManager.QueueSync(self, player, statPath)
	end
	return count
end

function PlayerModifierManager.RemoveByTag(self: PlayerModifierManagerImpl, player: Player, statPath: string, tag: string): number
	local count = BaseModifierManager.RemoveByTag(self :: any, player, statPath, tag)
	if count > 0 then
		PlayerModifierManager.QueueSync(self, player, statPath)
	end
	return count
end

function PlayerModifierManager.RemoveAllBySource(self: PlayerModifierManagerImpl, player: Player, source: string): number
	local count = BaseModifierManager.RemoveAllBySource(self :: any, player, source)
	if count > 0 and self.stacks[player] then
		for statPath, _ in self.stacks[player] do
			PlayerModifierManager.QueueSync(self, player, statPath)
		end
	end
	return count
end

function PlayerModifierManager.RemoveAllByTag(self: PlayerModifierManagerImpl, player: Player, tag: string): number
	local affectedPaths: { string } = {}
	if self.tagIndex[player] then
		for statPath, tags in self.tagIndex[player] do
			if tags[tag] then
				table.insert(affectedPaths, statPath)
			end
		end
	end

	local count = BaseModifierManager.RemoveAllByTag(self :: any, player, tag)

	if count > 0 then
		for _, statPath in affectedPaths do
			PlayerModifierManager.QueueSync(self, player, statPath)
		end
	end

	return count
end

function PlayerModifierManager.Get(self: PlayerModifierManagerImpl, player: Player, statPath: string): number
	return BaseModifierManager.Get(self :: any, player, statPath)
end

function PlayerModifierManager.GetModifiers(self: PlayerModifierManagerImpl, player: Player, statPath: string): { Modifier }
	return BaseModifierManager.GetModifiers(self :: any, player, statPath)
end

function PlayerModifierManager.GetModifiersBySource(self: PlayerModifierManagerImpl, player: Player, statPath: string, source: string): { Modifier }
	return BaseModifierManager.GetModifiersBySource(self :: any, player, statPath, source)
end

function PlayerModifierManager.GetModifiersByTag(self: PlayerModifierManagerImpl, player: Player, statPath: string, tag: string): { Modifier }
	return BaseModifierManager.GetModifiersByTag(self :: any, player, statPath, tag)
end

function PlayerModifierManager.GetAllStats(self: PlayerModifierManagerImpl, player: Player): { string }
	if not self.stacks[player] then
		return {}
	end

	local stats: { string } = {}
	for statPath, _ in self.stacks[player] do
		table.insert(stats, statPath)
	end

	return stats
end

function PlayerModifierManager.GetAllSyncData(self: PlayerModifierManagerImpl, player: Player): { [string]: StatSyncData }
	local result: { [string]: StatSyncData } = {}

	if not self.stacks[player] then
		return result
	end

	for statPath, stack in self.stacks[player] do
		result[statPath] = PlayerModifierManager.BuildSyncData(self, stack)
	end

	return result
end

function PlayerModifierManager.OnChanged(self: PlayerModifierManagerImpl, player: Player, statPath: string, callback: (newValue: number) -> ()): Signal.Connection
	return BaseModifierManager.OnChanged(self :: any, player, statPath, callback)
end

function PlayerModifierManager.TriggerChange(self: PlayerModifierManagerImpl, statPath: string, player: Player)
	BaseModifierManager.TriggerChange(self :: any, statPath, player)
end

function PlayerModifierManager.QueueSync(self: PlayerModifierManagerImpl, player: Player, statPath: string)
	if not self.pendingSyncs[player] then
		self.pendingSyncs[player] = {}
	end

	self.pendingSyncs[player][statPath] = true
end

function PlayerModifierManager.ProcessPendingSyncs(self: PlayerModifierManagerImpl)
	for player, paths in self.pendingSyncs do
		if typeof(player) == "Instance" and player:IsA("Player") and player.Parent then
			for statPath, _ in paths do
				local stack = self.stacks[player] and self.stacks[player][statPath]
				if stack then
					PlayerModifierManager.SyncToClient(self, player, statPath, stack)
				end
			end
		end
		self.pendingSyncs[player] = nil
	end
end

function PlayerModifierManager.BuildSyncData(_self: PlayerModifierManagerImpl, stack: StatStack): StatSyncData
	local syncData: StatSyncData = {
		baseValue = stack.baseValue,
		modifiers = {},
		minClamp = stack.minClamp,
		maxClamp = stack.maxClamp,
		decimalPlaces = stack.decimalPlaces,
	}

	for _, modifier in stack.modifiers do
		table.insert(syncData.modifiers, {
			id = modifier.id,
			value = modifier.value,
			modifierType = modifier.modifierType,
			source = modifier.source,
			priority = modifier.priority,
			tags = modifier.tags,
			expireTime = modifier.expireTime,
			stackingRule = modifier.stackingRule,
			minValue = modifier.minValue,
			maxValue = modifier.maxValue,
		})
	end

	return syncData
end

function PlayerModifierManager.SyncToClient(self: PlayerModifierManagerImpl, player: Player, statPath: string, stack: StatStack)
	if not self.onSyncRequired then
		return
	end

	local syncData = PlayerModifierManager.BuildSyncData(self, stack)
	self.onSyncRequired(player, statPath, syncData)
end

function PlayerModifierManager.GetDebugInfo(self: PlayerModifierManagerImpl, player: Player): { [string]: any }
	return BaseModifierManager.GetDebugInfo(self :: any, player)
end

return PlayerModifierManager
