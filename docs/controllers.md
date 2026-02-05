---
sidebar_position: 4
---

# Controllers

Controllers are client-side singletons that handle local game logic, UI, and player input. They communicate with Services to perform server-authoritative actions.

## Creating a Controller

```lua
local root = script.Parent.Parent.Parent
local Types = require(root.Types)

local e2en: Types.e2enClient = require(root) :: any

local InventoryController = e2en.CreateController({
    Name = "InventoryController",
})

function InventoryController:Init()
    -- Setup code
end

function InventoryController:Start()
    -- Runtime code
end

return InventoryController
```

## Controller Definition

| Field | Type | Description |
|-------|------|-------------|
| `Name` | `string` | **Required.** Unique identifier for the controller. |
| `Dependencies` | `{string}` | Controllers that must initialize before this one. |
| `Init` | `function` | Called synchronously during startup. |
| `Start` | `function` | Called asynchronously after all controllers initialize. |
| *custom* | `any` | Any other fields become part of the controller table. |

## Accessing Server Services

Use `GetService()` to get a proxy to a server Service:

```lua
function InventoryController:Start()
    local InventoryService = e2en.GetService("InventoryService")

    -- Call server methods
    local items = InventoryService:GetItems()

    -- Listen to server signals
    InventoryService.ItemAdded:Connect(function(item)
        self:OnItemAdded(item)
    end)

    -- Observe replicated properties
    InventoryService.InventorySize:Observe(function(size)
        self:UpdateInventoryUI(size)
    end)
end
```

## Accessing Other Controllers

```lua
function InventoryController:Start()
    local UIController = e2en.GetController("UIController")
    UIController:ShowInventory()
end
```

For `Init()` dependencies:

```lua
local InventoryController = e2en.CreateController({
    Name = "InventoryController",
    Dependencies = { "UIController" },
})

function InventoryController:Init()
    self._uiController = e2en.GetController("UIController")
end
```

## Working with UI

Controllers are the natural place for UI logic. e2en provides patterns for clean UI code.

### UI Reference Pattern

Initialize UI references at module scope using `WaitForChild`:

```lua
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local PlayerGui = player.PlayerGui

local root = script.Parent.Parent.Parent
local Types = require(root.Types)

local e2en: Types.e2enClient = require(root) :: any

local InventoryController = e2en.CreateController({ Name = "InventoryController" })

-- UI references at module scope
local InventoryGui              = PlayerGui:WaitForChild("Inventory") :: ScreenGui
local MainFrame                 = InventoryGui:WaitForChild("Main") :: Frame
local ItemsContainer            = MainFrame:WaitForChild("Items") :: ScrollingFrame
local CloseButton               = MainFrame:WaitForChild("Close") :: TextButton

function InventoryController:Init()
    -- Wire up events
    CloseButton.Activated:Connect(function()
        self:Hide()
    end)
end

function InventoryController:Show()
    InventoryGui.Enabled = true
end

function InventoryController:Hide()
    InventoryGui.Enabled = false
end

return InventoryController
```

### Why Module Scope?

Initializing UI at module scope instead of `Init()`:

1. **Fails fast** - Missing UI elements error immediately on require
2. **Clear dependencies** - All UI refs visible at top of file
3. **Type safety** - Cast types once, use everywhere
4. **No nil checks** - Guaranteed to exist after module loads

## Player Reference

Access the local player via `e2en.Player`:

```lua
function MyController:Start()
    local player = e2en.Player
    print("Local player:", player.Name)
end
```

## Character Access

Get the current character or respond to character events:

```lua
function MyController:Start()
    -- Get current character (may be nil)
    local character = e2en.GetCharacter()

    -- React to character spawns
    e2en.OnCharacterAdded(function(character, trove)
        local humanoid = character:WaitForChild("Humanoid")

        -- Auto-cleanup when character dies
        trove:Connect(humanoid.Died, function()
            self:OnDied()
        end)
    end)
end
```

## Input Handling

Controllers handle player input:

```lua
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local InputController = e2en.CreateController({ Name = "InputController" })

function InputController:Init()
    ContextActionService:BindAction(
        "OpenInventory",
        function(_, state)
            if state == Enum.UserInputState.Begin then
                local InventoryController = e2en.GetController("InventoryController")
                InventoryController:Toggle()
            end
        end,
        false,
        Enum.KeyCode.I
    )
end

return InputController
```

## Loading Controllers

### Automatic (Recommended)

The client automatically loads Controllers from `Systems/` folders:

```
Systems/
├── Combat/
│   └── Controller.luau  ← Loaded automatically
├── UI/
│   └── Controller.luau  ← Loaded automatically
```

### Manual Loading

```lua
-- Load direct children
e2en.AddControllers(someFolder)

-- Load all descendants
e2en.AddControllersDeep(someFolder)

-- Load Controller.luau from immediate child folders
e2en.AddSystems(someFolder)

-- Load Controller.luau from all descendant folders
e2en.AddSystemsDeep(someFolder)
```

## Example: Complete Controller

```lua
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local PlayerGui = player.PlayerGui

local root = script.Parent.Parent.Parent
local Types = require(root.Types)

local e2en: Types.e2enClient = require(root) :: any

local ShopController = e2en.CreateController({
    Name = "ShopController",
    Dependencies = { "NotificationController" },
})

-- UI references
local ShopGui               = PlayerGui:WaitForChild("Shop") :: ScreenGui
local MainFrame             = ShopGui:WaitForChild("Main") :: Frame
local ItemsContainer        = MainFrame:WaitForChild("Items") :: ScrollingFrame
local CloseButton           = MainFrame:WaitForChild("Close") :: TextButton
local CoinsLabel            = MainFrame:WaitForChild("Coins") :: TextLabel

-- Template
local ItemTemplate          = ItemsContainer:WaitForChild("Template") :: Frame

function ShopController:Init()
    self._notifications = e2en.GetController("NotificationController")
    self._shopService = nil -- Set in Start

    CloseButton.Activated:Connect(function()
        self:Hide()
    end)
end

function ShopController:Start()
    self._shopService = e2en.GetService("ShopService")

    -- Update coins display
    self._shopService.Coins:Observe(function(coins)
        CoinsLabel.Text = tostring(coins)
    end)

    -- Populate items
    self:PopulateItems()
end

function ShopController:PopulateItems()
    local items = self._shopService:GetItems()

    for _, item in items do
        local itemFrame = ItemTemplate:Clone()
        itemFrame.Name = item.id
        itemFrame.ItemName.Text = item.name
        itemFrame.Price.Text = tostring(item.price)
        itemFrame.Visible = true

        itemFrame.BuyButton.Activated:Connect(function()
            self:TryPurchase(item.id)
        end)

        itemFrame.Parent = ItemsContainer
    end
end

function ShopController:TryPurchase(itemId: string)
    local success = self._shopService:Purchase(itemId)

    if success then
        self._notifications:Show("Purchase successful!")
    else
        self._notifications:Show("Not enough coins!")
    end
end

function ShopController:Show()
    ShopGui.Enabled = true
end

function ShopController:Hide()
    ShopGui.Enabled = false
end

return ShopController
```
