local root = script.Parent.Parent.Parent
local Types = require(root.Types)

local e2en: Types.e2enServer = require(root) :: any

local TemplateService = e2en.CreateService({
	Name = "TemplateService",
	Client = {},
})

function TemplateService:Init() end

function TemplateService:Start() end

return TemplateService
