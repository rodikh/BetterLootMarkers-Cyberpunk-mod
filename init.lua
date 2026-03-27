local Utils = require("Modules/Utils.lua")

BetterLootMarkers = {
    Settings = {},
    ItemTypes = {},
    _renderCache = {},
    Version = "dev"
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
        BetterLootMarkers.Version = BetterLootMarkers.LoadVersion()
        BetterLootMarkers.ItemTypes = require("Modules/Types.lua")
        print("[BetterLootMarkers] Loaded v" .. BetterLootMarkers.Version)

        ObserveAfter("GameplayMappinController", "UpdateVisibility", function(self)
            BetterLootMarkers.HandleLootMarkersForController(self)
        end)

        ObserveAfter("GameplayMappinController", "UpdateIcon", function(self)
            BetterLootMarkers.HandleLootMarkersForController(self)
        end)

        -- CDPR removed "HasLootableItems" from 2.0
        -- Override("ScriptedPuppet", "HasLootableItems;ScriptedPuppet", function(self)
        --     -- This fixes a bug where bodies with only ammo loot will not show markers in the vanilla game. HasLootableItems is coded to ignore ammo.
        --     local _, itemList = Game.GetTransactionSystem():GetItemList(self)
        --     return table.getn(itemList) > 0
        -- end)
    end)
end

function BetterLootMarkers.HandleLootMarkersForController(ctrl)
    if ctrl == nil or ctrl:GetMappin() == nil or ctrl:GetMappin():GetVariant() == nil then
        -- compatibility fix with other mods
        return
    end

    if ctrl:GetMappin():GetVariant() ~= gamedataMappinVariant.LootVariant then
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

    -- Full passthrough mode: restore vanilla marker and remove custom widgets.
    if BetterLootMarkers.Settings.showDefaultMappin then
        BetterLootMarkers.RestoreVanillaMarker(ctrl, iconWidget, containerPanel)
        return
    end

    local target = Game.FindEntityByID(ctrl:GetMappin():GetEntityID())
    if target == nil then
        -- TODO: Why sometimes no target?
        return
    end

    local itemList = BetterLootMarkers.GetItemListForObject(target)
    local itemCount = table.getn(itemList)
    if itemCount == 0 then
        local cacheKey = BetterLootMarkers.GetControllerCacheKey(ctrl)
        if cacheKey ~= nil then
            BetterLootMarkers._renderCache[cacheKey] = nil
        end
        containerPanel:RemoveChildByName(CName.new("BetterLootMarkersContainer"))
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

    local cacheKey = BetterLootMarkers.GetControllerCacheKey(ctrl)
    local renderSignature = BetterLootMarkers.BuildRenderSignature(categories, ctrl:IsQuest())
    if cacheKey ~= nil and BetterLootMarkers._renderCache[cacheKey] == renderSignature then
        return
    end

    containerPanel:RemoveChildByName(CName.new("BetterLootMarkersContainer"))

    local betterLootMarkersContainer = BetterLootMarkers.AddPanelToWidget(containerPanel, "BetterLootMarkersContainer")
    for categoryKey, category in Utils.sortedCategoryPairs(categories) do
        local colorIndex = category.isIconic and "Iconic" or category.quality.value
        local color = HDRColor.new(BetterLootMarkers.ItemTypes.Colors[colorIndex])
        BetterLootMarkers.AddIconToWidget(betterLootMarkersContainer, "BetterLootMappin-" .. categoryKey,
            BetterLootMarkers.ItemTypes.ItemIcons[categoryKey], color, colorIndex)
    end

    if cacheKey ~= nil then
        BetterLootMarkers._renderCache[cacheKey] = renderSignature
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

function BetterLootMarkers.RestoreVanillaMarker(ctrl, iconWidget, containerPanel)
    BetterLootMarkers.HandleShowHideOriginalIcon(ctrl, iconWidget)

    local cacheKey = BetterLootMarkers.GetControllerCacheKey(ctrl)
    if cacheKey ~= nil then
        BetterLootMarkers._renderCache[cacheKey] = nil
    end

    containerPanel:RemoveChildByName(CName.new("BetterLootMarkersContainer"))
end

function BetterLootMarkers.AddPanelToWidget(parent, name)
    local betterLootMarkersContainer
    if BetterLootMarkers.Settings.verticalMode then
        betterLootMarkersContainer = inkVerticalPanel.new()
    else
        betterLootMarkersContainer = inkHorizontalPanel.new()
    end

    betterLootMarkersContainer:SetName(CName.new(name))
    betterLootMarkersContainer:SetFitToContent(true)
    betterLootMarkersContainer:SetAnchor(inkEAnchor.Fill)
    betterLootMarkersContainer:SetAnchorPoint(Vector2.new({
        X = 0.5,
        Y = 0.5
    }))
    betterLootMarkersContainer:SetChildMargin(inkMargin.new({
        top = 0.0,
        right = 20.0,
        bottom = 20.0,
        left = 0.0
    }))
    betterLootMarkersContainer:Reparent(parent)
    return betterLootMarkersContainer
end

function BetterLootMarkers.AddIconToWidget(parent, name, iconId, color, value)
    local icon = inkImage.new()
    icon:SetName(CName.new(name))
    local resolvedIconId = iconId or BetterLootMarkers.ItemTypes.ItemIcons.Default
    local iconRecord = TweakDBInterface.GetUIIconRecord(TDBID.Create(resolvedIconId))
    if iconRecord == nil then
        iconRecord = TweakDBInterface.GetUIIconRecord(TDBID.Create(BetterLootMarkers.ItemTypes.ItemIcons.Default))
        if iconRecord == nil then
            return
        end
    end
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

function BetterLootMarkers.GetControllerCacheKey(ctrl)
    local mappin = ctrl:GetMappin()
    if mappin == nil or mappin:GetEntityID() == nil then
        return nil
    end

    return tostring(EntityID.GetHash(mappin:GetEntityID()))
end

function BetterLootMarkers.BuildRenderSignature(categories, isQuest)
    local parts = {
        BetterLootMarkers.Settings.verticalMode and "v1" or "v0",
        BetterLootMarkers.Settings.showDefaultMappin and "d1" or "d0",
        string.format("s%.2f", BetterLootMarkers.Settings.markerScaling or 1.0),
        isQuest and "q1" or "q0"
    }

    for categoryKey, category in Utils.sortedCategoryPairs(categories) do
        local colorIndex = category.isIconic and "Iconic" or category.quality.value
        parts[#parts + 1] = categoryKey .. ":" .. colorIndex
    end

    return table.concat(parts, "|")
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
        if not Utils.HasKey(categories, category) then
            categories[category] = newItem
        else
            local currentItem = categories[category]
            local newScore = BetterLootMarkers.GetItemScore(newItem)
            local currentScore = BetterLootMarkers.GetItemScore(currentItem)
            if newScore > currentScore then
                categories[category] = newItem
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

    local mappedCategory = BetterLootMarkers.ItemTypes.TypeToCategory[item:GetItemType()]
    if mappedCategory ~= nil then
        return mappedCategory
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
    local itemCount = table.getn(itemList)
    local owner = object:GetOwner()
    if itemCount == 0 and not owner then
        return {}
    end
    if itemCount == 0 and owner:IsA(CName.new("gameItemDropObject")) then
        object = object:GetOwner()
        _, itemList = transactionSystem:GetItemList(object)
        itemList = itemList or {}
    end

    return itemList
end

return BetterLootMarkers:new()
