local Settings = {
    showDefaultMappin = false,
    verticalMode = false,
    markerScaling = 1.0,
    isOverlayOpen = false,
    config_file = "config.json",
    _dirty = false
}

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
        markerScaling = Settings.markerScaling
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
end

return Settings
