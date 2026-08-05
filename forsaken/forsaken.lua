local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ESPClass = loadstring(game:HttpGet("https://raw.githubusercontent.com/T1REI/Nuclide/refs/heads/main/Modules/ESP.lua?t=" .. os.time()))()
local ChamsClass = loadstring(game:HttpGet("https://raw.githubusercontent.com/T1REI/Nuclide/refs/heads/main/Modules/Chams.lua?t=" .. os.time()))()
local AutoGeneratorClass = loadstring(game:HttpGet("https://raw.githubusercontent.com/T1REI/Nuclide/refs/heads/main/Modules/AutoGenerator.lua?t=" .. os.time()))()
local ExploitsClass = loadstring(game:HttpGet("https://raw.githubusercontent.com/T1REI/Nuclide/refs/heads/main/Modules/Exploits.lua?t=" .. os.time()))()

local espInstance = ESPClass.new()
espInstance:Start()

local chamsInstance = ChamsClass.new()
chamsInstance:Start()

local autoGen = AutoGeneratorClass.new()
autoGen:Start()

local exploits = ExploitsClass.new()
exploits:Start()

local killerESP = espInstance:CreateGroup("Killers")
local survivorESP = espInstance:CreateGroup("Survivors")

local generatorChams = chamsInstance:CreateGroup("Generators")
local itemESP = espInstance:CreateGroup("Items")

generatorChams:SetEnabled(false)
generatorChams:SetConfig({
	VisibleColor = Color3.fromRGB(0, 255, 255),
	InvisibleColor = Color3.fromRGB(0, 255, 255),
})

itemESP:SetConfig({
	Corner = false,
	HealthBar = false,
	Distance = false,
	Nametag = true,
	VisibleColor = Color3.fromRGB(255, 255, 0),
	InvisibleColor = Color3.fromRGB(200, 200, 0),
})

local ActorsModule = ReplicatedStorage.Modules.Gameplay:FindFirstChild("Actors")
if ActorsModule then
	local success, Actors = pcall(require, ActorsModule)
	if success and Actors then
		local function onActorCreated(actorInfo)
			if not actorInfo or not actorInfo.Rig then return end
			local actorType = actorInfo.ActorType or ""
			if actorType:find("Killer") then
				killerESP:Add(actorInfo.Rig)
			elseif actorType:find("Survivor") then
				survivorESP:Add(actorInfo.Rig)
			end
		end

		local function onActorDestroyed(actorInfo)
			if not actorInfo or not actorInfo.Rig then return end
			killerESP:Remove(actorInfo.Rig)
			survivorESP:Remove(actorInfo.Rig)
		end

		local function connectSignal(signal, callback)
			if not signal then return end
			if signal.Event then
				signal.Event:Connect(callback)
			elseif signal.Connect then
				signal:Connect(callback)
			end
		end

		connectSignal(Actors.__actorCreated, onActorCreated)
		connectSignal(Actors.__actorDestroyed, onActorDestroyed)

		for _, actorInfo in pairs(Actors.CurrentActors or {}) do
			onActorCreated(actorInfo)
		end
	end
end

local function watchMapFolder(genChams, itemESP)
	local currentConn = {}
	local activeMapFolder = nil

	local function cleanup()
		for _, c in ipairs(currentConn) do c:Disconnect() end
		table.clear(currentConn)
		genChams:Clear()
		itemESP:Clear()
		activeMapFolder = nil
	end

	local function scan(mapFolder)
		if activeMapFolder == mapFolder then return end
		cleanup()
		activeMapFolder = mapFolder

		local function onChildAdded(child)
			if child.Name == "Generator" then
				genChams:Add(child)
			elseif child.Name == "BloxyCola" or child.Name == "Medkit" then
				itemESP:Add(child)
			end
		end

		local function onChildRemoved(child)
			if child.Name == "Generator" then
				genChams:Remove(child)
			elseif child.Name == "BloxyCola" or child.Name == "Medkit" then
				itemESP:Remove(child)
			end
		end

		for _, child in ipairs(mapFolder:GetChildren()) do onChildAdded(child) end
		table.insert(currentConn, mapFolder.ChildAdded:Connect(onChildAdded))
		table.insert(currentConn, mapFolder.ChildRemoved:Connect(onChildRemoved))
	end

	local function checkAndBind()
		local map = Workspace:FindFirstChild("Map")
		if map then
			local ingame = map:FindFirstChild("Ingame")
			if ingame then
				local mapFolder = ingame:FindFirstChild("Map")
				if mapFolder then scan(mapFolder) return true end
			end
		end
		if activeMapFolder ~= nil then cleanup() end
		return false
	end

	task.spawn(function()
		while true do checkAndBind() task.wait(2) end
	end)
end

watchMapFolder(generatorChams, itemESP)

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()

local Window = Rayfield:CreateWindow({
	name = "Nuclide",
	subtitle = "Forsaken - 0.0.1",
	configuration = {
		autoSave = false,
		autoLoad = false,
		fileName = "NuclideForsaken",
	},
})

local KillerTab = Window:CreateTab({ name = "Killer ESP" })
local SurvivorTab = Window:CreateTab({ name = "Survivor ESP" })
local ObjectsTab = Window:CreateTab({ name = "Objects ESP" })
local TasksTab = Window:CreateTab({ name = "Tasks" })
local ExploitsTab = Window:CreateTab({ name = "Exploits" })
local MiscTab = Window:CreateTab({ name = "Misc" })

local killerConfig = {
	Corner = true, Nametag = true, HealthBar = true, Distance = true,
	VisibleColor = Color3.fromRGB(255, 0, 0), InvisibleColor = Color3.fromRGB(150, 0, 0),
	Yourself = false, AdaptWidth = false,
}
killerESP:SetConfig(killerConfig)

KillerTab:CreateToggle({ name = "Enable Killer ESP", flag = "KillerEnabled", value = false, callback = function(Value) killerESP:SetEnabled(Value) end })
KillerTab:CreateToggle({ name = "Yourself", flag = "KillerYourself", value = false, callback = function(Value) killerConfig.Yourself = Value killerESP:SetConfig(killerConfig) end })
KillerTab:CreateToggle({ name = "Corner Box", flag = "KillerCorner", value = true, callback = function(Value) killerConfig.Corner = Value killerESP:SetConfig(killerConfig) end })
KillerTab:CreateToggle({ name = "Nametag", flag = "KillerNametag", value = true, callback = function(Value) killerConfig.Nametag = Value killerESP:SetConfig(killerConfig) end })
KillerTab:CreateToggle({ name = "Health Bar", flag = "KillerHealthBar", value = true, callback = function(Value) killerConfig.HealthBar = Value killerESP:SetConfig(killerConfig) end })
KillerTab:CreateToggle({ name = "Distance", flag = "KillerDistance", value = true, callback = function(Value) killerConfig.Distance = Value killerESP:SetConfig(killerConfig) end })
KillerTab:CreateColorPicker({ name = "Visible Color", flag = "KillerVisColor", color = Color3.fromRGB(255, 0, 0), callback = function(Value) killerConfig.VisibleColor = Value killerESP:SetConfig(killerConfig) end })
KillerTab:CreateColorPicker({ name = "Invisible Color", flag = "KillerInvisColor", color = Color3.fromRGB(150, 0, 0), callback = function(Value) killerConfig.InvisibleColor = Value killerESP:SetConfig(killerConfig) end })

local survivorConfig = {
	Corner = true, Nametag = true, HealthBar = true, Distance = true,
	VisibleColor = Color3.fromRGB(0, 255, 0), InvisibleColor = Color3.fromRGB(0, 150, 0),
	Yourself = false, AdaptWidth = false,
}
survivorESP:SetConfig(survivorConfig)

SurvivorTab:CreateToggle({ name = "Enable Survivor ESP", flag = "SurvivorEnabled", value = false, callback = function(Value) survivorESP:SetEnabled(Value) end })
SurvivorTab:CreateToggle({ name = "Yourself", flag = "SurvivorYourself", value = false, callback = function(Value) survivorConfig.Yourself = Value survivorESP:SetConfig(survivorConfig) end })
SurvivorTab:CreateToggle({ name = "Corner Box", flag = "SurvivorCorner", value = true, callback = function(Value) survivorConfig.Corner = Value survivorESP:SetConfig(survivorConfig) end })
SurvivorTab:CreateToggle({ name = "Nametag", flag = "SurvivorNametag", value = true, callback = function(Value) survivorConfig.Nametag = Value survivorESP:SetConfig(survivorConfig) end })
SurvivorTab:CreateToggle({ name = "Health Bar", flag = "SurvivorHealthBar", value = true, callback = function(Value) survivorConfig.HealthBar = Value survivorESP:SetConfig(survivorConfig) end })
SurvivorTab:CreateToggle({ name = "Distance", flag = "SurvivorDistance", value = true, callback = function(Value) survivorConfig.Distance = Value survivorESP:SetConfig(survivorConfig) end })
SurvivorTab:CreateColorPicker({ name = "Visible Color", flag = "SurvivorVisColor", color = Color3.fromRGB(0, 255, 0), callback = function(Value) survivorConfig.VisibleColor = Value survivorESP:SetConfig(survivorConfig) end })
SurvivorTab:CreateColorPicker({ name = "Invisible Color", flag = "SurvivorInvisColor", color = Color3.fromRGB(0, 150, 0), callback = function(Value) survivorConfig.InvisibleColor = Value survivorESP:SetConfig(survivorConfig) end })

ObjectsTab:CreateToggle({ name = "Generator Chams", flag = "GeneratorChamsEnabled", value = false, callback = function(Value) generatorChams:SetEnabled(Value) end })
ObjectsTab:CreateToggle({ name = "Items Nametag", flag = "ItemsNametagEnabled", value = false, callback = function(Value) itemESP:SetEnabled(Value) end })
ObjectsTab:CreateColorPicker({ name = "Generator Color", flag = "GeneratorColor", color = Color3.fromRGB(0, 255, 255), callback = function(Value) generatorChams:SetConfig({ VisibleColor = Value, InvisibleColor = Value }) end })
ObjectsTab:CreateColorPicker({ name = "Items Visible Color", flag = "ItemsVisColor", color = Color3.fromRGB(255, 255, 0), callback = function(Value) itemESP:SetConfig({ VisibleColor = Value }) end })
ObjectsTab:CreateColorPicker({ name = "Items Invisible Color", flag = "ItemsInvisColor", color = Color3.fromRGB(200, 200, 0), callback = function(Value) itemESP:SetConfig({ InvisibleColor = Value }) end })

TasksTab:CreateSection("Settings")
TasksTab:CreateToggle({
	name = "Auto Generator", flag = "AutoGenEnabled", value = false,
	callback = function(Value)
		autoGen:SetEnabled(Value)
		if Value then
			local diag = autoGen:Diagnostics()
			local msg = string.format("Map: %s | Generators: %d\nEnter a generator manually to start auto-repair.", diag.mapLoaded and "OK" or "NOT LOADED", diag.generatorCount)
			Window:Notify({ title = "Auto Generator", content = msg, duration = 5 })
		end
	end,
})
TasksTab:CreateSlider({ name = "Tick delay", flag = "AutoGenDelay", range = {1, 2000}, increment = 1, suffix = "ms", value = 100, callback = function(Value) autoGen:SetDelay(Value) end })
TasksTab:CreateButton({ name = "Reset Statistics", callback = function() autoGen:ResetStats() end })
TasksTab:CreateButton({
	name = "Diagnostics",
	callback = function()
		local diag = autoGen:Diagnostics()
		local msg = string.format("Map: %s\nGenerators on map: %d\nIs player repairing: %s\nAuto-repair target: %s\nProgress: %s%%\nStatus: %s",
			diag.mapLoaded and "Loaded" or "Not loaded", diag.generatorCount, diag.inside and "Yes" or "No",
			diag.hasTarget and "Yes" or "No", diag.progress ~= nil and tostring(diag.progress) or "-", diag.status)
		Window:Notify({ title = "Diagnostics", content = msg, duration = 8 })
	end,
})

TasksTab:CreateSection("Progress")
local progressRow = TasksTab:CreateGroup()
local pcol1 = progressRow:CreateGroup({ direction = "column" })
local pcol2 = progressRow:CreateGroup({ direction = "column" })
local stagesStat = pcol1:CreateStat({ name = "Stages completed", value = 0, compact = true })
local generatorsStat = pcol2:CreateStat({ name = "Generators done", value = 0, compact = true })

task.spawn(function()
	while true do
		task.wait(0.25)
		if not autoGen then break end
		local stats = autoGen:GetStats()
		stagesStat:Set(stats.stagesCompleted)
		generatorsStat:Set(stats.generatorsCompleted)
	end
end)

ExploitsTab:CreateSection("1. Stamina")
ExploitsTab:CreateToggle({ name = "Infinite Stamina", flag = "InfiniteStamina", value = false, callback = function(Value) exploits:SetInfiniteStamina(Value) end })

ExploitsTab:CreateSection("2. Movement")
ExploitsTab:CreateSlider({ name = "Speed Multiplier", flag = "SpeedMultiplier", range = {1.0, 5.0}, increment = 0.1, suffix = "x", value = 1.0, callback = function(Value) exploits:SetSpeedMultiplier(Value) end })
ExploitsTab:CreateSlider({ name = "FOV Multiplier", flag = "FOVMultiplier", range = {1.0, 2.0}, increment = 0.1, suffix = "x", value = 1.0, callback = function(Value) exploits:SetFOVMultiplier(Value) end })

ExploitsTab:CreateSection("3. Emotes")
ExploitsTab:CreateToggle({ name = "Emote Walk", flag = "EmoteWalk", value = false, callback = function(Value) exploits:SetEmoteWalk(Value) end })
ExploitsTab:CreateToggle({ name = "Anti-Interrupt Emotes", flag = "AntiInterruptEmotes", value = false, callback = function(Value) exploits:SetAntiInterruptEmotes(Value) end })

ExploitsTab:CreateSection("4. Network")
ExploitsTab:CreateToggle({
	name = "Desync Position",
	flag = "DesyncEnabled",
	value = false,
	callback = function(Value)
		exploits:SetDesync(Value)
	end,
})
ExploitsTab:CreateButton({
	name = "Update Freeze Point",
	callback = function()
		if exploits.DesyncEnabled then
			local updated = exploits:UpdateFrozenPosition()
			Window:Notify({ title = "Desync", content = updated and "Position updated" or "No character", duration = 3 })
		end
	end,
})

local currentConfigName = "NuclideForsaken"
MiscTab:CreateInput({ name = "Config File Name", placeholderText = "NuclideForsaken", callback = function(Text) if Text and Text ~= "" then currentConfigName = Text end end })
MiscTab:CreateButton({ name = "Save Config", callback = function() if Window:Save(currentConfigName) then Window:Notify({ title = "Config System", content = "Saved: " .. currentConfigName }) else Window:Notify({ title = "Config System", content = "Failed to save configuration!" }) end end })
MiscTab:CreateButton({ name = "Load Config", callback = function() if Window:Load(currentConfigName) then Window:Notify({ title = "Config System", content = "Loaded: " .. currentConfigName }) else Window:Notify({ title = "Config System", content = "Failed to load configuration!" }) end end })
MiscTab:CreateButton({ name = "Unload", callback = function() autoGen:Stop() espInstance:Destroy() chamsInstance:Destroy() exploits:Destroy() Window:Unload() end })