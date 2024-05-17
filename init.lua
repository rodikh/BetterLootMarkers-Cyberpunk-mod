local Utils = require("Modules/Utils.lua")

BetterLootMarkers = {
    Settings = {},
    ItemTypes = {}
}

function BetterLootMarkers:new()
    BetterLootMarkers.Settings = require("Modules/Settings.lua")
    BetterLootMarkers.Settings.Init()

    registerForEvent("onInit", function()
        BetterLootMarkers.ItemTypes = require("Modules/Types.lua")

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
    if ctrl:GetMappin():GetVariant() ~= gamedataMappinVariant.LootVariant then
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
        return
    end

    local categories = BetterLootMarkers.ResolveHighestQualityByCategory(itemList)
    BetterLootMarkers.HandleShowHideOriginalIcon(ctrl, ctrl.iconWidget.widget)

    local parentWidget = ctrl.iconWidget.widget.parentWidget
    parentWidget:SetFitToContent(true)
    parentWidget:SetAnchor(inkEAnchor.TopLeft)
    parentWidget:SetAnchorPoint(Vector2.new({
        X = 0.5,
        Y = 0.5
    }))

    local containerPanel = ctrl.iconWidget.widget.parentWidget.parentWidget
    containerPanel:RemoveChildByName(CName.new("BetterLootMarkersContainer"))

    local betterLootMarkersContainer = BetterLootMarkers.AddPanelToWidget(containerPanel, "BetterLootMarkersContainer")
    for categoryKey, category in Utils.sortedCategoryPairs(categories) do
        local colorIndex = category.isIconic and "Iconic" or category.quality.value
        local color = HDRColor.new(BetterLootMarkers.ItemTypes.Colors[colorIndex])
        BetterLootMarkers.AddIconToWidget(betterLootMarkersContainer, "BetterLootMappin-" .. categoryKey,
            BetterLootMarkers.ItemTypes.ItemIcons[categoryKey], color, colorIndex)
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
    iconRecord = TweakDBInterface.GetUIIconRecord(TDBID.Create(iconId))
    icon:SetTexturePart(iconRecord:AtlasPartName())
    icon:SetAtlasResource( iconRecord:AtlasResourcePath())

    icon:SetMargin(inkMargin.new({
        top = 0.0,
        right = 0.0,
        bottom = 00.0,
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
            local qualityForCompare = quality
            if newItem.isIconic then
                qualityForCompare = BetterLootMarkers.ItemTypes.Qualities.Iconic
            end
            if BetterLootMarkers.ItemTypes.Qualities[qualityForCompare.value] >
                BetterLootMarkers.ItemTypes.Qualities[categories[category].quality.value] then
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

    for type, list in pairs(BetterLootMarkers.ItemTypes.Categories) do
        if Utils.HasValue(list, item:GetItemType()) then
            return type
        end
    end

    return "Default"
end

function BetterLootMarkers.GetItemListForObject(object)
    local _, itemList = Game.GetTransactionSystem():GetItemList(object)
    local itemCount = table.getn(itemList)
    local owner = object:GetOwner()
    if itemCount == 0 and not owner then
        return {}
    end
    if itemCount == 0 and owner:IsA(CName.new("gameItemDropObject")) then
        object = object:GetOwner()
        _, itemList = Game.GetTransactionSystem():GetItemList(object)
    end

    return itemList
end

return BetterLootMarkers:new()
