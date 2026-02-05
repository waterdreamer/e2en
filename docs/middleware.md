---
sidebar_position: 9
---

# Middleware

Middleware intercepts network traffic between clients and servers. Use it for logging, validation, rate limiting, or data transformation.

## Configuration

Pass middleware to `e2en.Run()`:

```lua
e2en.Run({
    Middleware = {
        Inbound = { validateMiddleware, logMiddleware },
        Outbound = { serializeMiddleware },
    }
})
```

## Inbound Middleware

Inbound middleware intercepts **client → server** remote function calls.

### Signature

```lua
function(player: Player, serviceName: string, methodName: string, args: {any}): (boolean, {any})
```

| Parameter | Description |
|-----------|-------------|
| `player` | The player making the request |
| `serviceName` | Name of the service being called |
| `methodName` | Name of the method being called |
| `args` | Arguments passed by the client |

| Return | Description |
|--------|-------------|
| `boolean` | `true` to continue, `false` to drop the request |
| `{any}` | The (possibly modified) arguments to pass forward |

### Example: Logging

```lua
local function logMiddleware(player, serviceName, methodName, args)
    print(string.format(
        "[%s] %s called %s:%s",
        os.date("%H:%M:%S"),
        player.Name,
        serviceName,
        methodName
    ))
    return true, args
end
```

### Example: Rate Limiting

```lua
local rateLimits = {}
local RATE_LIMIT = 10  -- calls per second

local function rateLimitMiddleware(player, serviceName, methodName, args)
    local key = player.UserId .. ":" .. serviceName .. ":" .. methodName
    local now = os.clock()

    local history = rateLimits[key] or {}

    -- Remove old entries
    local newHistory = {}
    for _, timestamp in history do
        if now - timestamp < 1 then
            table.insert(newHistory, timestamp)
        end
    end

    if #newHistory >= RATE_LIMIT then
        warn(player.Name, "rate limited on", serviceName .. ":" .. methodName)
        return false, {}
    end

    table.insert(newHistory, now)
    rateLimits[key] = newHistory

    return true, args
end
```

### Example: Validation

```lua
local function validateMiddleware(player, serviceName, methodName, args)
    -- Check if player is still valid
    if not player.Parent then
        return false, {}
    end

    -- Check if player is banned
    if bannedPlayers[player.UserId] then
        return false, {}
    end

    return true, args
end
```

## Outbound Middleware

Outbound middleware intercepts **server → client** signals and property updates.

### Signature

```lua
function(player: Player?, serviceName: string, signalName: string, args: {any}): (boolean, {any})
```

| Parameter | Description |
|-----------|-------------|
| `player` | Target player (`nil` for FireAll) |
| `serviceName` | Name of the service |
| `signalName` | Name of the signal or property |
| `args` | Data being sent |

### Example: Serialization

```lua
local function serializeMiddleware(player, serviceName, signalName, args)
    -- Convert Vector3 to table for network efficiency
    local processed = {}
    for i, arg in args do
        if typeof(arg) == "Vector3" then
            processed[i] = { x = arg.X, y = arg.Y, z = arg.Z }
        else
            processed[i] = arg
        end
    end
    return true, processed
end
```

### Example: Filtering Sensitive Data

```lua
local function filterMiddleware(player, serviceName, signalName, args)
    -- Don't send admin data to non-admins
    if signalName == "AdminData" then
        if not player or not player:GetAttribute("IsAdmin") then
            return false, {}
        end
    end
    return true, args
end
```

## Middleware Chain

Middleware runs in array order. Each middleware receives the output of the previous one.

```lua
Middleware = {
    Inbound = { first, second, third },
}
```

```
Request arrives
      │
      ▼
  ┌─────────┐
  │  first  │ ── returns true, modifiedArgs1
  └─────────┘
      │
      ▼
  ┌─────────┐
  │ second  │ ── returns true, modifiedArgs2
  └─────────┘
      │
      ▼
  ┌─────────┐
  │  third  │ ── returns true, finalArgs
  └─────────┘
      │
      ▼
  Handler called with finalArgs
```

If any middleware returns `false`, the chain stops and the request is dropped:

```
Request arrives
      │
      ▼
  ┌─────────┐
  │  first  │ ── returns true, args
  └─────────┘
      │
      ▼
  ┌─────────┐
  │ second  │ ── returns false, {}
  └─────────┘
      │
      ▼
  Request dropped (handler never called)
```

## Complete Example

```lua
-- Loader.server.luau
local ServerScriptService = game:GetService("ServerScriptService")
local Types = require(ServerScriptService.e2en.Types)

local e2en: Types.e2enServer = require(ServerScriptService.e2en) :: any

-- Rate limiting state
local callHistory = {}

local function rateLimitMiddleware(player, serviceName, methodName, args)
    local key = tostring(player.UserId)
    local now = os.clock()

    callHistory[key] = callHistory[key] or {}
    local history = callHistory[key]

    -- Clean old entries
    for i = #history, 1, -1 do
        if now - history[i] > 1 then
            table.remove(history, i)
        end
    end

    -- Check limit
    if #history >= 30 then
        return false, {}
    end

    table.insert(history, now)
    return true, args
end

local function logMiddleware(player, serviceName, methodName, args)
    print(string.format(
        "[RPC] %s -> %s:%s (%d args)",
        player.Name,
        serviceName,
        methodName,
        #args
    ))
    return true, args
end

local function sanitizeMiddleware(player, serviceName, signalName, args)
    -- Remove internal fields before sending to clients
    local cleaned = {}
    for i, arg in args do
        if type(arg) == "table" then
            local copy = table.clone(arg)
            copy._internal = nil
            copy._debug = nil
            cleaned[i] = copy
        else
            cleaned[i] = arg
        end
    end
    return true, cleaned
end

e2en.Run({
    Middleware = {
        Inbound = {
            rateLimitMiddleware,
            logMiddleware,
        },
        Outbound = {
            sanitizeMiddleware,
        },
    }
})
```

## Best Practices

1. **Keep middleware fast** - It runs on every network call
2. **Return early** - Check failure conditions first
3. **Don't yield** - Middleware should be synchronous
4. **Clean up state** - For rate limiters, periodically remove old entries
5. **Log sparingly** - Excessive logging impacts performance
6. **Order matters** - Put validation before logging to avoid logging invalid requests
