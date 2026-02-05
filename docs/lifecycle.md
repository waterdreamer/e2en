---
sidebar_position: 6
---

# Lifecycle

e2en provides hooks for player and character lifecycle events with automatic cleanup through Troves.

## Server Lifecycle

### Player Added

Called when a player joins. Also fires retroactively for players already in the game.

```lua
e2en.OnPlayerAdded(function(player: Player, trove: Trove)
    print(player.Name, "joined")

    -- Load their data
    local data = loadData(player)

    -- Add things to the trove for auto-cleanup
    trove:Add(createPlayerState(player))

    trove:Connect(player.Chatted, function(message)
        print(player.Name, "said:", message)
    end)
end)
```

The `trove` automatically cleans up when the player leaves, so no manual disconnection is needed.

### Player Removing

Called when a player is about to leave. Use this for saving data.

```lua
e2en.OnPlayerRemoving(function(player: Player)
    print(player.Name, "leaving")
    saveData(player)
end)
```

### Character Added

Called when a character spawns. Also fires retroactively for existing characters.

```lua
e2en.OnCharacterAdded(function(player: Player, character: Model, trove: Trove)
    print(player.Name, "spawned")

    local humanoid = character:WaitForChild("Humanoid") :: Humanoid

    -- Auto-cleanup when character dies/respawns
    trove:Connect(humanoid.Died, function()
        print(player.Name, "died")
    end)

    trove:Connect(humanoid.Running, function(speed)
        if speed > 0 then
            print(player.Name, "is running")
        end
    end)
end)
```

### Character Removing

Called when a character is about to be removed.

```lua
e2en.OnCharacterRemoving(function(player: Player, character: Model)
    print(player.Name, "character removing")
end)
```

### Getting Troves Manually

```lua
local playerTrove = e2en.GetPlayerTrove(player)
local characterTrove = e2en.GetCharacterTrove(player)

if playerTrove then
    playerTrove:Add(someCleanupTarget)
end
```

## Client Lifecycle

### Character Added

```lua
e2en.OnCharacterAdded(function(character: Model, trove: Trove)
    print("Spawned")

    local humanoid = character:WaitForChild("Humanoid") :: Humanoid

    trove:Connect(humanoid.Died, function()
        print("Died")
    end)

    trove:Connect(humanoid.HealthChanged, function(health)
        updateHealthBar(health)
    end)
end)
```

### Character Removing

```lua
e2en.OnCharacterRemoving(function(character: Model)
    print("Character removing")
end)
```

### Getting Current Character

```lua
-- Returns nil if no character exists
local character = e2en.GetCharacter()

-- Get the character's trove (nil if no character)
local trove = e2en.GetCharacterTrove()
```

### Player Reference

```lua
local player = e2en.Player
print("I am", player.Name)
```

## The Trove Pattern

Troves manage cleanup automatically. When a trove is cleaned (player leaves, character dies), everything added to it is destroyed/disconnected.

### Adding Objects

```lua
e2en.OnPlayerAdded(function(player, trove)
    -- Instances are destroyed
    local folder = Instance.new("Folder")
    folder.Name = player.Name
    trove:Add(folder)
    folder.Parent = workspace

    -- Connections are disconnected
    trove:Connect(player.Chatted, function(msg)
        print(msg)
    end)

    -- Tables with Destroy method
    local state = { Destroy = function() print("cleaned up") end }
    trove:Add(state)

    -- Custom cleanup method
    local resource = createResource()
    trove:Add(resource, "Release") -- calls resource:Release()
end)
```

### Nested Troves

Create sub-troves for grouped cleanup:

```lua
e2en.OnCharacterAdded(function(player, character, trove)
    -- Combat-related stuff
    local combatTrove = Trove.new()
    trove:Add(combatTrove)

    combatTrove:Connect(...)
    combatTrove:Add(...)

    -- Clear combat stuff without clearing everything
    combatTrove:Clean()
end)
```

## Lifecycle Timing

![Server Timeline](/server-timeline.svg)

## Common Patterns

### Per-Player State

```lua
local playerStates = {}

e2en.OnPlayerAdded(function(player, trove)
    playerStates[player] = {
        score = 0,
        inventory = {},
    }
end)

e2en.OnPlayerRemoving(function(player)
    playerStates[player] = nil
end)
```

### Character Components

```lua
e2en.OnCharacterAdded(function(player, character, trove)
    -- Add a highlight that auto-removes on death
    local highlight = Instance.new("Highlight")
    highlight.FillColor = Color3.new(1, 0, 0)
    trove:Add(highlight)
    highlight.Parent = character

    -- Track running state
    local humanoid = character:WaitForChild("Humanoid") :: Humanoid
    local isRunning = false

    trove:Connect(humanoid.Running, function(speed)
        isRunning = speed > 0
    end)
end)
```

### Waiting for Character

```lua
function MyService:DoSomethingWithCharacter(player: Player)
    local character = player.Character
    if not character then
        character = player.CharacterAdded:Wait()
    end
    -- Now we have a character
end
```

### Client: Waiting for Server

```lua
function MyController:Start()
    -- Wait for framework to be fully ready
    e2en.OnStart()

    -- Now safe to access services
    local GameService = e2en.GetService("GameService")
end
```
