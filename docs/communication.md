---
sidebar_position: 5
---

# Communication

e2en provides three ways for servers and clients to communicate: **Remote Methods**, **Remote Signals**, and **Remote Properties**. Each serves a different purpose.

## Overview

| Type | Direction | Use Case |
|------|-----------|----------|
| Remote Method | Client → Server | Request/response calls |
| Remote Signal | Both | Fire-and-forget events |
| Remote Property | Server → Client | Replicated state |

## Remote Methods

Functions in a Service's Client table become callable from clients.

### Server Definition

```lua
local ShopService = e2en.CreateService({
    Name = "ShopService",
    Client = {
        GetItems = function(self, player: Player): {any}
            return getAvailableItems()
        end,

        Purchase = function(self, player: Player, itemId: string): (boolean, string?)
            if typeof(itemId) ~= "string" then
                return false, "Invalid item"
            end

            if not canAfford(player, itemId) then
                return false, "Not enough coins"
            end

            giveItem(player, itemId)
            return true, nil
        end,
    },
})
```

### Client Usage

```lua
local ShopService = e2en.GetService("ShopService")

-- Call like a method (player is automatically passed)
local items = ShopService:GetItems()

local success, error = ShopService:Purchase("sword_01")
if not success then
    print("Failed:", error)
end
```

### Security

:::danger Always Validate
Remote methods are called by clients. Never trust the arguments:

```lua
Purchase = function(self, player: Player, itemId: any, quantity: any)
    -- Validate types
    if typeof(itemId) ~= "string" then return false end
    if typeof(quantity) ~= "number" then return false end
    if quantity < 1 or quantity > 99 then return false end
    if math.floor(quantity) ~= quantity then return false end

    -- Now safe to use
    ...
end
```
:::

## Remote Signals

Signals are fire-and-forget events that can flow both directions.

### Creating a Signal

```lua
local CombatService = e2en.CreateService({
    Name = "CombatService",
    Client = {
        DamageDealt = e2en.CreateSignal(),
        PlayerKilled = e2en.CreateSignal(),
    },
})
```

### Server → Client

#### Fire to One Player

```lua
self.Client.DamageDealt:Fire(player, { amount = 25, source = "Enemy" })
```

#### Fire to All Players

```lua
self.Client.PlayerKilled:FireAll({ victim = "Player1", killer = "Player2" })
```

#### Fire to Multiple Players

```lua
local team = getTeamPlayers("Red")
self.Client.DamageDealt:FireFor(team, { amount = 10 })
```

#### Fire to All Except One

```lua
self.Client.DamageDealt:FireExcept(excludedPlayer, data)
```

#### Fire with Filter

```lua
self.Client.DamageDealt:FireFilter(function(player)
    return player.Team == Teams.Blue
end, data)
```

### Client → Server

Clients can fire signals back:

```lua
-- Client
local CombatService = e2en.GetService("CombatService")
CombatService.DamageDealt:Fire({ target = "Enemy1" })

-- Server (listen for client fires)
self.Client.DamageDealt:Connect(function(player, data)
    -- Validate!
    if typeof(data) ~= "table" then return end
    if typeof(data.target) ~= "string" then return end

    handlePlayerAttack(player, data.target)
end)
```

### Client Listening

```lua
local CombatService = e2en.GetService("CombatService")

CombatService.DamageDealt:Connect(function(data)
    print("Took damage:", data.amount)
    showDamageEffect(data.amount)
end)
```

### Unreliable Signals

For high-frequency data where occasional packet loss is acceptable:

```lua
Client = {
    PositionUpdate = e2en.CreateUnreliableSignal(),
}

-- Uses UnreliableRemoteEvent under the hood
-- Lower latency, but packets may be dropped
```

## Remote Properties

Properties replicate state from server to client with built-in observation.

### Creating a Property

```lua
local GameService = e2en.CreateService({
    Name = "GameService",
    Client = {
        GamePhase = e2en.CreateProperty("Waiting"),
        RoundTime = e2en.CreateProperty(0),
        Scores = e2en.CreateProperty({}),
    },
})
```

### Server: Setting Values

#### Set for All Players

```lua
-- Clears per-player overrides
self.Client.GamePhase:Set("Playing")
```

#### Set Top Value Only

```lua
-- Sets the default without clearing per-player overrides
self.Client.RoundTime:SetTop(60)
```

#### Set for Specific Player

```lua
self.Client.Scores:SetFor(player, { kills = 5, deaths = 2 })
```

#### Set for Multiple Players

```lua
self.Client.Scores:SetForList(teamPlayers, { kills = 0, deaths = 0 })
```

#### Set with Filter

```lua
self.Client.Scores:SetFilter(function(player)
    return player:GetAttribute("VIP")
end, specialScores)
```

### Server: Reading Values

```lua
-- Get the top value
local phase = self.Client.GamePhase:Get()

-- Get value for specific player (respects per-player overrides)
local playerScores = self.Client.Scores:GetFor(player)
```

### Server: Clearing Overrides

```lua
-- Player reverts to the top value
self.Client.Scores:ClearFor(player)
self.Client.Scores:ClearForList(players)
```

### Server: Observing Changes

```lua
-- Called immediately with current value, then on each change
self.Client.GamePhase:Observe(function(phase)
    print("Phase changed to:", phase)
end)
```

### Client: Reading Values

```lua
local GameService = e2en.GetService("GameService")

-- Get current value
local phase = GameService.GamePhase:Get()
```

### Client: Observing Changes

```lua
-- Called immediately, then on each update
GameService.GamePhase:Observe(function(phase)
    updatePhaseUI(phase)
end)
```

### Client: Waiting for Initial Value

```lua
-- Check if initial value received
if GameService.Scores:IsReady() then
    local scores = GameService.Scores:Get()
end

-- Wait for ready (with optional timeout)
local scores = GameService.Scores:OnReady(5) -- 5 second timeout
if scores then
    print("Got scores:", scores)
else
    print("Timed out waiting for scores")
end
```

## Per-Player Properties

Properties support per-player overrides, which is perfect for player-specific state:

```lua
local DataService = e2en.CreateService({
    Name = "DataService",
    Client = {
        Coins = e2en.CreateProperty(0),
        Inventory = e2en.CreateProperty({}),
    },
})

function DataService:Start()
    e2en.OnPlayerAdded(function(player, trove)
        -- Load player's data
        local data = loadPlayerData(player)

        -- Set their specific values
        self.Client.Coins:SetFor(player, data.coins)
        self.Client.Inventory:SetFor(player, data.inventory)
    end)
end
```

On the client, each player sees only their own value:

```lua
local DataService = e2en.GetService("DataService")

DataService.Coins:Observe(function(coins)
    -- This is MY coins, not another player's
    updateCoinsUI(coins)
end)
```

## Choosing the Right Type

| Scenario | Use |
|----------|-----|
| Client requests data | Remote Method |
| Client performs action | Remote Method |
| Server notifies one-time event | Remote Signal |
| High-frequency updates (positions) | Unreliable Signal |
| Persistent replicated state | Remote Property |
| Per-player state | Remote Property with SetFor |
