---
sidebar_position: 7
---

# Components

Components bind Luau classes to Roblox instances via CollectionService tags. When an instance gains a tag, a component is created. When the tag is removed or the instance is destroyed, the component cleans up automatically.

## Creating a Component

```lua
local root = script.Parent.Parent.Parent
local Component = require(root.Libraries.Component)

local Lava = Component.new({
    Tag = "Lava",
    Ancestors = { workspace },  -- Optional: only track in workspace
})

-- Define properties on the prototype
Lava._prototype.Damage = 10
Lava._prototype.DamageInterval = 0.5

-- Lifecycle methods
function Lava._prototype:Construct()
    -- Called when component is created
    print("Lava created on", self.Instance.Name)
end

function Lava._prototype:Start()
    -- Called after Construct, safe to interact with other components
    self._lastDamageTime = {}

    self._trove:Connect(self.Instance.Touched, function(hit)
        self:OnTouched(hit)
    end)
end

function Lava._prototype:Stop()
    -- Called before cleanup
    print("Lava removed from", self.Instance.Name)
end

-- Custom methods
function Lava._prototype:OnTouched(hit: BasePart)
    local character = hit.Parent
    local humanoid = character and character:FindFirstChild("Humanoid") :: Humanoid?

    if humanoid and humanoid.Health > 0 then
        local now = os.clock()
        local lastDamage = self._lastDamageTime[character] or 0

        if now - lastDamage >= self.DamageInterval then
            humanoid:TakeDamage(self.Damage)
            self._lastDamageTime[character] = now
        end
    end
end

-- Start tracking tagged instances
Lava:Start()

return Lava
```

## Component Lifecycle

```
Instance tagged with "Lava"
         │
         ▼
┌─────────────────┐
│   Construct()   │  Component instance created
└─────────────────┘
         │
         ▼
┌─────────────────┐
│     Start()     │  Safe to interact with world
└─────────────────┘
         │
         │  (component active...)
         │
         ▼
┌─────────────────┐
│     Stop()      │  Cleanup begins
└─────────────────┘
         │
         ▼
   _trove:Clean()    Automatic cleanup
         │
         ▼
  Component destroyed
```

## Configuration

```lua
local MyComponent = Component.new({
    Tag = "MyTag",           -- Required: CollectionService tag
    Ancestors = { workspace, ReplicatedStorage },  -- Optional: only track in these
})
```

If `Ancestors` is not specified, all tagged instances are tracked regardless of location.

## The Prototype

Define properties and methods on `_prototype`:

```lua
-- Properties (copied to each instance)
MyComponent._prototype.Speed = 10
MyComponent._prototype.MaxHealth = 100

-- Methods (shared via metatable)
function MyComponent._prototype:TakeDamage(amount)
    self.Health = math.max(0, self.Health - amount)
end
```

## Built-in Properties

Every component instance has:

| Property | Type | Description |
|----------|------|-------------|
| `Instance` | `Instance` | The tagged Roblox instance |
| `_trove` | `Trove` | Auto-cleans when component is destroyed |

## Update Loops

Components can opt into per-frame updates:

```lua
-- Called every Heartbeat
function MyComponent._prototype:HeartbeatUpdate(dt: number)
    self.Instance.CFrame *= CFrame.Angles(0, dt, 0)
end

-- Called every RenderStepped (client only)
function MyComponent._prototype:RenderSteppedUpdate(dt: number)
    -- Client-side rendering logic
end
```

Update methods are only connected if they're defined on the prototype.

## Accessing Components

### Get Component from Instance

```lua
local lavaComponent = Lava:FromInstance(somePart)

if lavaComponent then
    print("Damage:", lavaComponent.Damage)
    lavaComponent.Damage = 20  -- Modify this instance
end
```

### Get All Active Components

```lua
local allLava = Lava:GetAll()

for _, component in allLava do
    print(component.Instance.Name, "deals", component.Damage, "damage")
end
```

### Wait for Component

```lua
-- Yields until component exists (with timeout)
local component = Lava:WaitForInstance(somePart, 5)

if component then
    print("Found!")
else
    print("Timed out")
end
```

## Component Signals

React to components being added or removed:

```lua
Lava.ComponentAdded:Connect(function(component)
    print("New lava on", component.Instance.Name)
end)

Lava.ComponentRemoving:Connect(function(component)
    print("Lava being removed from", component.Instance.Name)
end)
```

## Using Trove

Each component has a `_trove` that auto-cleans when destroyed:

```lua
function MyComponent._prototype:Start()
    -- Connections auto-disconnect
    self._trove:Connect(self.Instance.Touched, function(hit)
        self:OnTouched(hit)
    end)

    -- Instances auto-destroy
    local highlight = Instance.new("Highlight")
    self._trove:Add(highlight)
    highlight.Parent = self.Instance

    -- Custom cleanup
    local resource = createResource()
    self._trove:Add(resource, "Release")
end
```

## Destroying Components

### Remove Tag

```lua
-- Component is destroyed when tag is removed
local CollectionService = game:GetService("CollectionService")
CollectionService:RemoveTag(part, "Lava")
```

### Destroy Instance

```lua
-- Component is destroyed when instance is destroyed
part:Destroy()
```

### Destroy Component Class

```lua
-- Stops tracking and destroys all instances
Lava:Destroy()
```

## Example: Collectible

```lua
local Component = require(root.Libraries.Component)

local Collectible = Component.new({
    Tag = "Collectible",
    Ancestors = { workspace },
})

Collectible._prototype.Value = 10
Collectible._prototype.RespawnTime = 30

function Collectible._prototype:Construct()
    self._originalCFrame = self.Instance.CFrame
    self._collected = false
end

function Collectible._prototype:Start()
    self._trove:Connect(self.Instance.Touched, function(hit)
        self:OnTouched(hit)
    end)
end

function Collectible._prototype:HeartbeatUpdate(dt: number)
    if not self._collected then
        -- Spin and bob
        local time = os.clock()
        self.Instance.CFrame = self._originalCFrame
            * CFrame.Angles(0, time * 2, 0)
            * CFrame.new(0, math.sin(time * 3) * 0.5, 0)
    end
end

function Collectible._prototype:OnTouched(hit: BasePart)
    if self._collected then return end

    local player = game.Players:GetPlayerFromCharacter(hit.Parent)
    if not player then return end

    self._collected = true
    self.Instance.Transparency = 1

    -- Award points (via service)
    local PointsService = e2en.GetService("PointsService")
    PointsService:AddPoints(player, self.Value)

    -- Respawn after delay
    task.delay(self.RespawnTime, function()
        if self.Instance and self.Instance.Parent then
            self._collected = false
            self.Instance.Transparency = 0
        end
    end)
end

Collectible:Start()

return Collectible
```

## Best Practices

1. **Keep components focused** - One responsibility per component
2. **Use Trove** - Always clean up via `_trove`, not manual tracking
3. **Validate Instance** - Check `self.Instance` still exists in delayed callbacks
4. **Ancestors filter** - Use `Ancestors` to avoid tracking instances in unexpected places
5. **HeartbeatUpdate for logic** - Use `RenderSteppedUpdate` only for visual client-side updates
