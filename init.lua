local Utils = require("Modules/Utils.lua")

local CONTAINER_CNAME
local ITEM_DROP_CNAME

local _scannerCacheTime = 0
local _scannerCacheValue = false

BetterLootMarkers = {
    Settings = {},
    ItemTypes = {},
    Version = "dev",
    _managedControllers = {},
    _lastScannerState = nil,
    _cleanupTimer = 0
}

function BetterLootMarkers.LoadVersion()
    local versionFile = io.open("version.txt", "r")
    if versionFile == nil then
        return BetterLootMarkers.Version
    end

    local version = versionFile:read("*l")
    versionFile:close()
    if version == nil or version == "" then
        return BetterLootMarkers.Version
    end

    return version
end

function BetterLootMarkers:new()
    BetterLootMarkers.Settings = require("Modules/Settings.lua")
    BetterLootMarkers.Settings.Init()

    registerForEvent("onInit", function()
        CONTAINER_CNAME = CName.new("BetterLootMarkersContainer")
        ITEM_DROP_CNAME = CName.new("gameItemDropObject")

        BetterLootMarkers.Version = BetterLootMarkers.LoadVersion()
        BetterLootMarkers.ItemTypes = require("Modules/Types.lua")
        print("[BetterLootMarkers] Loaded v" .. BetterLootMarkers.Version)

        ObserveAfter("GameplayMappinController", "UpdateVisibility", function(self)
            BetterLootMarkers.HandleLootMarkersForController(self)
        end)

        ObserveAfter("GameplayMappinController", "UpdateIcon", function(self)
            BetterLootMarkers.HandleLootMarkersForController(self)
        end)
    end)

    registerForEvent("onUpdate", function(dt)
        if not BetterLootMarkers.Settings.immersiveMode then
            return
        end

        BetterLootMarkers._cleanupTimer = BetterLootMarkers._cleanupTimer + dt
        if BetterLootMarkers._cleanupTimer > 10 then
            BetterLootMarkers._cleanupTimer = 0
            BetterLootMarkers._managedControllers = {}
        end

        local scannerNow = BetterLootMarkers.IsScannerActive()

        if BetterLootMarkers._lastScannerState == nil then
            BetterLootMarkers._lastScannerState = scannerNow
            return
        end

        if scannerNow == BetterLootMarkers._lastScannerState then
            return
        end

        BetterLootMarkers._lastScannerState = scannerNow
        for ctrl, _ in pairs(BetterLootMarkers._managedControllers) do
            pcall(BetterLootMarkers._HandleLootMarkers, ctrl)
        end
    end)
end

function BetterLootMarkers.IsScannerActive()
    local now = os.clock()
    if now - _scannerCacheTime < 0.05 then
        return _scannerCacheValue
    end
    _scannerCacheTime = now

    local ok, result = pcall(function()
        local player = Game.GetPlayer()
        if player == nil then return false end

        local bb = Game.GetBlackboardSystem():GetLocalInstanced(
            player:GetEntityID(),
            GetAllBlackboardDefs().PlayerStateMachine
        )
        if bb == nil then return false end

        local visionValue = bb:GetInt(GetAllBlackboardDefs().PlayerStateMachine.Vision)
        return visionValue == 1
    end)

    if ok then
        _scannerCacheValue = result
    else
        _scannerCacheValue = false
    end
    return _scannerCacheValue
end

function BetterLootMarkers.HandleLootMarkersForController(ctrl)
    local ok, err = pcall(BetterLootMarkers._HandleLootMarkers, ctrl)
    if not ok then
        print("[BetterLootMarkers] Error: " .. tostring(err))
    end
end

function BetterLootMarkers._HandleLootMarkers(ctrl)
    if ctrl == nil then
        return
    end

    local mappin = ctrl:GetMappin()
    if mappin == nil then
        return
    end

    local variant = mappin:GetVariant()
    if variant == nil or variant ~= gamedataMappinVariant.LootVariant then
        return
    end

    local iconWidget = ctrl.iconWidget and ctrl.iconWidget.widget
    if iconWidget == nil then
        return
    end

    local parentWidget = iconWidget.parentWidget
    local containerPanel = parentWidget and parentWidget.parentWidget
    if parentWidget == nil or containerPanel == nil then
        return
    end

    BetterLootMarkers._managedControllers[ctrl] = true

    -- Immersive mode: only show custom markers when scanner is active
    if BetterLootMarkers.Settings.immersiveMode and not BetterLootMarkers.IsScannerActive() then
        iconWidget:SetScale(Vector2.new({ X = 1, Y = 1 }))
        containerPanel:RemoveChildByName(CONTAINER_CNAME)
        return
    end

    local target = Game.FindEntityByID(mappin:GetEntityID())
    if target == nil then
        return
    end

    local itemList = BetterLootMarkers.GetItemListForObject(target)
    if #itemList == 0 then
        containerPanel:RemoveChildByName(CONTAINER_CNAME)
        return
    end

    local categories = BetterLootMarkers.ResolveHighestQualityByCategory(itemList)
    BetterLootMarkers.HandleShowHideOriginalIcon(ctrl, iconWidget)

    parentWidget:SetFitToContent(true)
    parentWidget:SetAnchor(inkEAnchor.TopLeft)
    parentWidget:SetAnchorPoint(Vector2.new({
        X = 0.5,
        Y = 0.5
    }))

    containerPanel:RemoveChildByName(CONTAINER_CNAME)

    local container = BetterLootMarkers.AddPanelToWidget(containerPanel)
    local iconicMode = BetterLootMarkers.Settings.iconicHighlight
    local showCounts = BetterLootMarkers.Settings.showItemCounts

    for categoryKey, category in Utils.sortedCategoryPairs(categories, BetterLootMarkers.ItemTypes.Qualities) do
        local colorIndex = category.isIconic and "Iconic" or category.quality.value
        local color = HDRColor.new(BetterLootMarkers.ItemTypes.Colors[colorIndex])
        local iconKey = BetterLootMarkers.ItemTypes.ItemIcons[categoryKey]
        local needsCountSlot = showCounts and category.count > 1
        local iconParent = container

        if needsCountSlot then
            local slot = inkVerticalPanel.new()
            slot:SetName(CName.new("BetterLootSlot-" .. categoryKey))
            slot:SetFitToContent(true)
            slot:Reparent(container)
            iconParent = slot
        end

        if category.isIconic and iconicMode ~= "none" then
            BetterLootMarkers.AddIconicIconToWidget(iconParent, "BetterLootMappin-" .. categoryKey,
                iconKey, color, iconicMode)
        else
            BetterLootMarkers.AddIconToWidget(iconParent, "BetterLootMappin-" .. categoryKey,
                iconKey, color)
        end

        if needsCountSlot then
            BetterLootMarkers.AddCountBadge(iconParent, "BetterLootCount-" .. categoryKey,
                category.count, color)
        end
    end
end

function BetterLootMarkers.HandleShowHideOriginalIcon(ctrl, icon)
    if not BetterLootMarkers.Settings.showDefaultMappin and not ctrl:IsQuest() then
        icon:SetScale(Vector2.new({
            X = 0,
            Y = 0
        }))
    else
        icon:SetScale(Vector2.new({
            X = 1,
            Y = 1
        }))
    end
end

function BetterLootMarkers.AddPanelToWidget(parent)
    local container
    if BetterLootMarkers.Settings.verticalMode then
        container = inkVerticalPanel.new()
    else
        container = inkHorizontalPanel.new()
    end

    container:SetName(CONTAINER_CNAME)
    container:SetFitToContent(true)
    container:SetAnchor(inkEAnchor.Fill)
    container:SetAnchorPoint(Vector2.new({
        X = 0.5,
        Y = 0.5
    }))
    container:SetChildMargin(inkMargin.new({
        top = 0.0,
        right = 20.0,
        bottom = 20.0,
        left = 0.0
    }))
    container:Reparent(parent)
    return container
end

function BetterLootMarkers.ResolveIconRecord(iconId)
    local resolvedId = iconId or BetterLootMarkers.ItemTypes.ItemIcons.Default
    local record = TweakDBInterface.GetUIIconRecord(TDBID.Create(resolvedId))
    if record == nil then
        record = TweakDBInterface.GetUIIconRecord(TDBID.Create(BetterLootMarkers.ItemTypes.ItemIcons.Default))
    end
    return record
end

function BetterLootMarkers.AddIconToWidget(parent, name, iconId, color)
    local iconRecord = BetterLootMarkers.ResolveIconRecord(iconId)
    if iconRecord == nil then
        return
    end

    local icon = inkImage.new()
    icon:SetName(CName.new(name))
    icon:SetTexturePart(iconRecord:AtlasPartName())
    icon:SetAtlasResource(iconRecord:AtlasResourcePath())
    icon:SetMargin(inkMargin.new({
        top = 0.0,
        right = 0.0,
        bottom = 0.0,
        left = 0.0
    }))
    icon:SetVisible(true)
    icon:SetFitToContent(true)
    icon:SetScale(Vector2.new({
        X = BetterLootMarkers.Settings.markerScaling,
        Y = BetterLootMarkers.Settings.markerScaling
    }))
    icon:SetTintColor(color)
    parent:AddChildWidget(icon)
end

function BetterLootMarkers.AddIconicIconToWidget(parent, name, iconId, color, mode)
    local iconRecord = BetterLootMarkers.ResolveIconRecord(iconId)
    if iconRecord == nil then
        return
    end

    local scale = BetterLootMarkers.Settings.markerScaling

    if mode == "border" then
        local canvas = inkCanvas.new()
        canvas:SetName(CName.new(name))
        canvas:SetFitToContent(true)
        canvas:SetMargin(inkMargin.new({
            top = 0.0,
            right = 15.0,
            bottom = 0.0,
            left = 0.0
        }))

        -- Glow layer: larger semi-transparent copy behind the main icon
        local glow = inkImage.new()
        glow:SetName(CName.new(name .. "-glow"))
        glow:SetTexturePart(iconRecord:AtlasPartName())
        glow:SetAtlasResource(iconRecord:AtlasResourcePath())
        glow:SetVisible(true)
        glow:SetFitToContent(true)
        glow:SetScale(Vector2.new({ X = scale * 1.4, Y = scale * 1.4 }))
        glow:SetTintColor(HDRColor.new(BetterLootMarkers.ItemTypes.Colors.Iconic))
        glow:SetOpacity(0.45)
        glow:SetAnchor(inkEAnchor.Centered)
        glow:SetAnchorPoint(Vector2.new({ X = 0.5, Y = 0.5 }))
        glow:Reparent(canvas)

        -- Main icon on top
        local icon = inkImage.new()
        icon:SetName(CName.new(name .. "-icon"))
        icon:SetTexturePart(iconRecord:AtlasPartName())
        icon:SetAtlasResource(iconRecord:AtlasResourcePath())
        icon:SetVisible(true)
        icon:SetFitToContent(true)
        icon:SetScale(Vector2.new({ X = scale, Y = scale }))
        icon:SetTintColor(color)
        icon:SetAnchor(inkEAnchor.Centered)
        icon:SetAnchorPoint(Vector2.new({ X = 0.5, Y = 0.5 }))
        icon:Reparent(canvas)

        canvas:Reparent(parent)

    elseif mode == "pulse" then
        local icon = inkImage.new()
        icon:SetName(CName.new(name))
        icon:SetTexturePart(iconRecord:AtlasPartName())
        icon:SetAtlasResource(iconRecord:AtlasResourcePath())
        icon:SetMargin(inkMargin.new({ top = 0.0, right = 0.0, bottom = 0.0, left = 0.0 }))
        icon:SetVisible(true)
        icon:SetFitToContent(true)
        icon:SetScale(Vector2.new({ X = scale, Y = scale }))
        icon:SetTintColor(color)
        parent:AddChildWidget(icon)

        local animDef = inkAnimDef.new()
        local scaleInterp = inkAnimScale.new()
        scaleInterp:SetStartScale(Vector2.new({ X = scale, Y = scale }))
        scaleInterp:SetEndScale(Vector2.new({ X = scale * 1.25, Y = scale * 1.25 }))
        scaleInterp:SetDuration(0.4)
        animDef:AddInterpolator(scaleInterp)

        local options = inkAnimOptions.new()
        options.loopType = inkanimLoopType.PingPong
        options.loopCounter = 0
        icon:PlayAnimationWithOptions(animDef, options)

        if not icon:IsAnimationPlaying() then
            -- Fallback: try constructor-style options
            local opts2 = inkAnimOptions.new({ loopType = 2, loopCounter = 0 })
            icon:PlayAnimationWithOptions(animDef, opts2)
        end
    end
end

function BetterLootMarkers.AddCountBadge(parent, name, count, color)
    local text = inkText.new()
    text:SetName(CName.new(name))
    text:SetText(tostring(count))
    text:SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily")
    text:SetFontSize(18)
    text:SetTintColor(color)
    text:SetVisible(true)
    text:SetFitToContent(true)
    text:SetHAlign(inkEHorizontalAlign.Center)
    text:SetScale(Vector2.new({
        X = BetterLootMarkers.Settings.markerScaling,
        Y = BetterLootMarkers.Settings.markerScaling
    }))
    parent:AddChildWidget(text)
end

function BetterLootMarkers.GetItemScore(itemData)
    if itemData.isIconic then
        return BetterLootMarkers.ItemTypes.Qualities.Iconic
    end

    local qualityValue = itemData.quality and itemData.quality.value
    return BetterLootMarkers.ItemTypes.Qualities[qualityValue] or -1
end

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

function BetterLootMarkers.GetLootCategoryForItem(item)
    if item:GetNameAsString() == "money" then
        return "Money"
    end

    if RPGManager.IsItemBroken(item) then
        return "Broken"
    end

    if item:HasTag("Recipe") then
        return "CraftingSpec"
    end

    local itemType = item:GetItemType()
    local mappedCategory = BetterLootMarkers.ItemTypes.TypeToCategoryByString[tostring(itemType)]
    if mappedCategory ~= nil then
        return mappedCategory
    end

    for cat, list in pairs(BetterLootMarkers.ItemTypes.Categories) do
        if Utils.HasValue(list, itemType) then
            return cat
        end
    end

    return "Default"
end

function BetterLootMarkers.GetItemListForObject(object)
    local transactionSystem = Game.GetTransactionSystem()
    if transactionSystem == nil then
        return {}
    end

    local _, itemList = transactionSystem:GetItemList(object)
    itemList = itemList or {}
    if #itemList == 0 then
        local owner = object:GetOwner()
        if not owner then
            return {}
        end
        if owner:IsA(ITEM_DROP_CNAME) then
            _, itemList = transactionSystem:GetItemList(owner)
            itemList = itemList or {}
        end
    end

    return itemList
end

return BetterLootMarkers:new()
