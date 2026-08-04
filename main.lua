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

EspTab:CreateToggle({
	Name = "ESP",
	CurrentValue = ESP and ESP:IsEnabled() or false,
	Callback = function(Value)
		if not ESP then
			return
		end
		if Value then
			ESP:Enable()
		else
			ESP:Disable()
		end
	end,
})

EspTab:CreateColorPicker({
	Name = "ESP Color",
	Color = ESP and ESP.Config.Color or Color3.fromRGB(255, 255, 255),
	Callback = function(Value)
		if not ESP then
			return
		end
		ESP:SetConfig({ Color = Value })
	end,
})

EspTab:CreateToggle({
	Name = "Corner Box",
	CurrentValue = true,
	Callback = function(Value)
		if not ESP then
			return
		end
		ESP:SetConfig({ Corner = Value })
	end,
})

EspTab:CreateSlider({
	Name = "Толщина",
	Range = { 1, 5 },
	Increment = 1,
	Suffix = "px",
	CurrentValue = 2,
	Callback = function(Value)
		if not ESP then
			return
		end
		ESP:SetConfig({ Thickness = Value })
	end,
})

EspTab:CreateSlider({
	Name = "Прозрачность",
	Range = { 0, 1 },
	Increment = 0.05,
	Suffix = "",
	CurrentValue = 0,
	Callback = function(Value)
		if not ESP then
			return
		end
		ESP:SetConfig({ Transparency = Value })
	end,
})

if not ESP then
	Rayfield:Notify({
		Title = "Nuclide",
		Content = "nucesp.lua не загружен — настройки не будут применяться.",
		Duration = 6,
	})
end
