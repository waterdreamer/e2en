---
sidebar_position: 2
---

# Getting Started

This guide walks you through setting up e2en in a new or existing Roblox project.

## Installation

1. Download or clone the repository from GitHub
2. Place the `e2en` folder in `ServerScriptService`

## Project Structure

e2en expects this folder structure:

```
ServerScriptService/
└── e2en/
    └── src/
        ├── init.luau
        ├── Systems/          -- Your game systems go here
        │   └── Example/
        │       ├── Service.luau
        │       └── Controller.luau
        ├── Shared/
        │   └── common/       -- Shared data, configs
        └── Environment/      -- StarterGui, StarterPlayerScripts, etc.

src/
└── server/
    └── Loader.server.luau   -- Server entry point
```

## Server Setup

Create a loader script that starts the framework. Place this in `ServerScriptService` or your equivalent server scripts folder.

```lua
-- Loader.server.luau
local ServerScriptService = game:GetService("ServerScriptService")
local Types = require(ServerScriptService.e2en.Types)

local e2en: Types.e2enServer = require(ServerScriptService.e2en) :: any

e2en.Run()
```

That's it. `Run()` does several things automatically:
1. Moves assets from `Environment/` to their proper locations (StarterGui, etc.)
2. Discovers and loads all Services from `Systems/`
3. Replicates the framework to clients (stripping server-only code)
4. Initializes and starts all Services in dependency order

## Creating Your First Service

Services are server-side singletons. Create one in `Systems/MySystem/Service.luau`:

```lua
local root = script.Parent.Parent.Parent
local Types = require(root.Types)

local e2en: Types.e2enServer = require(root) :: any

local MyService = e2en.CreateService({
    Name = "MyService",
    Client = {
        -- Things clients can access
        SomethingHappened = e2en.CreateSignal(),
        CurrentScore = e2en.CreateProperty(0),
    },
})

function MyService:Init()
    -- Called synchronously during startup
    -- Safe to call GetService() for dependencies
    print("MyService initializing")
end

function MyService:Start()
    -- Called after all Services have initialized
    -- Runs asynchronously
    print("MyService started")
end

function MyService:AddScore(player: Player, amount: number)
    local currentScore = self.Client.CurrentScore:GetFor(player)
    self.Client.CurrentScore:SetFor(player, currentScore + amount)
end

return MyService
```

## Creating Your First Controller

Controllers are client-side singletons. Create one in `Systems/MySystem/Controller.luau`:

```lua
local root = script.Parent.Parent.Parent
local Types = require(root.Types)

local e2en: Types.e2enClient = require(root) :: any

local MyController = e2en.CreateController({
    Name = "MyController",
})

function MyController:Init()
    print("MyController initializing")
end

function MyController:Start()
    -- Access server services
    local MyService = e2en.GetService("MyService")

    -- Listen for server events
    MyService.SomethingHappened:Connect(function(data)
        print("Server said:", data)
    end)

    -- Observe replicated state
    MyService.CurrentScore:Observe(function(score)
        print("Score updated:", score)
    end)
end

return MyController
```

## Understanding the Lifecycle

When `e2en.Run()` is called:

```
Server                              Client
──────                              ──────
1. Environment allocated
2. Systems discovered
3. Framework replicated to client ──────> Client receives framework
4. Init() called (sync, in order)         Init() called (sync, in order)
5. Player lifecycle setup
6. Start() called (async)                 Start() called (async)
7. Services exposed to clients
```

### Init vs Start

| Phase | When | Use For |
|-------|------|---------|
| `Init()` | Synchronous, dependency order | Setting up references, registering handlers |
| `Start()` | Asynchronous, after all Init | Starting game loops, initial data loads |

In `Init()`, you can safely call `GetService()` or `GetController()` for any declared dependency. In `Start()`, everything is available.

## Dependencies

If your Service needs another Service during `Init()`, declare the dependency:

```lua
local MyService = e2en.CreateService({
    Name = "MyService",
    Dependencies = { "DataService", "PlayerService" },
})

function MyService:Init()
    -- DataService and PlayerService are guaranteed to be initialized
    local DataService = e2en.GetService("DataService")
end
```

## Next Steps

Now that you have the basics:

- [Services](./services) - Deep dive into server-side architecture
- [Controllers](./controllers) - Client-side patterns and UI integration
- [Communication](./communication) - RemoteSignals and RemoteProperties
- [Lifecycle](./lifecycle) - Player and character lifecycle management
