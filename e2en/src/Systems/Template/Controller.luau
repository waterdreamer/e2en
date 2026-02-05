local root = script.Parent.Parent.Parent
local Types = require(root.Types)

local e2en: Types.e2enClient = require(root) :: any

local TemplateController = e2en.CreateController({
	Name = "TemplateController",
})

function TemplateController:Init() end

function TemplateController:Start() end

return TemplateController
