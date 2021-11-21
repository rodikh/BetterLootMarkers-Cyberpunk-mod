local Settings = {
    hideDefaultMappin = true,
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
        hideDefaultMappin, toggled = ImGui.Checkbox("Hide Default Mappin", Settings.hideDefaultMappin)
        if toggled then
            Settings.hideDefaultMappin = hideDefaultMappin
            Settings.Save()
            BetterLootMarkers.HandleToggleHideDefaultMappin()
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
    local settings = { hideDefaultMappin = Settings.hideDefaultMappin }
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
    Settings.hideDefaultMappin = json["hideDefaultMappin"]
end

return Settings