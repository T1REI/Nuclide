local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
	Name = "Nuclide Modules",
	LoadingTitle = "Nuclide",
	LoadingSubtitle = "A new optimized experience.",
	ConfigurationSaving = {
		Enabled = true,
		FolderName = "Nuclide",
		FileName = "Settings"
	},
	KeySystem = false
})

local AboutTab = Window:CreateTab("About", 4483362458)

AboutTab:CreateParagraph({
	Title = "Nuclide Modules",
	Content = "One of the best."
})
