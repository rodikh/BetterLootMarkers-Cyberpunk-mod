local Settings = {
    showDefaultMappin = false,
    verticalMode = false,
    markerScaling = 1.0,
    iconicHighlight = "none",
    showItemCounts = false,
    immersiveMode = false,
    isOverlayOpen = false,
    config_file = "config.json",
    _dirty = false
}

local ICONIC_OPTIONS = { "none", "border", "pulse" }
local ICONIC_LABELS = { "None", "Border (Glow)", "Pulse (Animation)" }

function Settings.Init()
    Settings.Load()

    registerForEvent("onDraw", function()
        if not Settings.isOverlayOpen then
            return
        end

        ImGui.PushStyleVar(ImGuiStyleVar.WindowMinSize, 300, 40)
        ImGui.Begin("BetterLootMarkers", ImGuiWindowFlags.AlwaysAutoResize)

        local toggled = false

        local verticalMode
        verticalMode, toggled = ImGui.Checkbox("Vertical Mode", Settings.verticalMode)
        if toggled then
            Settings.verticalMode = verticalMode
            Settings._dirty = true
        end

        local showDefaultMappin
        showDefaultMappin, toggled = ImGui.Checkbox("Show Default Markers", Settings.showDefaultMappin)
        if toggled then
            Settings.showDefaultMappin = showDefaultMappin
            Settings._dirty = true
        end

        local used = false
        local markerScaling
        markerScaling, used = ImGui.SliderFloat("Marker Scaling", Settings.markerScaling, 0.0, 1.0, "%.2f")
        if used then
            Settings.markerScaling = markerScaling
            Settings._dirty = true
        end

        ImGui.Separator()

        local immersiveMode
        immersiveMode, toggled = ImGui.Checkbox("Immersive Mode (Scanner Only)", Settings.immersiveMode)
        if toggled then
            Settings.immersiveMode = immersiveMode
            Settings._dirty = true
        end

        local iconicIndex = 0
        for i, opt in ipairs(ICONIC_OPTIONS) do
            if opt == Settings.iconicHighlight then
                iconicIndex = i - 1
            end
        end
        local newIconicIndex
        newIconicIndex, toggled = ImGui.Combo("Iconic Highlight", iconicIndex, ICONIC_LABELS, #ICONIC_LABELS)
        if toggled then
            Settings.iconicHighlight = ICONIC_OPTIONS[newIconicIndex + 1]
            Settings._dirty = true
        end

        local showItemCounts
        showItemCounts, toggled = ImGui.Checkbox("Show Item Counts", Settings.showItemCounts)
        if toggled then
            Settings.showItemCounts = showItemCounts
            Settings._dirty = true
        end

        ImGui.End()
        ImGui.PopStyleVar(1)
    end)

    registerForEvent("onOverlayOpen", function()
        Settings.isOverlayOpen = true
    end)

    registerForEvent("onOverlayClose", function()
        Settings.isOverlayOpen = false
        if Settings._dirty then
            Settings.Save()
            Settings._dirty = false
        end
    end)
end

function Settings.Save()
    local settings = {
        verticalMode = Settings.verticalMode,
        showDefaultMappin = Settings.showDefaultMappin,
        markerScaling = Settings.markerScaling,
        iconicHighlight = Settings.iconicHighlight,
        showItemCounts = Settings.showItemCounts,
        immersiveMode = Settings.immersiveMode
    }
    local file = io.open(Settings.config_file, "w")
    if file == nil then
        return
    end
    file:write(json.encode(settings))
    file:close()
end

function Settings.Load()
    local file = io.open(Settings.config_file, "r")
    if file == nil then
        return
    end

    local contents = file:read("*a")
    file:close()

    local ok, decoded = pcall(json.decode, contents)
    if not ok or type(decoded) ~= "table" then
        return
    end

    if type(decoded["verticalMode"]) == "boolean" then
        Settings.verticalMode = decoded["verticalMode"]
    end
    if type(decoded["showDefaultMappin"]) == "boolean" then
        Settings.showDefaultMappin = decoded["showDefaultMappin"]
    end
    if type(decoded["markerScaling"]) == "number" then
        Settings.markerScaling = math.max(0.0, math.min(1.0, decoded["markerScaling"]))
    end
    if type(decoded["iconicHighlight"]) == "string" then
        local valid = { none = true, border = true, pulse = true }
        if valid[decoded["iconicHighlight"]] then
            Settings.iconicHighlight = decoded["iconicHighlight"]
        end
    end
    if type(decoded["showItemCounts"]) == "boolean" then
        Settings.showItemCounts = decoded["showItemCounts"]
    end
    if type(decoded["immersiveMode"]) == "boolean" then
        Settings.immersiveMode = decoded["immersiveMode"]
    end
end

return Settings
