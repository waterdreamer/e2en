--!strict
local Types = require(script.Parent.Types)

type Modifier = Types.Modifier

export type CalculationInput = {
	baseValue: number,
	modifiers: { Modifier },
	minClamp: number?,
	maxClamp: number?,
	decimalPlaces: number?,
}

local function calculateValue(input: CalculationInput): number
	local additiveTotal: number = 0
	local multiplicativeTotal: number = 1
	local overrideValue: number? = nil
	local highestOverridePriority: number = -math.huge

	for _, modifier in input.modifiers do
		local modifierValue: number = modifier.value

		if modifier.minValue then
			modifierValue = math.max(modifierValue, modifier.minValue)
		end
		if modifier.maxValue then
			modifierValue = math.min(modifierValue, modifier.maxValue)
		end

		if modifier.modifierType == "Additive" then
			additiveTotal = additiveTotal + modifierValue
		elseif modifier.modifierType == "Multiplicative" then
			multiplicativeTotal = multiplicativeTotal * modifierValue
		elseif modifier.modifierType == "Override" then
			if modifier.priority > highestOverridePriority then
				overrideValue = modifierValue
				highestOverridePriority = modifier.priority
			end
		end
	end

	local finalValue: number
	if overrideValue ~= nil then
		finalValue = overrideValue
	else
		finalValue = (input.baseValue + additiveTotal) * multiplicativeTotal
	end

	if input.minClamp then
		finalValue = math.max(finalValue, input.minClamp)
	end
	if input.maxClamp then
		finalValue = math.min(finalValue, input.maxClamp)
	end

	if input.decimalPlaces then
		local multiplier = 10 ^ input.decimalPlaces
		finalValue = math.round(finalValue * multiplier) / multiplier
	end

	return finalValue
end

return {
	calculateValue = calculateValue,
}
