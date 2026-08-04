local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ESPClass = loadstring(game:HttpGet("https://raw.githubusercontent.com/T1REI/Nuclide/refs/heads/main/Modules/ESP.lua"))()
local ChamsClass = loadstring(game:HttpGet("https://raw.githubusercontent.com/T1REI/Nuclide/refs/heads/main/Modules/Chams.lua"))()

local espInstance = ESPClass.new()
espInstance:Start()

local chamsInstance = ChamsClass.new()
chamsInstance:Start()

local killerESP = espInstance:CreateGroup("Killers")
local survivorESP = espInstance:CreateGroup("Survivors")

local generatorESP = espInstance:CreateGroup("Generators")
local generatorChams = chamsInstance:CreateGroup("Generators")

local itemESP = espInstance:CreateGroup("Items")
local itemChams = chamsInstance:CreateGroup("Items")

generatorESP:SetConfig({
	Corner = false,
	HealthBar = false,
	Distance = false,
	Nametag = true,
	VisibleColor = Color3.fromRGB(0, 255, 255),
	InvisibleColor = Color3.fromRGB(0, 255, 255),
})

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
	InvisibleColor = Color3.fromRGB(255, 255, 0),
})

itemChams:SetConfig({
	VisibleColor = Color3.fromRGB(255, 255, 0),
	InvisibleColor = Color3.fromRGB(255, 255, 0),
})

local function watchPlayersFolder(folderName, espGroup)
	local players = Workspace:WaitForChild("Players", 10)
	if not players then return end

	local currentFolder = players:FindFirstChild(folderName)
	local function bind(folder)
		espGroup:Clear()
		if folder then
			espGroup:TrackFolder(folder)
		end
	end

	if currentFolder then
		bind(currentFolder)
	end

	players.ChildAdded:Connect(function(child)
		if child.Name == folderName then
			bind(child)
		end
	end)
	players.ChildRemoved:Connect(function(child)
		if child.Name == folderName then
			espGroup:Clear()
		end
	end)
end

watchPlayersFolder("Killers", killerESP)
watchPlayersFolder("Survivors", survivorESP)

local function watchMapFolder(genESP, genChams, itemESP, itemChams)
	local currentConn = {}

	local function cleanup()
		for _, c in ipairs(currentConn) do
			c:Disconnect()
		end
		table.clear(currentConn)
		genESP:Clear()
		genChams:Clear()
		itemESP:Clear()
		itemChams:Clear()
	end

	local function scan(mapFolder)
		cleanup()

		local function onChildAdded(child)
			if child.Name == "Generator" then
				genESP:Add(child)
				genChams:Add(child)
			elseif child.Name == "BloxyCola" or child.Name == "Medkit" then
				itemESP:Add(child)
				itemChams:Add(child)
			end
		end

		local function onChildRemoved(child)
			if child.Name == "Generator" then
				genESP:Remove(child)
				genChams:Remove(child)
			elseif child.Name == "BloxyCola" or child.Name == "Medkit" then
				itemESP:Remove(child)
				itemChams:Remove(child)
			end
		end

		for _, child in ipairs(mapFolder:GetChildren()) do
			onChildAdded(child)
		end

		table.insert(currentConn, mapFolder.ChildAdded:Connect(onChildAdded))
		table.insert(currentConn, mapFolder.ChildRemoved:Connect(onChildRemoved))
	end

	local function checkAndBind()
		local map = Workspace:FindFirstChild("Map")
		if map then
			local ingame = map:FindFirstChild("Ingame")
			if ingame then
				local mapFolder = ingame:FindFirstChild("Map")
				if mapFolder then
					scan(mapFolder)
					return true
				end
			end
		end
		cleanup()
		return false
	end

	task.spawn(function()
		while true do
			checkAndBind()
			task.wait(2)
		end
	end)
end

watchMapFolder(generatorESP, generatorChams, itemESP, itemChams)

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
	Name = "Nuclide",
	LoadingTitle = "Nuclide - Forsaken",
	LoadingSubtitle = "The ultimate custom experience.",
	KeySystem = false,
})

local KillerTab = Window:CreateTab("Killer ESP")
local SurvivorTab = Window:CreateTab("Survivor ESP")
local ObjectsTab = Window:CreateTab("Objects ESP")
local MiscTab = Window:CreateTab("Misc")

local killerConfig = {
	Corner = true,
	Nametag = true,
	HealthBar = true,
	Distance = true,
	VisibleColor = Color3.fromRGB(255, 0, 0),
	InvisibleColor = Color3.fromRGB(150, 0, 0),
}
killerESP:SetConfig(killerConfig)

KillerTab:CreateToggle({
	Name = "Enable Killer ESP",
	CurrentValue = false,
	Callback = function(Value)
		killerESP:SetEnabled(Value)
	end,
})

KillerTab:CreateToggle({
	Name = "Corner Box",
	CurrentValue = true,
	Callback = function(Value)
		killerConfig.Corner = Value
		killerESP:SetConfig(killerConfig)
	end,
})

KillerTab:CreateToggle({
	Name = "Nametag",
	CurrentValue = true,
	Callback = function(Value)
		killerConfig.Nametag = Value
		killerESP:SetConfig(killerConfig)
	end,
})

KillerTab:CreateToggle({
	Name = "Health Bar",
	CurrentValue = true,
	Callback = function(Value)
		killerConfig.HealthBar = Value
		killerESP:SetConfig(killerConfig)
	end,
})

KillerTab:CreateToggle({
	Name = "Distance",
	CurrentValue = true,
	Callback = function(Value)
		killerConfig.Distance = Value
		killerESP:SetConfig(killerConfig)
	end,
})

KillerTab:CreateColorPicker({
	Name = "Visible Color",
	Color = Color3.fromRGB(255, 0, 0),
	Callback = function(Value)
		killerConfig.VisibleColor = Value
		killerESP:SetConfig(killerConfig)
	end,
})

KillerTab:CreateColorPicker({
	Name = "Invisible Color",
	Color = Color3.fromRGB(150, 0, 0),
	Callback = function(Value)
		killerConfig.InvisibleColor = Value
		killerESP:SetConfig(killerConfig)
	end,
})

local survivorConfig = {
	Corner = true,
	Nametag = true,
	HealthBar = true,
	Distance = true,
	VisibleColor = Color3.fromRGB(0, 255, 0),
	InvisibleColor = Color3.fromRGB(0, 150, 0),
}
survivorESP:SetConfig(survivorConfig)

SurvivorTab:CreateToggle({
	Name = "Enable Survivor ESP",
	CurrentValue = false,
	Callback = function(Value)
		survivorESP:SetEnabled(Value)
	end,
})

SurvivorTab:CreateToggle({
	Name = "Corner Box",
	CurrentValue = true,
	Callback = function(Value)
		survivorConfig.Corner = Value
		survivorESP:SetConfig(survivorConfig)
	end,
})

SurvivorTab:CreateToggle({
	Name = "Nametag",
	CurrentValue = true,
	Callback = function(Value)
		survivorConfig.Nametag = Value
		survivorESP:SetConfig(survivorConfig)
	end,
})

SurvivorTab:CreateToggle({
	Name = "Health Bar",
	CurrentValue = true,
	Callback = function(Value)
		survivorConfig.HealthBar = Value
		survivorESP:SetConfig(survivorConfig)
	end,
})

SurvivorTab:CreateToggle({
	Name = "Distance",
	CurrentValue = true,
	Callback = function(Value)
		survivorConfig.Distance = Value
		survivorESP:SetConfig(survivorConfig)
	end,
})

SurvivorTab:CreateColorPicker({
	Name = "Visible Color",
	Color = Color3.fromRGB(0, 255, 0),
	Callback = function(Value)
		survivorConfig.VisibleColor = Value
		survivorESP:SetConfig(survivorConfig)
	end,
})

SurvivorTab:CreateColorPicker({
	Name = "Invisible Color",
	Color = Color3.fromRGB(0, 150, 0),
	Callback = function(Value)
		survivorConfig.InvisibleColor = Value
		survivorESP:SetConfig(survivorConfig)
	end,
})

ObjectsTab:CreateToggle({
	Name = "Generator Nametag",
	CurrentValue = false,
	Callback = function(Value)
		generatorESP:SetEnabled(Value)
	end,
})

ObjectsTab:CreateToggle({
	Name = "Generator Chams",
	CurrentValue = false,
	Callback = function(Value)
		generatorChams:SetEnabled(Value)
	end,
})

ObjectsTab:CreateToggle({
	Name = "Items Nametag",
	CurrentValue = false,
	Callback = function(Value)
		itemESP:SetEnabled(Value)
	end,
})

ObjectsTab:CreateToggle({
	Name = "Items Chams",
	CurrentValue = false,
	Callback = function(Value)
		itemChams:SetEnabled(Value)
	end,
})

ObjectsTab:CreateColorPicker({
	Name = "Generator Color",
	Color = Color3.fromRGB(0, 255, 255),
	Callback = function(Value)
		generatorESP:SetConfig({ VisibleColor = Value, InvisibleColor = Value })
		generatorChams:SetConfig({ VisibleColor = Value, InvisibleColor = Value })
	end,
})

ObjectsTab:CreateColorPicker({
	Name = "Items Color",
	Color = Color3.fromRGB(255, 255, 0),
	Callback = function(Value)
		itemESP:SetConfig({ VisibleColor = Value, InvisibleColor = Value })
		itemChams:SetConfig({ VisibleColor = Value, InvisibleColor = Value })
	end,
})

MiscTab:CreateButton({
	Name = "Unload",
	Callback = function()
		espInstance:Destroy()
		chamsInstance:Destroy()
		Rayfield:Destroy()
	end,
})
