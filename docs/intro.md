---
sidebar_position: 1
---

# Introduction

e2en is an opinionated framework I use for my personal Roblox projects. It's heavily inspired by [Knit](https://sleitnick.github.io/Knit/) but structured the way I prefer to organize code.

## What It Does

e2en separates server and client code into **Services** and **Controllers**, groups related code into **Systems**, and handles networking automatically. Here's the basic structure:

```
Systems/
├── Combat/
│   ├── Service.luau    -- Server logic
│   ├── Controller.luau -- Client logic
│   └── Shared/         -- Shared code
├── Inventory/
│   ├── Service.luau
│   └── Controller.luau
```

### Automatic Networking

Services can expose signals, properties, and methods to clients without manually creating RemoteEvents.

```lua
-- Server
local CombatService = e2en.CreateService({
    Name = "CombatService",
    Client = {
        DamageDealt = e2en.CreateSignal(),  -- Clients can listen
        PlayerHealth = e2en.CreateProperty(100),  -- Synced state
    },
})

-- Later on the server...
self.Client.DamageDealt:Fire(player, { amount = 25 })
self.Client.PlayerHealth:SetFor(player, 75)
```

```lua
-- Client (automatically available)
local CombatService = e2en.GetService("CombatService")

CombatService.DamageDealt:Connect(function(data)
    print("Took", data.amount, "damage")
end)

CombatService.PlayerHealth:Observe(function(health)
    updateHealthBar(health)
end)
```

### Type Annotations

Written in strict Luau with type annotations for intellisense. The `:: any` cast is needed at the require boundary due to Luau's static analysis limitations, but explicit type annotations restore checking from that point on.

```lua
local e2en: Types.e2enServer = require(root) :: any
```

### Lifecycle Management

Player and character lifecycle hooks with automatic cleanup via Trove integration.

```lua
e2en.OnCharacterAdded(function(player, character, trove)
    -- This connection is automatically disconnected when character dies
    trove:Connect(character.Humanoid.Running, function(speed)
        print(player.Name, "running at", speed)
    end)
end)
```

## Core Concepts

| Concept | Description |
|---------|-------------|
| **Service** | Server-side singleton that handles game logic. Can expose signals, properties, and methods to clients. |
| **Controller** | Client-side singleton that handles local logic and UI. Can communicate with Services. |
| **System** | A folder containing a Service and/or Controller that work together. Keeps related code organized. |
| **RemoteSignal** | Server-to-client event system. Fire to one player, all players, or filtered subsets. |
| **RemoteProperty** | Replicated state with per-player overrides. Clients observe changes reactively. |

## Next Steps

[Getting Started](./getting-started) covers installation and setup.

Other topics:
- [Services](./services) - Server-side architecture
- [Controllers](./controllers) - Client-side architecture
- [Communication](./communication) - Networking between server and client
- [Lifecycle](./lifecycle) - Player and character event handling
