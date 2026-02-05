---
sidebar_position: 8
---

# Utilities

e2en includes utility functions for common operations. Access them via `e2en.Util` or directly on `e2en`.

```lua
-- Both work
e2en.Util.ForEach(items, callback)
e2en.ForEach(items, callback)
```

## Iteration

### ForEach

Synchronous iteration over a table.

```lua
e2en.ForEach(players, function(player, index)
    print(index, player.Name)
end)

-- With performance tracking
e2en.ForEach(items, callback, "ProcessInventory")
```

### ForEachAsync

Spawns each callback in a separate thread.

```lua
e2en.ForEachAsync(players, function(player, index)
    -- Each runs in parallel
    loadPlayerData(player)
end)
```

### Map

Transform values into a new table.

```lua
local names = e2en.Map(players, function(player)
    return player.Name
end)
-- { "Player1", "Player2", ... }

local doubled = e2en.Map({ 1, 2, 3 }, function(n)
    return n * 2
end)
-- { 2, 4, 6 }
```

### Filter

Select values matching a predicate. Returns an array.

```lua
local adults = e2en.Filter(users, function(user)
    return user.age >= 18
end)

local positives = e2en.Filter({ -1, 2, -3, 4 }, function(n)
    return n > 0
end)
-- { 2, 4 }
```

### Find

Get the first value matching a predicate.

```lua
local admin = e2en.Find(players, function(player)
    return player:GetAttribute("IsAdmin")
end)

if admin then
    print("Found admin:", admin.Name)
end
```

### Reduce

Aggregate values into a single result.

```lua
local total = e2en.Reduce(prices, function(sum, price)
    return sum + price
end, 0)

local concatenated = e2en.Reduce(words, function(result, word)
    return result .. " " .. word
end, "")
```

### Every

Check if all values match a predicate.

```lua
local allReady = e2en.Every(players, function(player)
    return player:GetAttribute("Ready")
end)

if allReady then
    startGame()
end
```

### Some

Check if any value matches a predicate.

```lua
local hasEnemy = e2en.Some(entities, function(entity)
    return entity.Type == "Enemy"
end)
```

## Table Operations

### Reverse

Reverse array order.

```lua
local reversed = e2en.Reverse({ 1, 2, 3 })
-- { 3, 2, 1 }
```

### Shuffle

Randomize array order.

```lua
local shuffled = e2en.Shuffle({ 1, 2, 3, 4, 5 })
-- Random order each time
```

### Copy

Clone a table (shallow or deep).

```lua
local shallow = e2en.Copy(original)
local deep = e2en.Copy(original, true)
```

### Keys

Get all keys from a table.

```lua
local keys = e2en.Keys({ a = 1, b = 2, c = 3 })
-- { "a", "b", "c" }
```

### Values

Get all values from a table.

```lua
local values = e2en.Values({ a = 1, b = 2, c = 3 })
-- { 1, 2, 3 }
```

### Count

Count entries in a table (works for dictionaries).

```lua
local count = e2en.Count({ a = 1, b = 2, c = 3 })
-- 3
```

### Flat

Flatten nested arrays.

```lua
local flat = e2en.Flat({ { 1, 2 }, { 3, { 4 } } })
-- { 1, 2, 3, { 4 } }

local deepFlat = e2en.Flat({ { 1, { 2, { 3 } } } }, 2)
-- { 1, 2, { 3 } }
```

## Timing

### Step

Run a function every frame.

```lua
-- Heartbeat (server and client)
local connection = e2en.Step("UpdatePositions", function(dt)
    updateAllPositions(dt)
end)

-- RenderStepped (client only)
local connection = e2en.Step("UpdateCamera", function(dt)
    updateCamera(dt)
end, true)
```

### StopStep

Stop a running step.

```lua
e2en.StopStep("UpdatePositions")
```

### GetActiveSteps

Get names of all running steps.

```lua
local steps = e2en.GetActiveSteps()
-- { "UpdatePositions", "UpdateCamera" }
```

### Defer

Run next frame.

```lua
e2en.Defer(function()
    print("Runs next frame")
end)

-- With arguments
e2en.Defer(function(a, b)
    print(a + b)
end, 1, 2)
```

### Delay

Run after a duration.

```lua
e2en.Delay(2, function()
    print("2 seconds later")
end)

-- With arguments
e2en.Delay(1, function(message)
    print(message)
end, "Hello!")
```

### WaitFor

Poll until a condition is met.

```lua
local target = e2en.WaitFor(function()
    return workspace:FindFirstChild("Target")
end, 10, 0.1)  -- timeout, interval

if target then
    print("Found target!")
else
    print("Timed out")
end
```

## Performance Tracking

Track execution time of utility functions.

### Enable Tracking

```lua
e2en.EnablePerformanceTracking(true)
```

### Automatic Tracking

All iteration functions support a tracking name:

```lua
e2en.ForEach(items, callback, "ProcessItems")
e2en.Map(data, transform, "TransformData")
```

Steps are automatically tracked:

```lua
e2en.Step("GameLoop", function(dt)
    -- Tracked as "Step:GameLoop"
end)
```

### Get Performance Data

```lua
local data = e2en.GetPerformanceData()

--[[
{
    ["ProcessItems"] = {
        calls = 100,
        totalTime = 0.5,
        avgTime = 0.005,
        peakTime = 0.02,
        lastCall = 12345.67,
    },
    ["Step:GameLoop"] = { ... },
}
]]
```

### Print Report

```lua
e2en.PrintPerformanceReport()

-- Output:
-- === Performance Report ===
-- [Step:GameLoop] calls: 1000 | total: 50.0000ms | avg: 0.0500ms | peak: 0.2000ms
-- [ProcessItems] calls: 100 | total: 5.0000ms | avg: 0.0500ms | peak: 0.1000ms
-- ==========================
```

### Clear Data

```lua
e2en.ClearPerformanceData()
```

### Estimate Memory Usage

```lua
local bytes = e2en.EstimateMemoryUsage(someTable)
print("Estimated size:", bytes, "bytes")
```

## Practical Examples

### Filtering Active Players

```lua
local activePlayers = e2en.Filter(Players:GetPlayers(), function(player)
    return player.Character and player.Character:FindFirstChild("Humanoid")
end)
```

### Calculating Total Score

```lua
local totalScore = e2en.Reduce(players, function(total, player)
    return total + (playerScores[player] or 0)
end, 0)
```

### Finding Nearest Enemy

```lua
local nearest = e2en.Reduce(enemies, function(closest, enemy)
    local distance = (enemy.Position - myPosition).Magnitude
    if not closest or distance < closest.distance then
        return { enemy = enemy, distance = distance }
    end
    return closest
end, nil)

if nearest then
    print("Nearest enemy:", nearest.enemy.Name)
end
```

### Spawning Items with Delay

```lua
e2en.ForEach(spawnPoints, function(point, index)
    e2en.Delay(index * 0.5, function()
        spawnItemAt(point.Position)
    end)
end)
```

### Polling for Game State

```lua
local gameStarted = e2en.WaitFor(function()
    local GameService = e2en.GetService("GameService")
    local phase = GameService.GamePhase:Get()
    return phase == "Playing" and true or nil
end, 60)

if gameStarted then
    print("Game started!")
else
    print("Timed out waiting for game")
end
```
