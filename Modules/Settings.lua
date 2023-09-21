local Settings = {
    verticalMode = false,
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
    local settings = { verticalMode = Settings.verticalMode }
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
end

return Settings