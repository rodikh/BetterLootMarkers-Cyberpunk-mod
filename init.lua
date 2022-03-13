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
            local target = Game.FindEntityByID(self:GetMappin():GetEntityID())
            BetterLootMarkers.HandleLootMarkersForController(self)
        end)

        ObserveAfter("GameplayMappinController", "UpdateIcon", function(self)
            local target = Game.FindEntityByID(self:GetMappin():GetEntityID())
            BetterLootMarkers.HandleLootMarkersForController(self)
        end)

        Override("ScriptedPuppet", "HasLootableItems;ScriptedPuppet", function(self)
            -- This fixes a bug where bodies with only ammo loot will not show markers in the vanilla game. HasLootableItems is coded to ignore ammo.
            local _, itemList = Game.GetTransactionSystem():GetItemList(self)
            return table.getn(itemList) > 0
        end)
    end)
end

function BetterLootMarkers.HandleLootMarkersForController(ctrl)
    if ctrl:GetMappin():GetVariant() ~= gamedataMappinVariant.LootVariant then
        return
    end

    local target = Game.FindEntityByID(ctrl:GetMappin():GetEntityID())
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

    local horizontalPanel = ctrl.iconWidget.widget.parentWidget.parentWidget
    horizontalPanel:RemoveChildByName(CName.new("BetterLootMarkersContainer"))

    local betterLootMarkersContainer = BetterLootMarkers.AddPanelToWidget(horizontalPanel, "BetterLootMarkersContainer")

    for categoryKey, category in pairs(categories) do
        local color = HDRColor.new(BetterLootMarkers.ItemTypes.Colors[category.quality.value])
        BetterLootMarkers.AddIconToWidget(
            betterLootMarkersContainer,
            "BetterLootMappin-" .. categoryKey,
            categoryKey,
            color
        )
    end
end

function BetterLootMarkers.HandleShowHideOriginalIcon(ctrl, icon)
    if BetterLootMarkers.Settings.hideDefaultMappin and not ctrl:IsQuest() then
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
    local betterLootMarkersContainer = inkHorizontalPanel.new()
    betterLootMarkersContainer:SetName(CName.new(name))
    betterLootMarkersContainer:SetFitToContent(true)
    betterLootMarkersContainer:SetHAlign(inkEHorizontalAlign.Center)
    betterLootMarkersContainer:SetAnchor(inkEAnchor.Fill)
    betterLootMarkersContainer:SetAnchorPoint(Vector2.new({
        X = 0.5,
        Y = 0.5
    }))
    betterLootMarkersContainer:SetChildMargin(inkMargin.new({
        top = 0.0,
        right = 20.0,
        bottom = 0.0,
        left = 0.0
    }))
    betterLootMarkersContainer:Reparent(parent)
    return betterLootMarkersContainer
end

function BetterLootMarkers.AddIconToWidget(parent, name, iconId, color)
    local icon = inkImage.new()
    icon:SetName(CName.new(name))
    InkImageUtils.RequestSetImage(icon:GetController(), icon, iconId)

    icon:SetVisible(true)
    icon:SetFitToContent(true)
    if(string.find(iconId, 'WeaponTypeIcon')) then
        icon:SetScale(Vector2.new({
            X = 3,
            Y = 1
        }))
        icon:SetMargin(inkMargin.new({
            top = 0.0,
            right = 0.0,
            bottom = 0.0,
            left = 32.0
        }))
    elseif string.find(iconId, 'Ammo') then
        icon:SetScale(Vector2.new({
            X = 1.5,
            Y = 1
        }))
        icon:SetMargin(inkMargin.new({
            top = 0.0,
            right = 0.0,
            bottom = 0.0,
            left = 8.0
        }))
    else
        icon:SetScale(Vector2.new({
            X = 1,
            Y = 1
        }))
        icon:SetMargin(inkMargin.new({
            top = 0.0,
            right = 0.0,
            bottom = 0.0,
            left = 0.0
        }))
    end
    icon:SetTintColor(color)
    parent:AddChildWidget(icon)
end

function BetterLootMarkers.ResolveHighestQualityByCategory(itemList)
    local categories = {}
    for _, item in ipairs(itemList) do
        local quality = RPGManager.GetItemDataQuality(item)
        local category = BetterLootMarkers.GetIconByTweakDBID(item:GetID().id.hash, item:GetItemType().value)
        local newItem = {
            quality = quality,
            isIconic = RPGManager.IsItemIconic(item)
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


function BetterLootMarkers.GetIconByTweakDBID(itemTDBID, itemType)
    local t = {
        [TweakDBID.new("Items.money").hash] = "UIIcon.LootingShadow_Cash",
        [TweakDBID.new("Ammo.HandgunAmmo").hash] = "UIIcon.LootingShadow_HandgunAmmo",
        [TweakDBID.new("Ammo.ShotgunAmmo").hash] = "UIIcon.LootingShadow_ShotgunAmmo",
        [TweakDBID.new("Ammo.RifleAmmo").hash] = "UIIcon.LootingShadow_RifleAmmo",
        [TweakDBID.new("Ammo.SniperRifleAmmo").hash] = "UIIcon.LootingShadow_SniperRifleAmmo"
    };
    if(null ~= t[itemTDBID]) then
        return t[itemTDBID];
    end
    return BetterLootMarkers.GetIconByItemType(itemType);
end

function BetterLootMarkers.GetIconByItemType(itemType)
    t = {
        Clo_Face = "UIIcon.LootingShadow_Face",
        Clo_Feet = "UIIcon.LootingShadow_Feet",
        Clo_Head = "UIIcon.LootingShadow_Head",
        Clo_InnerChest = "UIIcon.LootingShadow_InnerChest",
        Clo_Legs = "UIIcon.LootingShadow_Legs",
        Clo_OuterChest = "UIIcon.LootingShadow_OuterChest",
        Clo_Outfit = "UIIcon.LootingShadow_Outfit",
        Con_Ammo = 'UIIcon.LootingShadow_Magazine',
        Con_Edible = 'UIIcon.LootingShadow_Consumable',
        Con_Inhaler = "UIIcon.LootingShadow_Inhaler",
        Con_Injector = "UIIcon.LootingShadow_Injector",
        Con_LongLasting = 'UIIcon.LootingShadow_Consumable',
        Con_Skillbook = "UIIcon.LootingShadow_Shard",
        Cyb_Ability = "UIIcon.LootingShadow_Cyberware",
        Cyb_Launcher = "UIIcon.LootingShadow_Cyberware",
        Cyb_MantisBlades = "UIIcon.LootingShadow_Cyberware",
        Cyb_NanoWires = "UIIcon.LootingShadow_Cyberware",
        Cyb_StrongArms = "UIIcon.LootingShadow_Cyberware",
        Cyberware = "UIIcon.LootingShadow_Cyberware",
        Gad_Grenade = "UIIcon.LootingShadow_Grenade",
        Gen_CraftingMaterial = "UIIcon.LootingShadow_Material",
        Gen_DataBank = 'UIIcon.Filter_AllItems', -- didn't find any specific Icon
        Gen_Jewellery = "UIIcon.LootingShadow_Junk",
        Gen_Junk = "UIIcon.LootingShadow_Junk",
        Gen_Keycard = 'UIIcon.Filter_AllItems', -- didn't find any specific Icon
        Gen_Misc = 'UIIcon.Filter_AllItems', -- don't have any Icon e.g. Crafting Specs
        Gen_Readable = "UIIcon.LootingShadow_Shard",
        Prt_BootsFabricEnhancer = "UIIcon.LootingShadow_Material",
        Prt_PantsFabricEnhancer = "UIIcon.LootingShadow_Material",
        Prt_OuterTorsoFabricEnhancer = "UIIcon.LootingShadow_Material",
        Prt_FaceFabricEnhancer = "UIIcon.LootingShadow_Material",
        Prt_HeadFabricEnhancer = "UIIcon.LootingShadow_Material",
        Prt_TorsoFabricEnhancer = "UIIcon.LootingShadow_Material",
        Prt_FabricEnhancer = "UIIcon.LootingShadow_Material",
        Prt_Fragment = "UIIcon.LootingShadow_Fragment",
        Prt_Magazine = "UIIcon.LootingShadow_Magazine",
        Prt_Mod =  "UIIcon.LootingShadow_Mod",
        Prt_RifleMuzzle = "UIIcon.LootingShadow_Silencer",
        Prt_HandgunMuzzle = "UIIcon.LootingShadow_Silencer",
        Prt_Muzzle = "UIIcon.LootingShadow_Silencer",
        Prt_Program = "UIIcon.LootingShadow_Program",
        Prt_Receiver = "UIIcon.LootingShadow_Receiver",
        Prt_Scope = "UIIcon.LootingShadow_Scope",
        Prt_ScopeRail = "UIIcon.LootingShadow_ScopeRail",
        Prt_Stock = "UIIcon.LootingShadow_Stock",
        Prt_TargetingSystem = "UIIcon.LootingShadow_TargetingSystem",
        Wea_AssaultRifle = "UIIcon.WeaponTypeIcon_AssaultRifle",
        Wea_Fists = "UIIcon.WeaponTypeIcon_Fists",
        Wea_Hammer = "UIIcon.WeaponTypeIcon_Hammer",
        Wea_Handgun = "UIIcon.WeaponTypeIcon_Handgun",
        Wea_HeavyMachineGun = "UIIcon.WeaponTypeIcon_HeavyMachineGun",
        Wea_Katana = "UIIcon.WeaponTypeIcon_Katana",
        Wea_Knife = "UIIcon.WeaponTypeIcon_Knife",
        Wea_LightMachineGun = "UIIcon.WeaponTypeIcon_LightMachineGun",
        Wea_LongBlade = "UIIcon.WeaponTypeIcon_LongBlade",
        Wea_Melee = "UIIcon.WeaponTypeIcon_Melee",
        Wea_OneHandedClub = "UIIcon.WeaponTypeIcon_OneHandedClub",
        Wea_PrecisionRifle = "UIIcon.WeaponTypeIcon_PrecisionRifle",
        Wea_Revolver = "UIIcon.WeaponTypeIcon_Revolver",
        Wea_Rifle = "UIIcon.WeaponTypeIcon_Rifle",
        Wea_ShortBlade = "UIIcon.WeaponTypeIcon_ShortBlade",
        Wea_Shotgun = "UIIcon.WeaponTypeIcon_Shotgun",
        Wea_ShotgunDual = "UIIcon.WeaponTypeIcon_ShotgunDual",
        Wea_SniperRifle = "UIIcon.WeaponTypeIcon_SniperRifle",
        Wea_SubmachineGun = "UIIcon.WeaponTypeIcon_SubmachineGun",
        Wea_TwoHandedClub = "UIIcon.WeaponTypeIcon_TwoHandedClub",
    };
    if(null ~= t[itemType]) then
        return t[itemType];
    end
    return "UIIcon.LootingShadow_Default";
end

return BetterLootMarkers:new()
