# Feature Implementation Guide

Guidelines for implementing new features in BetterLootMarkers. Each section is self-contained and can be implemented independently.

## Architecture Overview

Before implementing any feature, understand the mod's architecture:

- **`init.lua`** — Entry point. Hooks into `GameplayMappinController` via `ObserveAfter`. The main handler `_HandleLootMarkers` runs every time a loot mappin updates visibility or icon. It fetches item data from the game, categorizes items, and builds an ink widget tree to display custom icons.
- **`Modules/Settings.lua`** — Config UI (ImGui) and persistence (JSON file). Settings are applied live. File writes happen on CET overlay close via a `_dirty` flag.
- **`Modules/Types.lua`** — Static data: item type → category mappings, icon IDs, quality tiers, and quality colors. The `TypeToCategoryByString` lookup table is built at load time from `Categories`.
- **`Modules/Utils.lua`** — Pure utility functions with no game dependencies.

### Key Patterns

1. **Settings pattern**: Add field with default to the `Settings` table → add ImGui control in `onDraw` → include field in `Save()` and `Load()` with type validation.
2. **Config persistence**: All settings are saved as a flat JSON object. Use `type()` checks in `Load()` and clamp numeric values to valid ranges.
3. **Category names**: Every category in `Types.Categories` has a matching key in `Types.ItemIcons`, `Types.Colors` (via quality), and `Types.Qualities`. When filtering or toggling categories, always use these string keys: `Guns`, `Melee_Blunt`, `Melee_Blade`, `Vehicle_Weapon`, `Clothes`, `Cyberware`, `Consumable`, `Medical`, `Skillbook`, `Crafting`, `CraftingSpec`, `Grenade`, `Attachments`, `Hacking`, `Ammo`, `Junk`, `Readable`, `Money`, `Broken`, `Default`.
4. **Enum-as-key hazard**: Never use `gamedataItemType` enum values as Lua table keys. CET wraps them as userdata; Lua uses raw pointer identity for table lookup, not the `__eq` metamethod. Always convert with `tostring()` first.
5. **Ink widget tree**: The handler builds `containerPanel > BetterLootMarkersContainer (inkHorizontalPanel/inkVerticalPanel) > inkImage (per category)`. All custom widgets are children of the panel named `"BetterLootMarkersContainer"`.
6. **Error resilience**: The public handler wraps the implementation in `pcall`. Any new code inside `_HandleLootMarkers` is automatically protected. If you add new functions called from outside the handler, wrap them similarly.

### Testing Checklist (for all features)

- [ ] Load a save in a loot-dense area (e.g., any NCPD scanner hustle aftermath)
- [ ] Verify markers display correctly with default settings
- [ ] Change the new setting in the CET overlay, verify markers update
- [ ] Close and reopen the CET overlay — verify the setting persists visually
- [ ] Quit to main menu and reload — verify config.json has the new setting
- [ ] Delete config.json and reload — verify the mod uses defaults without crashing
- [ ] Set the new setting to extreme/edge values and verify no crashes

---

## Feature 1: Per-Category Visibility Toggles

**Impact**: High | **Effort**: Medium | **Files**: `Settings.lua`, `init.lua`

Let users hide specific loot categories from markers (e.g., hide Ammo, Junk).

### Settings.lua Changes

1. Add a `hiddenCategories` table to the `Settings` table:

```lua
local Settings = {
    showDefaultMappin = false,
    verticalMode = false,
    markerScaling = 1.0,
    hiddenCategories = {},
    -- ...
}
```

2. In the `onDraw` callback, after the existing controls, add a collapsible section with checkboxes. Use `ImGui.CollapsingHeader` for clean grouping:

```lua
if ImGui.CollapsingHeader("Category Visibility") then
    local allCategories = {
        "Guns", "Melee_Blunt", "Melee_Blade", "Vehicle_Weapon",
        "Clothes", "Cyberware", "Consumable", "Medical",
        "Skillbook", "Crafting", "CraftingSpec", "Grenade",
        "Attachments", "Hacking", "Ammo", "Junk", "Readable",
        "Money", "Broken"
    }
    for _, cat in ipairs(allCategories) do
        local visible = not Settings.hiddenCategories[cat]
        local newVisible, toggled = ImGui.Checkbox(cat, visible)
        if toggled then
            Settings.hiddenCategories[cat] = (not newVisible) or nil
            Settings._dirty = true
        end
    end
end
```

The `or nil` trick means unchecked = `true` in the table, checked = `nil` (absent). This keeps the saved JSON clean — only hidden categories are stored.

3. Add `hiddenCategories` to `Save()`:

```lua
local settings = {
    verticalMode = Settings.verticalMode,
    showDefaultMappin = Settings.showDefaultMappin,
    markerScaling = Settings.markerScaling,
    hiddenCategories = Settings.hiddenCategories
}
```

4. Add `hiddenCategories` to `Load()` with validation:

```lua
if type(decoded["hiddenCategories"]) == "table" then
    Settings.hiddenCategories = {}
    for k, v in pairs(decoded["hiddenCategories"]) do
        if type(k) == "string" and v == true then
            Settings.hiddenCategories[k] = true
        end
    end
end
```

### init.lua Changes

In `_HandleLootMarkers`, after building the `categories` table from `ResolveHighestQualityByCategory` and before the render loop, filter out hidden categories:

```lua
local categories = BetterLootMarkers.ResolveHighestQualityByCategory(itemList)

for cat, _ in pairs(categories) do
    if BetterLootMarkers.Settings.hiddenCategories[cat] then
        categories[cat] = nil
    end
end

-- If all categories were filtered out, clean up and return
local hasAny = false
for _ in pairs(categories) do hasAny = true; break end
if not hasAny then
    containerPanel:RemoveChildByName(CONTAINER_CNAME)
    return
end

BetterLootMarkers.HandleShowHideOriginalIcon(ctrl, iconWidget)
-- ... rest of rendering ...
```

### Edge Cases

- If ALL categories are hidden, remove the custom container and show the vanilla icon.
- `"Default"` category catches unmapped item types. Include it in the toggle list or always show it.
- `"CraftingSpec"` and `"Broken"` are resolved by tag/state checks before the type lookup, so they must be in the toggle list separately from `"Crafting"`.

---

## Feature 2: Minimum Quality Filter

**Impact**: High | **Effort**: Easy | **Files**: `Settings.lua`, `init.lua`

Hide items below a configurable quality threshold. Late-game players only want to see Rare+ loot.

### Settings.lua Changes

1. Add `minQuality` to the Settings table (default `"Common"` = show everything):

```lua
local Settings = {
    -- ...
    minQuality = "Common",
    -- ...
}
```

2. In `onDraw`, add a combo dropdown after the existing controls:

```lua
local qualityNames = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
local currentIndex = 0
for i, name in ipairs(qualityNames) do
    if name == Settings.minQuality then currentIndex = i - 1 end
end

local newIndex
newIndex, toggled = ImGui.Combo("Min Quality", currentIndex, qualityNames, #qualityNames)
if toggled then
    Settings.minQuality = qualityNames[newIndex + 1]
    Settings._dirty = true
end
```

3. Add to `Save()` and `Load()`:

```lua
-- Save: include minQuality in the settings table

-- Load:
if type(decoded["minQuality"]) == "string" then
    local valid = { Common=true, Uncommon=true, Rare=true, Epic=true, Legendary=true }
    if valid[decoded["minQuality"]] then
        Settings.minQuality = decoded["minQuality"]
    end
end
```

### init.lua Changes

Modify `ResolveHighestQualityByCategory` to skip items below the threshold. The quality threshold uses the `Qualities` score from `Types.lua` (Common=0, Uncommon=1, Rare=2, Epic=3, Legendary=4, Iconic=5):

```lua
function BetterLootMarkers.ResolveHighestQualityByCategory(itemList)
    local minScore = BetterLootMarkers.ItemTypes.Qualities[BetterLootMarkers.Settings.minQuality] or 0
    local categories = {}
    for _, item in ipairs(itemList) do
        local quality = RPGManager.GetItemDataQuality(item)
        local isIconic = RPGManager.IsItemIconic(item)

        -- Iconic items always pass the filter
        local qualityScore = BetterLootMarkers.ItemTypes.Qualities[quality.value] or 0
        if not isIconic and qualityScore < minScore then
            goto continue
        end

        local category = BetterLootMarkers.GetLootCategoryForItem(item)
        local newItem = {
            quality = quality,
            isIconic = isIconic,
        }
        if categories[category] == nil then
            categories[category] = newItem
        else
            local currentScore = BetterLootMarkers.GetItemScore(categories[category])
            local newScore = BetterLootMarkers.GetItemScore(newItem)
            if newScore > currentScore then
                categories[category] = newItem
            end
        end

        ::continue::
    end
    return categories
end
```

Note: Lua 5.1 (CET's runtime) does NOT support `goto`/labels. Use a helper function or restructure with `if/then` instead:

```lua
local function passesFilter(quality, isIconic, minScore)
    if isIconic then return true end
    local score = BetterLootMarkers.ItemTypes.Qualities[quality.value] or 0
    return score >= minScore
end
```

Then wrap the loop body: `if passesFilter(quality, isIconic, minScore) then ... end`.

### Edge Cases

- Iconic items should ALWAYS pass the quality filter regardless of their base quality.
- Money, Ammo, Junk, and Crafting materials have quality = Common. If the user sets min quality to Rare, these categories disappear. This is the desired behavior.
- If all items are filtered out, the `#itemList == 0` check won't catch it (the list isn't empty, just all items were skipped). Handle empty `categories` table after `ResolveHighestQualityByCategory` the same way as Feature 1 above.

---

## Feature 3: Iconic Item Highlight

**Impact**: Medium | **Effort**: Easy | **Files**: `init.lua`

Make containers holding iconic items visually distinct with a larger scale multiplier.

### init.lua Changes

In the render loop inside `_HandleLootMarkers`, after calling `Utils.sortedCategoryPairs`, check if the current category is iconic and apply a scale boost:

```lua
for categoryKey, category in Utils.sortedCategoryPairs(categories, BetterLootMarkers.ItemTypes.Qualities) do
    local colorIndex = category.isIconic and "Iconic" or category.quality.value
    local color = HDRColor.new(BetterLootMarkers.ItemTypes.Colors[colorIndex])
    local scale = BetterLootMarkers.Settings.markerScaling
    if category.isIconic then
        scale = math.min(1.0, scale * 1.35)
    end
    BetterLootMarkers.AddIconToWidget(container, "BetterLootMappin-" .. categoryKey,
        BetterLootMarkers.ItemTypes.ItemIcons[categoryKey], color, colorIndex, scale)
end
```

Update `AddIconToWidget` to accept an optional `scale` parameter:

```lua
function BetterLootMarkers.AddIconToWidget(parent, name, iconId, color, value, scale)
    -- ...
    local finalScale = scale or BetterLootMarkers.Settings.markerScaling
    icon:SetScale(Vector2.new({
        X = finalScale,
        Y = finalScale
    }))
    -- ...
end
```

### Optional Enhancement: Pulsing Animation

For a more dramatic effect, add an ink animation to iconic icons. This uses CET's ink animation API:

```lua
if category.isIconic then
    local animDef = inkAnimDef.new()
    local scaleInterp = inkAnimScale.new()
    scaleInterp:SetStartScale(Vector2.new({ X = finalScale, Y = finalScale }))
    scaleInterp:SetEndScale(Vector2.new({ X = finalScale * 1.15, Y = finalScale * 1.15 }))
    scaleInterp:SetDuration(0.6)
    scaleInterp:SetType(inkanimInterpolationType.Linear)
    scaleInterp:SetMode(inkanimInterpolationMode.EasyInOut)
    animDef:AddInterpolator(scaleInterp)
    icon:PlayAnimationWithOptions(animDef, inkAnimOptions.new({ loopType = inkanimLoopType.PingPong, loopCounter = 0 }))
end
```

**Warning**: The animation API names may differ between CET versions. Verify against CET's current Lua API dump before implementing. The above is based on the RED4 ink animation system. If the API isn't available, fall back to the static scale boost.

---

## Feature 4: Container Item Count Badge

**Impact**: Medium | **Effort**: Medium | **Files**: `init.lua`

Show a small number next to each category icon indicating how many items of that type are inside.

### init.lua Changes

1. Modify `ResolveHighestQualityByCategory` to also track counts:

```lua
function BetterLootMarkers.ResolveHighestQualityByCategory(itemList)
    local categories = {}
    for _, item in ipairs(itemList) do
        local quality = RPGManager.GetItemDataQuality(item)
        local category = BetterLootMarkers.GetLootCategoryForItem(item)
        local newItem = {
            quality = quality,
            isIconic = RPGManager.IsItemIconic(item),
        }
        if categories[category] == nil then
            categories[category] = newItem
            categories[category].count = 1
        else
            categories[category].count = categories[category].count + 1
            local currentScore = BetterLootMarkers.GetItemScore(categories[category])
            local newScore = BetterLootMarkers.GetItemScore(newItem)
            if newScore > currentScore then
                local count = categories[category].count
                categories[category] = newItem
                categories[category].count = count
            end
        end
    end
    return categories
end
```

2. Create a new function to add a text label:

```lua
function BetterLootMarkers.AddCountBadge(parent, name, count, color)
    if count <= 1 then return end
    local text = inkText.new()
    text:SetName(CName.new(name))
    text:SetText(tostring(count))
    text:SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily")
    text:SetFontSize(16)
    text:SetTintColor(color)
    text:SetAnchor(inkEAnchor.TopRight)
    text:SetMargin(inkMargin.new({ top = -5.0, right = 0.0, bottom = 0.0, left = -8.0 }))
    text:SetVisible(true)
    text:SetFitToContent(true)
    parent:AddChildWidget(text)
end
```

3. In the render loop, after each `AddIconToWidget` call, add the badge:

```lua
for categoryKey, category in Utils.sortedCategoryPairs(categories, BetterLootMarkers.ItemTypes.Qualities) do
    local colorIndex = category.isIconic and "Iconic" or category.quality.value
    local color = HDRColor.new(BetterLootMarkers.ItemTypes.Colors[colorIndex])
    BetterLootMarkers.AddIconToWidget(container, "BetterLootMappin-" .. categoryKey,
        BetterLootMarkers.ItemTypes.ItemIcons[categoryKey], color, colorIndex)
    BetterLootMarkers.AddCountBadge(container, "BetterLootCount-" .. categoryKey,
        category.count, color)
end
```

### Notes

- The font family path `"base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily"` is the game's default UI font. You can find other fonts by searching the game's archive files.
- `inkText` might require `SetLetterCase` or `SetWrappingAtPosition` depending on CET version.
- Margin values will need tuning to position the count badge correctly relative to the icon. Test with both horizontal and vertical layout modes.
- Consider adding a setting `showItemCounts` (boolean) to let users toggle this off.

---

## Feature 5: Empty-After-Loot Fade Out

**Impact**: Low | **Effort**: Easy | **Files**: `init.lua`

Instead of instantly removing the custom container when a loot pile becomes empty, fade it out.

### init.lua Changes

Replace the instant removal in the empty-item-list branch with a fade animation:

```lua
if #itemList == 0 then
    -- Try to fade out existing container before removing
    local existing = containerPanel:GetWidgetByPathName(CONTAINER_CNAME)
    if existing ~= nil and existing:GetOpacity() > 0.0 then
        local animDef = inkAnimDef.new()
        local alphaInterp = inkAnimTransparency.new()
        alphaInterp:SetStartTransparency(1.0)
        alphaInterp:SetEndTransparency(0.0)
        alphaInterp:SetDuration(0.3)
        animDef:AddInterpolator(alphaInterp)
        existing:PlayAnimation(animDef)
    else
        containerPanel:RemoveChildByName(CONTAINER_CNAME)
    end
    return
end
```

### Important Caveats

- `GetWidgetByPathName` may not exist in all CET versions. If it doesn't, use `GetWidget` with an `inkWidgetPath`, or fall back to instant removal.
- The animation plays asynchronously. The widget won't be removed after the animation finishes unless you register a callback. The next `UpdateVisibility` call will see `#itemList == 0` again and either restart the animation (if opacity > 0 still) or remove the widget (if opacity reached 0). This creates a natural cleanup loop.
- If the ink animation API is not accessible from CET Lua, skip this feature entirely. It's a polish item.
- Test thoroughly: make sure the fade doesn't cause stale ghost markers that never disappear.

---

## Feature 6: Custom Quality Colors

**Impact**: Medium | **Effort**: Medium | **Files**: `Settings.lua`, `Types.lua`, `init.lua`

Let users customize the color for each quality tier.

### Settings.lua Changes

1. Add `customColors` to Settings. Default to `nil` (use built-in colors):

```lua
local Settings = {
    -- ...
    customColors = nil,
    -- ...
}
```

2. In `onDraw`, add color pickers inside a collapsing header:

```lua
if ImGui.CollapsingHeader("Quality Colors") then
    local qualities = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Iconic" }
    if Settings.customColors == nil then
        Settings.customColors = {}
    end
    for _, quality in ipairs(qualities) do
        local defaults = BetterLootMarkers.ItemTypes.Colors[quality]
        local c = Settings.customColors[quality] or defaults
        local r, g, b, a, changed = ImGui.ColorEdit4(
            quality, c.Red, c.Green, c.Blue, c.Alpha or 1.0
        )
        if changed then
            Settings.customColors[quality] = { Red = r, Green = g, Blue = b, Alpha = a }
            Settings._dirty = true
        end
    end

    if ImGui.Button("Reset to Defaults") then
        Settings.customColors = nil
        Settings._dirty = true
    end
end
```

**Note**: CET's ImGui bindings for `ColorEdit4` may return values differently. Check CET's ImGui API. The return pattern might be `r, g, b, a, changed` or `changed` as first return. Test this.

3. Add to `Save()` and `Load()` with validation.

### init.lua Changes

When resolving colors in `_HandleLootMarkers`, check custom colors first:

```lua
local function resolveColor(colorIndex)
    local custom = BetterLootMarkers.Settings.customColors
    if custom ~= nil and custom[colorIndex] ~= nil then
        return HDRColor.new(custom[colorIndex])
    end
    return HDRColor.new(BetterLootMarkers.ItemTypes.Colors[colorIndex])
end
```

Replace `HDRColor.new(BetterLootMarkers.ItemTypes.Colors[colorIndex])` in the render loop with `resolveColor(colorIndex)`.

### Edge Cases

- HDRColor uses values > 1.0 for HDR bloom effects. ImGui's ColorEdit4 typically works in 0.0-1.0 range. You may need to add an "HDR Intensity" slider per color, or use `ImGuiColorEditFlags_Float` and `ImGuiColorEditFlags_HDR` flags if CET supports them.
- If `customColors` is `nil`, fall through to defaults everywhere. Never let `nil` propagate to `HDRColor.new()`.

---

## Feature 7: Separate Scaling per Category

**Impact**: Low | **Effort**: Medium | **Files**: `Settings.lua`, `init.lua`

Allow different icon scales per category (e.g., weapons large, ammo small).

### Settings.lua Changes

1. Add `categoryScaling` table (defaults to empty = use global scale):

```lua
local Settings = {
    -- ...
    categoryScaling = {},
    -- ...
}
```

2. In `onDraw`, add per-category sliders inside a collapsing header:

```lua
if ImGui.CollapsingHeader("Category Scaling") then
    local allCategories = {
        "Guns", "Melee_Blunt", "Melee_Blade", "Vehicle_Weapon",
        "Clothes", "Cyberware", "Consumable", "Medical",
        "Skillbook", "Crafting", "CraftingSpec", "Grenade",
        "Attachments", "Hacking", "Ammo", "Junk", "Readable",
        "Money", "Broken"
    }
    for _, cat in ipairs(allCategories) do
        local current = Settings.categoryScaling[cat] or Settings.markerScaling
        local newVal, used = ImGui.SliderFloat(cat .. " Scale", current, 0.0, 1.0, "%.2f")
        if used then
            if math.abs(newVal - Settings.markerScaling) < 0.01 then
                Settings.categoryScaling[cat] = nil
            else
                Settings.categoryScaling[cat] = newVal
            end
            Settings._dirty = true
        end
    end

    if ImGui.Button("Reset All to Global") then
        Settings.categoryScaling = {}
        Settings._dirty = true
    end
end
```

3. Add to `Save()` and `Load()`.

### init.lua Changes

In the render loop, resolve scale per category:

```lua
local scale = BetterLootMarkers.Settings.categoryScaling[categoryKey]
    or BetterLootMarkers.Settings.markerScaling
```

Pass this to `AddIconToWidget` (add a `scale` parameter as described in Feature 3).

---

## Feature 8: Minimap-Only vs World-Only Mode

**Impact**: Medium | **Effort**: Hard | **Files**: `Settings.lua`, `init.lua`

Let users choose to show custom markers only on the minimap, only in the world, or both.

### Research Required

This feature requires understanding how `GameplayMappinController` differentiates between minimap and world-space mappins. The key is the controller's context:

- `GameplayMappinController` is used for both minimap and world HUD markers.
- The controller may have a method like `IsMinimap()` or the mappin system may use different controller classes.
- Check the decompiled `GameplayMappinController` class hierarchy. Look for `MinimapMappinController` vs `WorldMappinController` or similar subclasses.
- Alternatively, check `ctrl:GetRootWidget()` parent chain — minimap widgets will be parented under the minimap container.

### Settings.lua Changes

Add a `markerContext` setting with three options:

```lua
local Settings = {
    -- ...
    markerContext = "both", -- "both", "minimap", "world"
    -- ...
}
```

Add a combo in `onDraw`:

```lua
local contexts = { "both", "minimap", "world" }
local currentIndex = 0
for i, ctx in ipairs(contexts) do
    if ctx == Settings.markerContext then currentIndex = i - 1 end
end
local newIndex, changed = ImGui.Combo("Show Markers", currentIndex, contexts, #contexts)
if changed then
    Settings.markerContext = contexts[newIndex + 1]
    Settings._dirty = true
end
```

### init.lua Changes

At the top of `_HandleLootMarkers`, after the variant check, add a context check:

```lua
local context = BetterLootMarkers.Settings.markerContext
if context ~= "both" then
    local isMinimap = -- detection logic here
    if context == "minimap" and not isMinimap then return end
    if context == "world" and isMinimap then return end
end
```

### Detection Approaches (try in order)

1. **Class check**: `if ctrl:IsA(CName.new("MinimapMappinController")) then` — simplest if the class exists.
2. **Widget hierarchy**: Walk up `ctrl:GetRootWidget()` parents looking for a widget named `"minimap"` or `"MinimapContainer"`.
3. **Mappin layer**: Check `mappin:GetMappinLayer()` or similar if available.

This feature has the highest research overhead. Start by dumping `ctrl` class info in CET console: `print(ctrl:GetClassName():ToString())` inside the observer to see what class is actually used for minimap vs world markers.
