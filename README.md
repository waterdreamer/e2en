# e2en

A Knit-inspired opinionated Roblox framework.

**[Documentation](https://estrogenie.github.io/e2en/)**

## Features

- **System-based architecture** - Organize code into Services (server), Controllers (client), and Shared modules
- **Automatic replication** - Client code is automatically replicated to ReplicatedStorage at runtime
- **Dependency management** - Topological sorting ensures proper initialization order
- **Built-in networking** - RemoteSignal, RemoteProperty, and RemoteFunction abstractions
- **Player lifecycle management** - Trove-based cleanup for players and characters
- **Middleware support** - Intercept inbound/outbound network calls

## Project Structure

```
e2en/src/
├── Core/           # Framework internals
├── Libraries/      # Signal, Trove, Component
├── Environment/    # Assets allocated at runtime
├── Shared/         # Code shared between server and client
└── Systems/        # Your game systems
    └── Example/
        ├── Service.luau      # Server-only
        ├── Controller.luau   # Client-only
        └── Shared.luau       # Both
```

## Requirements

Tools are managed via [Aftman](https://github.com/LPGhatguy/aftman):

- Rojo 7.6.1
- Selene 0.28.0
- Luau LSP 1.56.2

## Quick Start

```lua
-- Server: src/server/Loader.server.luau
local ServerScriptService = game:GetService("ServerScriptService")
local e2en = require(ServerScriptService.e2en)

e2en.Run()
```

## License

MIT
