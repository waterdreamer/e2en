---
sidebar_position: 10
---

# Type Safety

This guide explains how to set up intellisense and type checking in your project.

## The `:: any` Pattern

You'll see this pattern when requiring the framework:

```lua
local e2en: Types.e2enServer = require(root) :: any
```

The framework returns different modules at runtime depending on context (server vs client), which Luau's static analysis can't resolve. The `:: any` cast bypasses the type error at this boundary, and the explicit annotation (`: Types.e2enServer`) restores intellisense and type checking for all subsequent code.

## Setting Up Types

### Server Code

```lua
local root = script.Parent.Parent.Parent
local Types = require(root.Types)

local e2en: Types.e2enServer = require(root) :: any
```

### Client Code

```lua
local root = script.Parent.Parent.Parent
local Types = require(root.Types)

local e2en: Types.e2enClient = require(root) :: any
```

## Available Types

Import types from the Types module:

```lua
local Types = require(root.Types)

-- Core types
export type Service = Types.Service
export type Controller = Types.Controller
export type ServiceDefinition = Types.ServiceDefinition
export type ControllerDefinition = Types.ControllerDefinition

-- Communication types
export type RemoteSignal<T...> = Types.RemoteSignal<T...>
export type RemoteProperty<T> = Types.RemoteProperty<T>
export type ClientRemoteSignal<T...> = Types.ClientRemoteSignal<T...>
export type ClientRemoteProperty<T> = Types.ClientRemoteProperty<T>

-- Utility types
export type Trove = Types.Trove
export type Signal<T...> = Types.Signal<T...>
export type Connection = Types.Connection
```

## Type Checking Commands

Run type checking after every `.luau` change:

```bash
luau-lsp analyze \
  --sourcemap=sourcemap.json \
  --defs=.luau-types/globalTypes.d.luau \
  --flag:LuauSolverV2=false \
  --ignore="**/Libraries/**" \
  --ignore="**/Iris/**" \
  e2en/src src
```

Generate the sourcemap first:

```bash
rojo sourcemap default.project.json --output sourcemap.json
```

## Strict Mode

e2en uses strict mode via `.luaurc`, not `--!strict` comments. Your `.luaurc` should include:

```json
{
    "languageMode": "strict"
}
```

## Validating Client Input

When handling client input, use `any` (not `unknown`) and validate:

```lua
function MyService.Client:DoSomething(player: Player, value: any): boolean
    -- Validate type
    if typeof(value) ~= "string" then
        return false
    end

    -- Now value is narrowed to string
    return self.Server:ProcessString(player, value)
end
```

### Type Narrowing

Use guard clauses for type narrowing:

```lua
-- Good: Guard clause narrows type
function process(data: any)
    if typeof(data) ~= "table" then
        return
    end
    -- data is now table

    if typeof(data.name) ~= "string" then
        return
    end
    -- data.name is now string
end

-- Avoid: Conditional access doesn't narrow
function process(data: any)
    if data and data.name then
        -- data.name is still any
    end
end
```

## Generic Services

Type your custom service methods:

```lua
local InventoryService = e2en.CreateService({
    Name = "InventoryService",
    Client = {},

    _items = {} :: { [Player]: { string } },
})

function InventoryService:GetItems(player: Player): { string }
    return self._items[player] or {}
end

function InventoryService:AddItem(player: Player, itemId: string): boolean
    local items = self._items[player]
    if not items then
        items = {}
        self._items[player] = items
    end
    table.insert(items, itemId)
    return true
end
```

## Typed Remote Properties

```lua
type PlayerData = {
    coins: number,
    level: number,
    inventory: { string },
}

local DataService = e2en.CreateService({
    Name = "DataService",
    Client = {
        PlayerData = e2en.CreateProperty({} :: PlayerData),
    },
})

-- Type is inferred
self.Client.PlayerData:SetFor(player, {
    coins = 100,
    level = 1,
    inventory = {},
})
```

## Typed Signals

```lua
type DamageEvent = {
    amount: number,
    source: string,
    critical: boolean,
}

local CombatService = e2en.CreateService({
    Name = "CombatService",
    Client = {
        DamageDealt = e2en.CreateSignal(), -- RemoteSignal<DamageEvent>
    },
})

-- Fire with typed data
self.Client.DamageDealt:Fire(player, {
    amount = 25,
    source = "Enemy",
    critical = false,
} :: DamageEvent)
```

## Common Type Patterns

### Optional Values

```lua
function findPlayer(name: string): Player?
    for _, player in Players:GetPlayers() do
        if player.Name == name then
            return player
        end
    end
    return nil
end

local player = findPlayer("Bob")
if player then
    -- player is Player (not Player?)
end
```

### Callbacks with Trove

```lua
e2en.OnCharacterAdded(function(player: Player, character: Model, trove: Trove)
    local humanoid = character:WaitForChild("Humanoid") :: Humanoid

    trove:Connect(humanoid.Died, function()
        -- Type-safe callback
    end)
end)
```

### Type Assertions

When you know more than the type system:

```lua
local part = workspace:FindFirstChild("SpawnPoint")
assert(part, "SpawnPoint not found")

-- part is Instance, but we know it's a Part
local spawnPart = part :: Part
print(spawnPart.Position)
```

## Excluded from Strict Checking

Some folders are excluded from strict type checking:

- `Libraries/` - Third-party code
- `Iris/` - UI library
- `ShapecastHitbox/` - External module
- `ClientLoader.client.luau` - Bootstrap script

Configure exclusions in your type check command with `--ignore`.
