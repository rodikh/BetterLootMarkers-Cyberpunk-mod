local Settings = {
    showDefaultMappin = false,
    verticalMode = false,
    markerScaling = 1.0,
    isOverlayOpen = false,
    config_file = "config.json"
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
        verticalMode, toggled = ImGui.Checkbox("Vertical Mode", Settings.verticalMode)
        if toggled then
            Settings.verticalMode = verticalMode
            Settings.Save()
        end

        showDefaultMappin, toggled = ImGui.Checkbox("Show Default Markers", Settings.showDefaultMappin)
        if toggled then
            Settings.showDefaultMappin = showDefaultMappin
            Settings.Save()
        end

        local used = false
        markerScaling, used = ImGui.SliderFloat("Marker Scaling", Settings.markerScaling, 0.0, 1.0, "%.2f")
        if used then
            Settings.markerScaling = markerScaling
            Settings.Save()
        end

        ImGui.End()
        ImGui.PopStyleVar(1)
    end)

    registerForEvent("onOverlayOpen", function()
        Settings.isOverlayOpen = true
    end)

    registerForEvent("onOverlayClose", function()
        Settings.isOverlayOpen = false
    end)
end

function Settings.Save()
    local settings = { verticalMode = Settings.verticalMode, showDefaultMappin = Settings.showDefaultMappin, markerScaling = Settings.markerScaling }
    local file = io.open(Settings.config_file, "w")
    file:write(json.encode(settings))
    file:close()
end

function Settings.Load()
    local file = io.open(Settings.config_file, "r")
    if file == nil then
        return
    end

    local json = json.decode(file:read("*a"))
    file:close()
    Settings.verticalMode = json["verticalMode"]
    Settings.showDefaultMappin = json["showDefaultMappin"]
    Settings.markerScaling = json["markerScaling"]
end

return Settings