local NUCLIDE_ESP_URL = "https://raw.githubusercontent.com/T1REI/Nuclide/refs/heads/main/nucesp.lua"
local NUCLIDE_CHAMS_URL = "https://raw.githubusercontent.com/T1REI/Nuclide/refs/heads/main/nucchams.lua"

local function resolveESP()
	local esp = getgenv and getgenv().NuclideESP or shared.NuclideESP
	if not esp then
		local ok, loader = pcall(loadstring, game:HttpGet(NUCLIDE_ESP_URL))
		if ok and type(loader) == "function" then
			pcall(loader)
			esp = getgenv and getgenv().NuclideESP or shared.NuclideESP
		end
	end
	return esp
end

local function resolveChams()
	local ch = getgenv and getgenv().NuclideChams or shared.NuclideChams
	if not ch then
		local ok, loader = pcall(loadstring, game:HttpGet(NUCLIDE_CHAMS_URL))
		if ok and type(loader) == "function" then
			pcall(loader)
			ch = getgenv and getgenv().NuclideChams or shared.NuclideChams
		end
	end
	return ch
end

local ESP = resolveESP()
local Chams = resolveChams()

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
	Name = "Nuclide Modules",
	LoadingTitle = "Nuclide",
	LoadingSubtitle = "A new optimized experience.",
	KeySystem = false,
})

local EspTab = Window:CreateTab("ESP")
local ChamsTab = Window:CreateTab("Chams")
local MiscTab = Window:CreateTab("Misc")

-- ESP
EspTab:CreateToggle({
	Name = "ESP",
	CurrentValue = ESP and ESP:IsEnabled() or false,
	Callback = function(Value)
		if not ESP then return end
		if Value then ESP:Enable() else ESP:Disable() end
	end,
})

EspTab:CreateToggle({
	Name = "Yourself",
	CurrentValue = ESP and ESP.Config.Yourself or false,
	Callback = function(Value)
		if not ESP then return end
		ESP:SetConfig({ Yourself = Value })
	end,
})

EspTab:CreateToggle({
	Name = "Dead Check",
	CurrentValue = ESP and ESP.Config.DeadCheck or true,
	Callback = function(Value)
		if not ESP then return end
		ESP:SetConfig({ DeadCheck = Value })
	end,
})

EspTab:CreateColorPicker({
	Name = "Visible Color",
	Color = ESP and ESP.Config.VisibleColor or Color3.fromRGB(255, 255, 255),
	Callback = function(Value)
		if not ESP then return end
		ESP:SetConfig({ VisibleColor = Value })
	end,
})

EspTab:CreateColorPicker({
	Name = "Invisible Color",
	Color = ESP and ESP.Config.InvisibleColor or Color3.fromRGB(255, 80, 80),
	Callback = function(Value)
		if not ESP then return end
		ESP:SetConfig({ InvisibleColor = Value })
	end,
})

EspTab:CreateDivider()

EspTab:CreateToggle({
	Name = "Corner Box",
	CurrentValue = ESP and ESP.Config.Corner or true,
	Callback = function(Value)
		if not ESP then return end
		ESP:SetConfig({ Corner = Value })
	end,
})

EspTab:CreateSlider({
	Name = "Толщина",
	Range = { 1, 5 },
	Increment = 1,
	Suffix = "px",
	CurrentValue = ESP and ESP.Config.Thickness or 1,
	Callback = function(Value)
		if not ESP then return end
		ESP:SetConfig({ Thickness = Value })
	end,
})

EspTab:CreateSlider({
	Name = "Прозрачность",
	Range = { 0, 1 },
	Increment = 0.05,
	Suffix = "",
	CurrentValue = ESP and ESP.Config.Transparency or 0,
	Callback = function(Value)
		if not ESP then return end
		ESP:SetConfig({ Transparency = Value })
	end,
})

EspTab:CreateDivider()

EspTab:CreateToggle({
	Name = "Health Bar",
	CurrentValue = ESP and ESP.Config.HealthBar or true,
	Callback = function(Value)
		if not ESP then return end
		ESP:SetConfig({ HealthBar = Value })
	end,
})

EspTab:CreateToggle({
	Name = "Health Text",
	CurrentValue = ESP and ESP.Config.HealthText or true,
	Callback = function(Value)
		if not ESP then return end
		ESP:SetConfig({ HealthText = Value })
	end,
})

EspTab:CreateToggle({
	Name = "Nametag",
	CurrentValue = ESP and ESP.Config.Nametag or true,
	Callback = function(Value)
		if not ESP then return end
		ESP:SetConfig({ Nametag = Value })
	end,
})

EspTab:CreateInput({
	Name = "Custom Nametag",
	CurrentValue = "",
	PlaceholderText = "оставь пусто = DisplayName",
	RemoveTextAfterFocusLost = false,
	Callback = function(Text)
		if not ESP then return end
		if Text == "" then
			ESP:ClearAllNametags()
		else
			for _, pl in ipairs(game.Players:GetPlayers()) do
				if pl ~= game.Players.LocalPlayer then
					ESP:SetNametag(pl, Text)
				end
			end
		end
	end,
})

EspTab:CreateInput({
	Name = "Nametag Formatter (Lua)",
	CurrentValue = "",
	PlaceholderText = "return function(pl,model,dist,hp,max,base) return base end",
	RemoveTextAfterFocusLost = false,
	Callback = function(Text)
		if not ESP then return end
		if Text == "" then
			ESP:SetConfig({ NametagFormatter = nil })
			return
		end
		local ok, fn = pcall(loadstring, Text)
		if ok and type(fn) == "function" then
			local ok2, inner = pcall(fn)
			if ok2 and type(inner) == "function" then
				ESP:SetConfig({ NametagFormatter = inner })
			else
				ESP:SetConfig({ NametagFormatter = fn })
			end
		end
	end,
})

EspTab:CreateSlider({
	Name = "Nametag Size",
	Range = { 8, 24 },
	Increment = 1,
	Suffix = "px",
	CurrentValue = ESP and (ESP.Config.NametagSize or 13) or 13,
	Callback = function(Value)
		if not ESP then return end
		ESP:SetConfig({ NametagSize = Value })
	end,
})

EspTab:CreateToggle({
	Name = "Distance",
	CurrentValue = ESP and ESP.Config.Distance or true,
	Callback = function(Value)
		if not ESP then return end
		ESP:SetConfig({ Distance = Value })
	end,
})

-- CHAMS
ChamsTab:CreateToggle({
	Name = "Chams",
	CurrentValue = Chams and Chams:IsEnabled() or false,
	Callback = function(Value)
		if not Chams then return end
		if Value then Chams:Enable() else Chams:Disable() end
	end,
})

ChamsTab:CreateToggle({
	Name = "Yourself",
	CurrentValue = Chams and Chams.Config.Yourself or false,
	Callback = function(Value)
		if not Chams then return end
		Chams:SetConfig({ Yourself = Value })
	end,
})

ChamsTab:CreateToggle({
	Name = "Dead Check",
	CurrentValue = Chams and Chams.Config.DeadCheck or true,
	Callback = function(Value)
		if not Chams then return end
		Chams:SetConfig({ DeadCheck = Value })
	end,
})

ChamsTab:CreateToggle({
	Name = "Team Check",
	CurrentValue = Chams and Chams.Config.TeamCheck or false,
	Callback = function(Value)
		if not Chams then return end
		Chams:SetConfig({ TeamCheck = Value })
	end,
})

ChamsTab:CreateColorPicker({
	Name = "Visible Color",
	Color = Chams and Chams.Config.VisibleColor or Color3.fromRGB(0, 255, 120),
	Callback = function(Value)
		if not Chams then return end
		Chams:SetConfig({ VisibleColor = Value })
	end,
})

ChamsTab:CreateColorPicker({
	Name = "Invisible Color",
	Color = Chams and Chams.Config.InvisibleColor or Color3.fromRGB(255, 80, 80),
	Callback = function(Value)
		if not Chams then return end
		Chams:SetConfig({ InvisibleColor = Value })
	end,
})

ChamsTab:CreateDivider()

ChamsTab:CreateSlider({
	Name = "Fill Transparency",
	Range = { 0, 1 },
	Increment = 0.05,
	Suffix = "",
	CurrentValue = Chams and Chams.Config.FillTransparency or 0.5,
	Callback = function(Value)
		if not Chams then return end
		Chams:SetConfig({ FillTransparency = Value })
	end,
})

ChamsTab:CreateSlider({
	Name = "Outline Transparency",
	Range = { 0, 1 },
	Increment = 0.05,
	Suffix = "",
	CurrentValue = Chams and Chams.Config.OutlineTransparency or 0,
	Callback = function(Value)
		if not Chams then return end
		Chams:SetConfig({ OutlineTransparency = Value })
	end,
})

ChamsTab:CreateSlider({
	Name = "Max Distance",
	Range = { 100, 5000 },
	Increment = 100,
	Suffix = "stud",
	CurrentValue = Chams and Chams.Config.MaxDistance or 5000,
	Callback = function(Value)
		if not Chams then return end
		Chams:SetConfig({ MaxDistance = Value })
	end,
})

ChamsTab:CreateDivider()

ChamsTab:CreateButton({
	Name = "Track All NPCs (applies to all objects)",
	Callback = function()
		if not Chams then return end
		local count = 0
		for _, m in ipairs(workspace:GetDescendants()) do
			if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") and not game.Players:GetPlayerFromCharacter(m) then
				Chams:Track(m)
				count = count + 1
				if count >= 100 then break end
			end
		end
	end,
})

ChamsTab:CreateButton({
	Name = "Clear Tracked Objects (keep players)",
	Callback = function()
		if not Chams then return end
		for key, _ in pairs(Chams.Targets) do
			if typeof(key) ~= "Instance" or not key:IsA("Player") then
				Chams:Untrack(key)
			end
		end
	end,
})

-- MISC
MiscTab:CreateButton({
	Name = "Unload",
	Callback = function()
		if ESP then ESP:Unload() end
		if Chams then Chams:Unload() end
		Rayfield:Destroy()
	end,
})

if not ESP then
	Rayfield:Notify({
		Title = "Nuclide",
		Content = "nucesp.lua не загружен — настройки не будут применяться.",
		Duration = 6,
	})
end

if not Chams then
	Rayfield:Notify({
		Title = "Nuclide",
		Content = "nucchams.lua не загружен — Chams не работает.",
		Duration = 6,
	})
end
