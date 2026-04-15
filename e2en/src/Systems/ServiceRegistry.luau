--[[
	ServiceRegistry - Central index of all services and their types.

	Open this file to see every available service at a glance.
	Import from here when you need to cast GetService results.

	SERVER USAGE:
		local Registry = require(root.Systems.ServiceRegistry)
		local modifiersService = e2en.GetService("ModifiersService") :: Registry.ModifiersServiceType

	CLIENT USAGE:
		local Registry = require(root.Systems.ServiceRegistry)
		local modifiersService = e2en.GetService("ModifiersService") :: Registry.ModifiersServiceProxy
]]

local ExampleService = require(script.Parent.Example.Service)
local ExampleClientTypes = require(script.Parent.Example.Shared.ClientTypes)

local ModifiersService = require(script.Parent.Modifiers.Service)
local ModifiersClientTypes = require(script.Parent.Modifiers.Shared.ClientTypes)

-- Server-side service types (for service-to-service calls)
export type ExampleServiceType = ExampleService.ExampleServiceType
export type ModifiersServiceType = ModifiersService.ModifiersServiceType

-- Client proxy types (for controller-to-service calls)
export type ExampleServiceProxy = ExampleClientTypes.ExampleServiceProxy
export type ModifiersServiceProxy = ModifiersClientTypes.ModifiersServiceProxy

return nil
