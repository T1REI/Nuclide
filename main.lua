local NUCLIDE_ESP_URL = "https://raw.githubusercontent.com/T1REI/Nuclide/refs/heads/main/nucesp.lua"

local function resolveESP()
	local esp = getgenv and getgenv().NuclideESP or shared.NuclideESP
	if not esp then
		local ok, loader = pcall(loadstring, game:HttpGet(NUCLIDE_ESP_URL))
		if ok and type(loader) == "function" then
			loader()
			esp = getgenv and getgenv().NuclideESP or shared.NuclideESP
		end
	end
	return esp
end

local ESP = resolveESP()

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
	Name = "Nuclide Modules",
	LoadingTitle = "Nuclide",
	LoadingSubtitle = "A new optimized experience.",
	KeySystem = false,
})

local EspTab = Window:CreateTab("ESP")
local MiscTab = Window:CreateTab("Misc")

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
	CurrentValue = ESP and ESP.Config.Thickness or 2,
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

EspTab:CreateToggle({
	Name = "Distance",
	CurrentValue = ESP and ESP.Config.Distance or true,
	Callback = function(Value)
		if not ESP then return end
		ESP:SetConfig({ Distance = Value })
	end,
})

MiscTab:CreateButton({
	Name = "Unload",
	Callback = function()
		if ESP then
			ESP:Unload()
		end
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
