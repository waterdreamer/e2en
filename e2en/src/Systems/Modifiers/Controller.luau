local root = script.Parent.Parent.Parent
local Types = require(root.Types)
local SharedTypes = require(script.Parent.Shared.Types)

local ModifierManager = root.Libraries.ModifierManager
local Calculator = require(ModifierManager.Calculator)
local Signal = require(root.Libraries.Signal)

local e2en: Types.e2enClient = require(root) :: any

type Modifier = SharedTypes.Modifier
type StatSyncData = SharedTypes.StatSyncData

type StatData = {
	baseValue: number,
	modifiers: { Modifier },
	cachedValue: number?,
	isDirty: boolean,
	minClamp: number?,
	maxClamp: number?,
	decimalPlaces: number?,
	signal: any?,
}

local ModifiersController = e2en.CreateController({
	Name = "ModifiersController",
})

local modifiersService: { [string]: any }
local stats: { [string]: StatData } = {}
local initialSyncComplete = false

local function calculateValue(statData: StatData): number
	if not statData.isDirty and statData.cachedValue ~= nil then
		return statData.cachedValue
	end

	local finalValue = Calculator.calculateValue({
		baseValue = statData.baseValue,
		modifiers = statData.modifiers,
		minClamp = statData.minClamp,
		maxClamp = statData.maxClamp,
		decimalPlaces = statData.decimalPlaces,
	})

	statData.cachedValue = finalValue
	statData.isDirty = false

	return finalValue
end

local function handleStatSync(statPath: string, syncData: StatSyncData)
	local existing = stats[statPath]
	local signal = existing and existing.signal or nil

	stats[statPath] = {
		baseValue = syncData.baseValue,
		modifiers = syncData.modifiers,
		cachedValue = nil,
		isDirty = true,
		minClamp = syncData.minClamp,
		maxClamp = syncData.maxClamp,
		decimalPlaces = syncData.decimalPlaces,
		signal = signal,
	}

	if signal then
		local newValue = calculateValue(stats[statPath])
		signal:Fire(newValue)
	end
end

function ModifiersController:GetStat(statPath: string): number
	local statData = stats[statPath]
	if not statData then
		if initialSyncComplete then
			warn(`GetStat called for unknown stat: {statPath}`)
		end
		return 0
	end
	return calculateValue(statData)
end

function ModifiersController:GetModifiers(statPath: string): { Modifier }
	local statData = stats[statPath]
	if not statData then
		return {}
	end
	return statData.modifiers
end

function ModifiersController:GetModifiersBySource(statPath: string, source: string): { Modifier }
	local statData = stats[statPath]
	if not statData then
		return {}
	end

	local result: { Modifier } = {}
	for _, modifier in statData.modifiers do
		if modifier.source == source then
			table.insert(result, modifier)
		end
	end
	return result
end

function ModifiersController:GetModifiersByTag(statPath: string, tag: string): { Modifier }
	local statData = stats[statPath]
	if not statData then
		return {}
	end

	local result: { Modifier } = {}
	for _, modifier in statData.modifiers do
		for _, modifierTag in modifier.tags do
			if modifierTag == tag then
				table.insert(result, modifier)
				break
			end
		end
	end
	return result
end

function ModifiersController:GetAllStats(): { string }
	local statPaths: { string } = {}
	for statPath in stats do
		table.insert(statPaths, statPath)
	end
	return statPaths
end

function ModifiersController:HasStat(statPath: string): boolean
	return stats[statPath] ~= nil
end

function ModifiersController:OnStatChanged(statPath: string, callback: (newValue: number) -> ()): any
	local statData = stats[statPath]
	if not statData then
		local newSignal = Signal.new()
		stats[statPath] = {
			baseValue = 0,
			modifiers = {},
			cachedValue = nil,
			isDirty = true,
			signal = newSignal,
		}
		return newSignal:Connect(callback)
	end

	if not statData.signal then
		local newSignal = Signal.new()
		statData.signal = newSignal
		return newSignal:Connect(callback)
	end

	return statData.signal:Connect(callback)
end

function ModifiersController:GetBaseValue(statPath: string): number
	local statData = stats[statPath]
	if not statData then
		return 0
	end
	return statData.baseValue
end

function ModifiersController:IsInitialized(): boolean
	return initialSyncComplete
end

function ModifiersController:WaitForInitialSync()
	while not initialSyncComplete do
		task.wait()
	end
end

function ModifiersController:Init()
	modifiersService = e2en.GetService("ModifiersService")

	modifiersService.StatSynced:Connect(function(statPath: string, syncData: StatSyncData)
		handleStatSync(statPath, syncData)
	end)
end

function ModifiersController:Start()
	local allStats = modifiersService:GetAllStats()
	if allStats then
		for statPath, syncData in allStats do
			handleStatSync(statPath, syncData)
		end
	end
	initialSyncComplete = true
end

return ModifiersController
