local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local CORNER_OFFSETS = {
	{ -1, -1, -1 }, { 1, -1, -1 }, { 1, 1, -1 }, { -1, 1, -1 },
	{ -1, -1, 1 }, { 1, -1, 1 }, { 1, 1, 1 }, { -1, 1, 1 },
}

local DEFAULT_CONFIG = {
	Enabled = false,
	Color = Color3.fromRGB(255, 255, 255),
	Corner = true,
	Thickness = 2,
	Transparency = 0,
	UpdateInterval = 0.033,
	MaxDistance = 5000,
	TeamCheck = false,
	CornerLengthFraction = 0.2,
}

local Target = {}
Target.__index = Target

function Target.new(manager, key, isPlayer)
	local self = setmetatable({}, Target)
	self.Manager = manager
	self.Key = key
	self.Player = isPlayer and key or nil
	self.Model = nil
	self.RootPart = nil
	self.CachedCFrame = nil
	self.Size = nil
	self.MeasureAt = 0
	self.Visible = false
	self.Lines = {}
	self.Connections = {}
	if Drawing then
		for i = 1, 8 do
			local line = Drawing.new("Line")
			line.Color = manager.Config.Color
			line.Thickness = manager.Config.Thickness
			line.Transparency = manager.Config.Transparency
			line.Visible = false
			self.Lines[i] = line
		end
	end
	if self.Player then
		local player = self.Player
		table.insert(self.Connections, player.CharacterAdded:Connect(function(character)
			self:BindCharacter(character)
		end))
		table.insert(self.Connections, player.CharacterRemoving:Connect(function()
			self:Unbind()
		end))
		if player.Character then
			task.spawn(self.BindCharacter, self, player.Character)
		end
	else
		self:BindModel(key)
	end
	return self
end

function Target:BindCharacter(character)
	self.Model = character
	local rootPart = character:WaitForChild("HumanoidRootPart", 15)
	if rootPart and character == self.Model then
		self.RootPart = rootPart
		self:_measure()
	end
end

function Target:BindModel(model)
	self.Model = model
	self.RootPart = model.PrimaryPart
		or model:FindFirstChild("HumanoidRootPart")
		or model:FindFirstChildOfClass("BasePart")
	self:_measure()
end

function Target:Unbind()
	self.Model = nil
	self.RootPart = nil
	self.CachedCFrame = nil
	self:SetVisible(false)
end

function Target:_measure()
	local model = self.Model
	if not model then
		return
	end
	local cf, size = model:GetBoundingBox()
	if size and size.Magnitude > 0 then
		self.Size = size
		if not self.RootPart then
			self.CachedCFrame = cf
		end
	end
end

function Target:Update(camera)
	local config = self.Manager.Config
	local model = self.Model
	if not model then
		self:SetVisible(false)
		return
	end
	if model.Parent == nil then
		self.Manager:_removeTarget(self)
		return
	end
	if not self.Player then
		local now = os.clock()
		if now >= self.MeasureAt then
			self:_measure()
			self.MeasureAt = now + self.Manager.MeasureInterval
		end
	end
	local cf = self.RootPart and self.RootPart.CFrame or self.CachedCFrame
	if not cf or not self.Size then
		self:SetVisible(false)
		return
	end
	if self.Player and LocalPlayer and config.TeamCheck
		and self.Player.Team == LocalPlayer.Team then
		self:SetVisible(false)
		return
	end
	local origin = cf.Position
	local distance = (camera.CFrame.Position - origin).Magnitude
	if distance > config.MaxDistance then
		self:SetVisible(false)
		return
	end
	local center, onScreen = camera:WorldToViewportPoint(origin)
	if not onScreen or center.Z <= 0 then
		self:SetVisible(false)
		return
	end

	local half = self.Size * 0.5
	local right = cf.RightVector * half.X
	local up = cf.UpVector * half.Y
	local look = cf.LookVector * half.Z

	local minX, minY = math.huge, math.huge
	local maxX, maxY = -math.huge, -math.huge
	local anyFront = false

	for i = 1, 8 do
		local o = CORNER_OFFSETS[i]
		local point = camera:WorldToViewportPoint(Vector3.new(
			origin.X + right.X * o[1] + up.X * o[2] + look.X * o[3],
			origin.Y + right.Y * o[1] + up.Y * o[2] + look.Y * o[3],
			origin.Z + right.Z * o[1] + up.Z * o[2] + look.Z * o[3]
		))
		if point.Z > 0 then
			anyFront = true
			local px, py = point.X, point.Y
			if px < minX then minX = px end
			if px > maxX then maxX = px end
			if py < minY then minY = py end
			if py > maxY then maxY = py end
		end
	end

	if not anyFront then
		self:SetVisible(false)
		return
	end

	local viewport = camera.ViewportSize
	if maxX < 0 or minX > viewport.X or maxY < 0 or minY > viewport.Y then
		self:SetVisible(false)
		return
	end

	if not config.Corner or not Drawing then
		self:SetVisible(false)
		return
	end

	local width = maxX - minX
	local height = maxY - minY
	local length = math.clamp(math.min(width, height) * config.CornerLengthFraction, 6, 60)
	local lines = self.Lines

	lines[1].From = Vector2.new(minX, minY)
	lines[1].To = Vector2.new(minX + length, minY)
	lines[2].From = Vector2.new(minX, minY)
	lines[2].To = Vector2.new(minX, minY + length)
	lines[3].From = Vector2.new(maxX, minY)
	lines[3].To = Vector2.new(maxX - length, minY)
	lines[4].From = Vector2.new(maxX, minY)
	lines[4].To = Vector2.new(maxX, minY + length)
	lines[5].From = Vector2.new(maxX, maxY)
	lines[5].To = Vector2.new(maxX - length, maxY)
	lines[6].From = Vector2.new(maxX, maxY)
	lines[6].To = Vector2.new(maxX, maxY - length)
	lines[7].From = Vector2.new(minX, maxY)
	lines[7].To = Vector2.new(minX + length, maxY)
	lines[8].From = Vector2.new(minX, maxY)
	lines[8].To = Vector2.new(minX, maxY - length)

	self:SetVisible(true)
end

function Target:SetVisible(visible)
	self.Visible = visible
	self:_syncVisible()
end

function Target:_syncVisible()
	if not Drawing then
		return
	end
	local show = self.Visible and self.Manager.Config.Enabled and self.Manager.Config.Corner
	for i = 1, 8 do
		self.Lines[i].Visible = show
	end
end

function Target:ApplyConfig()
	if not Drawing then
		return
	end
	local config = self.Manager.Config
	for i = 1, 8 do
		local line = self.Lines[i]
		line.Color = config.Color
		line.Thickness = config.Thickness
		line.Transparency = config.Transparency
	end
	self:_syncVisible()
end

function Target:Destroy()
	for _, connection in ipairs(self.Connections) do
		connection:Disconnect()
	end
	table.clear(self.Connections)
	if Drawing then
		for i = 1, 8 do
			self.Lines[i]:Remove()
		end
	end
	table.clear(self.Lines)
end

local NuclideESP = {}
NuclideESP.__index = NuclideESP

NuclideESP.Name = "NuclideESP"
NuclideESP.Version = "0.0.1"

function NuclideESP.new()
	local self = setmetatable({}, NuclideESP)
	self.Config = {}
	for key, value in pairs(DEFAULT_CONFIG) do
		self.Config[key] = value
	end
	self.Targets = {}
	self.Running = false
	self.PlayersBound = false
	self.MeasureInterval = 1
	self.Connection = nil
	self.PlayerAddedConnection = nil
	self.PlayerRemovingConnection = nil
	self.LastTick = 0
	return self
end

function NuclideESP:Start()
	if self.Running then
		return self
	end
	self.Running = true
	self:TrackPlayers()
	self.Connection = RunService.RenderStepped:Connect(function()
		self:_update()
	end)
	return self
end

function NuclideESP:Stop()
	if not self.Running then
		return self
	end
	self.Running = false
	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end
	if self.PlayerAddedConnection then
		self.PlayerAddedConnection:Disconnect()
		self.PlayerAddedConnection = nil
	end
	if self.PlayerRemovingConnection then
		self.PlayerRemovingConnection:Disconnect()
		self.PlayerRemovingConnection = nil
	end
	self.PlayersBound = false
	self:Clear()
	return self
end

function NuclideESP:_update()
	if not self.Config.Enabled then
		return
	end
	local now = os.clock()
	if now - self.LastTick < self.Config.UpdateInterval then
		return
	end
	self.LastTick = now
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	for _, target in pairs(self.Targets) do
		target:Update(camera)
	end
end

function NuclideESP:Track(model)
	if not model or self.Targets[model] then
		return nil
	end
	local target = Target.new(self, model, false)
	self.Targets[model] = target
	return target
end

function NuclideESP:Untrack(model)
	local target = self.Targets[model]
	if target then
		self.Targets[model] = nil
		target:Destroy()
	end
	return self
end

function NuclideESP:_removeTarget(target)
	if self.Targets[target.Key] == target then
		self.Targets[target.Key] = nil
		target:Destroy()
	end
end

function NuclideESP:TrackPlayers()
	if self.PlayersBound then
		return self
	end
	self.PlayersBound = true

	local function bind(player)
		if player == LocalPlayer then
			return
		end
		self.Targets[player] = Target.new(self, player, true)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		bind(player)
	end

	self.PlayerAddedConnection = Players.PlayerAdded:Connect(bind)
	self.PlayerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		local target = self.Targets[player]
		if target then
			self.Targets[player] = nil
			target:Destroy()
		end
	end)
	return self
end

function NuclideESP:Clear()
	for _, target in pairs(self.Targets) do
		target:Destroy()
	end
	table.clear(self.Targets)
	return self
end

function NuclideESP:Enable()
	self.Config.Enabled = true
	return self
end

function NuclideESP:Disable()
	self.Config.Enabled = false
	for _, target in pairs(self.Targets) do
		target:SetVisible(false)
	end
	return self
end

function NuclideESP:Toggle()
	if self.Config.Enabled then
		self:Disable()
	else
		self:Enable()
	end
	return self
end

function NuclideESP:IsEnabled()
	return self.Config.Enabled
end

function NuclideESP:SetConfig(overrides)
	for key, value in pairs(overrides) do
		self.Config[key] = value
	end
	local config = self.Config
	config.UpdateInterval = math.max(config.UpdateInterval, 0.01)
	config.MaxDistance = math.max(config.MaxDistance, 0)
	config.Thickness = math.clamp(config.Thickness, 1, 8)
	config.Transparency = math.clamp(config.Transparency, 0, 1)
	config.CornerLengthFraction = math.clamp(config.CornerLengthFraction, 0.05, 0.5)
	for _, target in pairs(self.Targets) do
		target:ApplyConfig()
	end
	return self
end

if Drawing then
	local instance = NuclideESP.new()
	instance:Start()
	if getgenv then
		getgenv().NuclideESP = instance
	else
		shared.NuclideESP = instance
	end
else
	warn("NuclideESP: Drawing API is not available (requires an executor).")
end
