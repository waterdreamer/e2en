--!strict
export type ColorTable = {
	R: number,
	G: number,
	B: number,
}

local Color = {}

function Color:RGBToVertex(r: number, g: number, b: number): (number, number, number)
	return r / 255, g / 255, b / 255
end

function Color:VertexToRGB(r: number, g: number, b: number): (number, number, number)
	return math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5)
end

function Color:Color3ToVertex(color: Color3): (number, number, number)
	return color.R, color.G, color.B
end

function Color:VertexToColor3(r: number, g: number, b: number): Color3
	return Color3.new(r, g, b)
end

function Color:RGBToColor3(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

function Color:TableToColor3(colorTable: ColorTable | Color3 | nil): Color3?
	if not colorTable then
		return nil
	end

	if typeof(colorTable) == "Color3" then
		return colorTable
	end

	local asTable = colorTable :: ColorTable
	if asTable.R and asTable.G and asTable.B then
		return Color3.new(asTable.R, asTable.G, asTable.B)
	end

	return nil
end

function Color:Color3ToTable(color: Color3): ColorTable?
	if typeof(color) ~= "Color3" then
		return nil
	end

	return { R = color.R, G = color.G, B = color.B }
end

function Color:Color3ToRGB(color: Color3): (number, number, number)
	return self:VertexToRGB(color.R, color.G, color.B)
end

function Color:Lerp(colorA: Color3, colorB: Color3, alpha: number): Color3
	return colorA:Lerp(colorB, alpha)
end

function Color:LerpVertex(r1: number, g1: number, b1: number, r2: number, g2: number, b2: number, alpha: number): (number, number, number)
	return r1 + (r2 - r1) * alpha, g1 + (g2 - g1) * alpha, b1 + (b2 - b1) * alpha
end

function Color:MultiplyVertex(r: number, g: number, b: number, factor: number): (number, number, number)
	return math.clamp(r * factor, 0, 1), math.clamp(g * factor, 0, 1), math.clamp(b * factor, 0, 1)
end

function Color:AddVertex(r1: number, g1: number, b1: number, r2: number, g2: number, b2: number): (number, number, number)
	return math.clamp(r1 + r2, 0, 1), math.clamp(g1 + g2, 0, 1), math.clamp(b1 + b2, 0, 1)
end

return Color
