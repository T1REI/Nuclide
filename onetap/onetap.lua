local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- Load ESP Module
local ESPClass = loadstring(game:HttpGet("https://raw.githubusercontent.com/T1REI/Nuclide/refs/heads/main/Modules/ESP.lua?t=" .. os.time()))()

-- Initialize ESP System
local espInstance = ESPClass.new()
espInstance:Start()

-- Create Player Group
local playerESP = espInstance:CreateGroup("Players")

-- Default Configuration
local playerConfig = {
    Enabled = false,
    Corner = true,
    Nametag = true,
    HealthBar = true,
    Distance = true,
    VisibleColor = Color3.fromRGB(255, 255, 255),
    InvisibleColor = Color3.fromRGB(255, 0, 0),
    MaxDistance = 5000,
    Yourself = false,
    AdaptWidth = false,
    TeamCheck = false
}

playerESP:SetConfig(playerConfig)

-- Track Players
local function addPlayer(player)
    if player == LocalPlayer then return end
    if player.Character then
        playerESP:Add(player)
    end
    player.CharacterAdded:Connect(function()
        playerESP:Add(player)
    end)
    player.CharacterRemoving:Connect(function()
        playerESP:Remove(player)
    end)
end

for _, player in ipairs(Players:GetPlayers()) do
    addPlayer(player)
end

Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(function(player)
    playerESP:Remove(player)
end)

-- Load UI Library
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()

-- Create Window
local Window = Rayfield:CreateWindow({
    name = "Nuclide - One Tap",
    subtitle = "Version 0.0.1",
    theme = "cobalt",
    configuration = {
        autoSave = true,
        autoLoad = true,
        fileName = "NuclideOneTap"
    }
})

-- Create Tabs
local PlayersTab = Window:CreateTab({ 
    name = "Players",
    icon = 6023391392
})

local SettingsTab = Window:CreateTab({ 
    name = "Settings",
    icon = 6031069255
})

-- Players Tab - ESP Controls
PlayersTab:CreateSection("Main Controls")

PlayersTab:CreateToggle({
    name = "Enable Player ESP",
    flag = "PlayerESPEnabled",
    value = false,
    callback = function(Value)
        playerConfig.Enabled = Value
        playerESP:SetEnabled(Value)
    end
})

PlayersTab:CreateToggle({
    name = "Show Yourself",
    flag = "ShowYourself",
    value = false,
    callback = function(Value)
        playerConfig.Yourself = Value
        playerESP:SetConfig(playerConfig)
    end
})

PlayersTab:CreateToggle({
    name = "Team Check",
    flag = "TeamCheck",
    value = false,
    description = "Only show enemies (game-specific)",
    callback = function(Value)
        playerConfig.TeamCheck = Value
    end
})

PlayersTab:CreateSection("Visual Elements")

PlayersTab:CreateToggle({
    name = "Corner Box",
    flag = "CornerBox",
    value = true,
    description = "Draw corner-style bounding box",
    callback = function(Value)
        playerConfig.Corner = Value
        playerESP:SetConfig(playerConfig)
    end
})

PlayersTab:CreateToggle({
    name = "Nametag",
    flag = "Nametag",
    value = true,
    description = "Show player name above head",
    callback = function(Value)
        playerConfig.Nametag = Value
        playerESP:SetConfig(playerConfig)
    end
})

PlayersTab:CreateToggle({
    name = "Health Bar",
    flag = "HealthBar",
    value = true,
    description = "Show health bar on the left",
    callback = function(Value)
        playerConfig.HealthBar = Value
        playerESP:SetConfig(playerConfig)
    end
})

PlayersTab:CreateToggle({
    name = "Distance",
    flag = "Distance",
    value = true,
    description = "Show distance below player",
    callback = function(Value)
        playerConfig.Distance = Value
        playerESP:SetConfig(playerConfig)
    end
})

PlayersTab:CreateSection("Colors")

PlayersTab:CreateColorPicker({
    name = "Visible Color",
    flag = "VisibleColor",
    color = Color3.fromRGB(255, 255, 255),
    callback = function(Value)
        playerConfig.VisibleColor = Value
        playerESP:SetConfig(playerConfig)
    end
})

PlayersTab:CreateColorPicker({
    name = "Invisible Color",
    flag = "InvisibleColor",
    color = Color3.fromRGB(255, 0, 0),
    description = "Color when behind obstacles",
    callback = function(Value)
        playerConfig.InvisibleColor = Value
        playerESP:SetConfig(playerConfig)
    end
})

PlayersTab:CreateSection("Advanced")

PlayersTab:CreateSlider({
    name = "Max Distance",
    flag = "MaxDistance",
    range = {100, 10000},
    increment = 100,
    suffix = " studs",
    value = 5000,
    callback = function(Value)
        playerConfig.MaxDistance = Value
        playerESP:SetConfig(playerConfig)
    end
})

PlayersTab:CreateToggle({
    name = "Adaptive Width",
    flag = "AdaptiveWidth",
    value = false,
    description = "Adjust box width based on model",
    callback = function(Value)
        playerConfig.AdaptWidth = Value
        playerESP:SetConfig(playerConfig)
    end
})

-- Settings Tab
SettingsTab:CreateSection("Configuration")

local currentConfigName = "NuclideOneTap"

SettingsTab:CreateInput({
    name = "Config File Name",
    flag = "ConfigFileName",
    value = "NuclideOneTap",
    placeholder = "Enter config name",
    callback = function(Text)
        if Text and Text ~= "" then
            currentConfigName = Text
        end
    end
})

SettingsTab:CreateButton({
    name = "Save Configuration",
    callback = function()
        if Window:Save(currentConfigName) then
            Window:Notify({
                title = "Config System",
                content = "Configuration saved: " .. currentConfigName,
                duration = 5
            })
        else
            Window:Notify({
                title = "Config System",
                content = "Failed to save configuration!",
                duration = 5
            })
        end
    end
})

SettingsTab:CreateButton({
    name = "Load Configuration",
    callback = function()
        if Window:Load(currentConfigName) then
            Window:Notify({
                title = "Config System",
                content = "Configuration loaded: " .. currentConfigName,
                duration = 5
            })
        else
            Window:Notify({
                title = "Config System",
                content = "Failed to load configuration!",
                duration = 5
            })
        end
    end
})

SettingsTab:CreateSection("System")

SettingsTab:CreateButton({
    name = "Unload Script",
    callback = function()
        espInstance:Destroy()
        Window:Unload()
    end
})

-- Auto-apply enabled state if loaded from config
if playerConfig.Enabled then
    playerESP:SetEnabled(true)
end

-- Notification on load
Window:Notify({
    title = "Nuclide - One Tap",
    content = "Loaded successfully! Version 0.0.1",
    duration = 5
})