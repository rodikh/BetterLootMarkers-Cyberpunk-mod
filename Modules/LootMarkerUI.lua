-- inkWidget / canvas helpers for loot marker icons. Requires global BetterLootMarkers
-- (table must exist before this module is loaded). CONTAINER_CNAME is assigned in onInit.

assert(BetterLootMarkers, "LootMarkerUI: load after BetterLootMarkers is defined")

-- Fixed square cell shared by every loot icon so the horizontal panel row height
-- matches; otherwise a tall iconic border cell stretches shorter inkImages.
-- Small outer pad: large values add visible gap between adjacent icon columns.
local LOOT_ICON_CELL_PAD = 2.0

function BetterLootMarkers.GetMarkerCellSize()
    local scale = BetterLootMarkers.Settings.markerScaling
    return 64.0 * (0.45 + scale * 0.55) * 1.55
end

function BetterLootMarkers.CreateLootIconCell(name)
    local cell = BetterLootMarkers.GetMarkerCellSize()
    local canvas = inkCanvas.new()
    canvas:SetName(CName.new(name))
    canvas:SetMargin(inkMargin.new({
        top = LOOT_ICON_CELL_PAD,
        right = LOOT_ICON_CELL_PAD,
        bottom = LOOT_ICON_CELL_PAD,
        left = LOOT_ICON_CELL_PAD
    }))
    canvas:SetHAlign(inkEHorizontalAlign.Center)
    local ok = pcall(function()
        canvas:SetSize(Vector2.new({ X = cell, Y = cell }))
        canvas:SetFitToContent(false)
    end)
    if not ok then
        canvas:SetFitToContent(true)
    end
    return canvas
end

function BetterLootMarkers.AddPanelToWidget(parent)
    local container
    if BetterLootMarkers.Settings.verticalMode then
        container = inkVerticalPanel.new()
    else
        container = inkHorizontalPanel.new()
    end

    container:SetName(BetterLootMarkers.CONTAINER_CNAME)
    container:SetFitToContent(true)
    container:SetAnchor(inkEAnchor.Fill)
    container:SetAnchorPoint(Vector2.new({
        X = 0.5,
        Y = 0.5
    }))
    container:SetChildMargin(inkMargin.new({
        top = 0.0,
        right = 4.0,
        bottom = 10.0,
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

    local canvas = BetterLootMarkers.CreateLootIconCell(name .. "-cell")

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
    icon:SetAnchor(inkEAnchor.Centered)
    icon:SetAnchorPoint(Vector2.new({ X = 0.5, Y = 0.5 }))
    icon:SetHAlign(inkEHorizontalAlign.Center)
    icon:Reparent(canvas)
    canvas:Reparent(parent)
end

function BetterLootMarkers.AddIconicIconToWidget(parent, name, iconId, color, mode, pulseRegisterList)
    local iconRecord = BetterLootMarkers.ResolveIconRecord(iconId)
    if iconRecord == nil then
        return
    end

    local scale = BetterLootMarkers.Settings.markerScaling

    if mode == "border" then
        local canvas = BetterLootMarkers.CreateLootIconCell(name)

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
        glow:SetHAlign(inkEHorizontalAlign.Center)
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
        icon:SetHAlign(inkEHorizontalAlign.Center)
        icon:Reparent(canvas)

        canvas:Reparent(parent)

    elseif mode == "pulse" then
        local canvas = BetterLootMarkers.CreateLootIconCell(name .. "-pulsecell")

        local icon = inkImage.new()
        icon:SetName(CName.new(name))
        icon:SetTexturePart(iconRecord:AtlasPartName())
        icon:SetAtlasResource(iconRecord:AtlasResourcePath())
        icon:SetMargin(inkMargin.new({ top = 0.0, right = 0.0, bottom = 0.0, left = 0.0 }))
        icon:SetVisible(true)
        icon:SetFitToContent(true)
        icon:SetScale(Vector2.new({ X = scale, Y = scale }))
        icon:SetTintColor(color)
        icon:SetAnchor(inkEAnchor.Centered)
        icon:SetAnchorPoint(Vector2.new({ X = 0.5, Y = 0.5 }))
        icon:SetHAlign(inkEHorizontalAlign.Center)
        icon:Reparent(canvas)
        canvas:Reparent(parent)

        -- Pulse is driven by init.lua TickIconicPulseAnimations (onUpdate): ink
        -- PlayAnimationWithOptions looping is unreliable in CET.
        if pulseRegisterList ~= nil then
            table.insert(pulseRegisterList, { icon = icon, base = scale })
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
