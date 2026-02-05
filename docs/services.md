---
sidebar_position: 3
---

# Services

Services are server-side singletons that handle your game logic. Each Service manages a specific domain of your game: combat, inventory, matchmaking, etc.

## Creating a Service

```lua
local root = script.Parent.Parent.Parent
local Types = require(root.Types)

local e2en: Types.e2enServer = require(root) :: any

local InventoryService = e2en.CreateService({
    Name = "InventoryService",
})

function InventoryService:Init()
    -- Setup code
end

function InventoryService:Start()
    -- Game loop code
end

return InventoryService
```

## Service Definition

The table passed to `CreateService` can include:

| Field | Type | Description |
|-------|------|-------------|
| `Name` | `string` | **Required.** Unique identifier for the service. |
| `Client` | `table` | Methods, signals, and properties exposed to clients. |
| `Dependencies` | `{string}` | Services that must initialize before this one. |
| `Init` | `function` | Called synchronously during startup. |
| `Start` | `function` | Called asynchronously after all services initialize. |
| *custom* | `any` | Any other fields become part of the service table. |

## The Client Table

The `Client` table defines what clients can access. It supports three types of entries:

### Functions (Remote Methods)

Functions in the Client table become callable from clients:

```lua
local ShopService = e2en.CreateService({
    Name = "ShopService",
    Client = {
        PurchaseItem = function(self, player: Player, itemId: string): boolean
            -- 'self' is the Client table
            -- 'player' is automatically injected
            if not hasEnoughGold(player, itemId) then
                return false
            end
            giveItem(player, itemId)
            return true
        end,
    },
})
```

On the client:
```lua
local ShopService = e2en.GetService("ShopService")
local success = ShopService:PurchaseItem("sword_01")
```

:::caution Validate Client Input
Never trust data from clients. Always validate:
```lua
PurchaseItem = function(self, player: Player, itemId: any): boolean
    if typeof(itemId) ~= "string" then
        return false
    end
    -- Now safe to use
end
```
:::

### Signals (Remote Events)

Use `CreateSignal()` for events you want to fire to clients:

```lua
local CombatService = e2en.CreateService({
    Name = "CombatService",
    Client = {
        DamageDealt = e2en.CreateSignal(),
        PlayerKilled = e2en.CreateSignal(),
    },
})

-- Fire to a specific player
self.Client.DamageDealt:Fire(player, { amount = 25, source = "Enemy" })

-- Fire to all players
self.Client.PlayerKilled:FireAll({ victim = player.Name, killer = enemyName })
```

Clients can also fire signals back to the server:
```lua
-- Server
self.Client.DamageDealt:Connect(function(player, data)
    -- Handle client-sent event
    -- Always validate!
end)
```

For high-frequency, loss-tolerant data (like position updates), use unreliable signals:
```lua
Client = {
    PositionUpdate = e2en.CreateUnreliableSignal(),
}
```

### Properties (Replicated State)

Use `CreateProperty()` for state that should sync to clients:

```lua
local GameService = e2en.CreateService({
    Name = "GameService",
    Client = {
        GamePhase = e2en.CreateProperty("Waiting"),
        PlayerScores = e2en.CreateProperty({}),
    },
})

-- Set for all players
self.Client.GamePhase:Set("Playing")

-- Set for a specific player
self.Client.PlayerScores:SetFor(player, { kills = 5, deaths = 2 })
```

## Accessing Other Services

Use `GetService()` to access other services:

```lua
function InventoryService:Start()
    local DataService = e2en.GetService("DataService")
    local PlayerService = e2en.GetService("PlayerService")
end
```

If you need a service during `Init()`, declare it as a dependency:

```lua
local InventoryService = e2en.CreateService({
    Name = "InventoryService",
    Dependencies = { "DataService" },
})

function InventoryService:Init()
    -- DataService is guaranteed to be initialized
    self._dataService = e2en.GetService("DataService")
end
```

## Custom Properties and Methods

Add any properties or methods you need:

```lua
local MatchService = e2en.CreateService({
    Name = "MatchService",

    -- Custom properties
    _matches = {},
    _config = {
        maxPlayersPerMatch = 10,
        matchDuration = 300,
    },
})

-- Custom methods
function MatchService:CreateMatch(players: {Player})
    local match = {
        id = HttpService:GenerateGUID(),
        players = players,
        startTime = os.clock(),
    }
    self._matches[match.id] = match
    return match
end

function MatchService:EndMatch(matchId: string)
    local match = self._matches[matchId]
    if match then
        -- Cleanup logic
        self._matches[matchId] = nil
    end
end
```

## Loading Services

### Automatic (Recommended)

When you call `e2en.Run()`, it automatically loads all Services from the `Systems/` folder:

```
Systems/
├── Combat/
│   └── Service.luau  ← Loaded automatically
├── Inventory/
│   └── Service.luau  ← Loaded automatically
```

### Manual Loading

For more control, use the loading methods:

```lua
-- Load direct children
e2en.AddServices(someFolder)

-- Load all descendants
e2en.AddServicesDeep(someFolder)

-- Load Service.luau from immediate child folders
e2en.AddSystems(someFolder)

-- Load Service.luau from all descendant folders
e2en.AddSystemsDeep(someFolder)
```

## Example: Complete Service

```lua
local root = script.Parent.Parent.Parent
local Types = require(root.Types)

local e2en: Types.e2enServer = require(root) :: any

local CurrencyService = e2en.CreateService({
    Name = "CurrencyService",
    Dependencies = { "DataService" },

    Client = {
        CoinsChanged = e2en.CreateSignal(),
        Coins = e2en.CreateProperty(0),

        GetCoins = function(self, player: Player): number
            return self.Server:GetCoins(player)
        end,
    },

    _playerCoins = {},
})

function CurrencyService:Init()
    self._dataService = e2en.GetService("DataService")
end

function CurrencyService:Start()
    e2en.OnPlayerAdded(function(player, trove)
        local data = self._dataService:GetData(player)
        self._playerCoins[player] = data.coins or 0
        self.Client.Coins:SetFor(player, self._playerCoins[player])
    end)

    e2en.OnPlayerRemoving(function(player)
        self._playerCoins[player] = nil
    end)
end

function CurrencyService:GetCoins(player: Player): number
    return self._playerCoins[player] or 0
end

function CurrencyService:AddCoins(player: Player, amount: number)
    local current = self:GetCoins(player)
    local newAmount = current + amount
    self._playerCoins[player] = newAmount
    self.Client.Coins:SetFor(player, newAmount)
    self.Client.CoinsChanged:Fire(player, { old = current, new = newAmount })
end

return CurrencyService
```
