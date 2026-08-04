local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local DEFAULT_CONFIG = {
	Enabled = false,
	Yourself = false,
	DeadCheck = true,
	TeamCheck = false,
	VisibleColor = Color3.fromRGB(0, 255, 120),
	InvisibleColor = Color3.fromRGB(255, 80, 80),
	FillTransparency = 0.5,
	OutlineTransparency = 0,
	MaxDistance = 5000,
	MeasureInterval = 0.2,
	DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
}

local RaycastCache = nil
local function getRaycastParams()
	if not RaycastCache then
		RaycastCache = RaycastParams.new()
		RaycastCache.FilterType = Enum.RaycastFilterType.Exclude
		RaycastCache.IgnoreWater = true
	end
	return RaycastCache
end

local Target = {}
Target.__index = Target

function Target.new(manager, key, isPlayer)
	local self = setmetatable({}, Target)
	self.Manager = manager
	self.Key = key
	self.Player = isPlayer and key or nil
	self.Model = nil
	self.RootPart = nil
	self.Humanoid = nil
	self.CachedPos = nil
	self.Visible = false
	self.LastVisCheck = 0
	self.IsRayVisible = true
	self.CurrentColor = manager.Config.VisibleColor
	self.Connections = {}
	self.Highlight = Instance.new("Highlight")
	self.Highlight.FillColor = manager.Config.VisibleColor
	self.Highlight.OutlineColor = manager.Config.VisibleColor
	self.Highlight.FillTransparency = manager.Config.FillTransparency
	self.Highlight.OutlineTransparency = manager.Config.OutlineTransparency
	self.Highlight.DepthMode = manager.Config.DepthMode
	self.Highlight.Enabled = false
	self.Highlight.Adornee = nil
	pcall(function()
		self.Highlight.Parent = game:GetService("CoreGui")
	end)
	if not self.Highlight.Parent then
		pcall(function()
			self.Highlight.Parent = Workspace
		end)
	end

	if self.Player then
		local pl = self.Player
		table.insert(self.Connections, pl.CharacterAdded:Connect(function(ch)
			self:BindCharacter(ch)
		end))
		table.insert(self.Connections, pl.CharacterRemoving:Connect(function()
			self:Unbind()
		end))
		if pl.Character then
			task.spawn(self.BindCharacter, self, pl.Character)
		end
	else
		self:BindModel(key)
	end
	return self
end

function Target:BindCharacter(character)
	self.Model = character
	self.RootPart = character:WaitForChild("HumanoidRootPart", 10)
	self.Humanoid = character:FindFirstChildOfClass("Humanoid")
	if not self.Humanoid then
		character:WaitForChild("Humanoid", 10)
		self.Humanoid = character:FindFirstChildOfClass("Humanoid")
	end
	if character ~= self.Model then
		return
	end
	self.Highlight.Adornee = character
	self.CachedPos = self.RootPart and self.RootPart.Position or character:GetBoundingBox()
end

function Target:BindModel(model)
	self.Model = model
	self.RootPart = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildOfClass("BasePart")
	self.Humanoid = model:FindFirstChildOfClass("Humanoid")
	self.Highlight.Adornee = model
	self.CachedPos = self.RootPart and self.RootPart.Position or model:GetBoundingBox()
end

function Target:Unbind()
	self.Model = nil
	self.RootPart = nil
	self.Humanoid = nil
	self.CachedPos = nil
	self.Highlight.Adornee = nil
	self:SetVisible(false)
end

function Target:Update(camera)
	local cfg = self.Manager.Config
	local model = self.Model
	if not model or model.Parent == nil then
		if self.Player then
			self:Unbind()
		else
			self.Manager:_removeTarget(self)
		end
		return
	end

	if self.Player and not cfg.Yourself and self.Player == LocalPlayer then
		self:SetVisible(false)
		return
	end

	if cfg.TeamCheck and self.Player and LocalPlayer and self.Player.Team == LocalPlayer.Team then
		self:SetVisible(false)
		return
	end

	if cfg.DeadCheck and self.Humanoid and self.Humanoid.Health <= 0 then
		self:SetVisible(false)
		return
	end

	local origin = self.RootPart and self.RootPart.Position or self.CachedPos
	if typeof(origin) == "Vector3" then
	else
		if self.RootPart then
			origin = self.RootPart.Position
		else
			local ok, cf = pcall(model.GetBoundingBox, model)
			if ok then
				origin = cf.Position
				self.CachedPos = origin
			else
				self:SetVisible(false)
				return
			end
		end
	end

	local dist = (camera.CFrame.Position - origin).Magnitude
	if dist > cfg.MaxDistance then
		self:SetVisible(false)
		return
	end

	local now = os.clock()
	if now - self.LastVisCheck >= cfg.MeasureInterval then
		self.LastVisCheck = now
		local params = getRaycastParams()
		params.FilterDescendantsInstances = { model, LocalPlayer and LocalPlayer.Character }
		local result = Workspace:Raycast(camera.CFrame.Position, origin - camera.CFrame.Position, params)
		self.IsRayVisible = result == nil
	end

	local chosen = self.IsRayVisible and cfg.VisibleColor or cfg.InvisibleColor
	self.CurrentColor = chosen
	self.Highlight.FillColor = chosen
	self.Highlight.OutlineColor = chosen
	self.Highlight.FillTransparency = cfg.FillTransparency
	self.Highlight.OutlineTransparency = cfg.OutlineTransparency
	self.Highlight.DepthMode = cfg.DepthMode

	self:SetVisible(true)
end

function Target:SetVisible(v)
	self.Visible = v
	self.Highlight.Enabled = v and self.Manager.Config.Enabled
	if v then
		self.Highlight.FillColor = self.CurrentColor
		self.Highlight.OutlineColor = self.CurrentColor
	end
end

function Target:ApplyConfig()
	local cfg = self.Manager.Config
	self.Highlight.FillTransparency = cfg.FillTransparency
	self.Highlight.OutlineTransparency = cfg.OutlineTransparency
	self.Highlight.DepthMode = cfg.DepthMode
	self.Highlight.FillColor = self.CurrentColor
	self.Highlight.OutlineColor = self.CurrentColor
end

function Target:Destroy()
	for _, c in ipairs(self.Connections) do
		c:Disconnect()
	end
	table.clear(self.Connections)
	self.Highlight:Destroy()
end

local NuclideChams = {}
NuclideChams.__index = NuclideChams
NuclideChams.Name = "NuclideChams"
NuclideChams.Version = "0.0.1"

function NuclideChams.new()
	local self = setmetatable({}, NuclideChams)
	self.Config = {}
	for k, v in pairs(DEFAULT_CONFIG) do
		self.Config[k] = v
	end
	self.Targets = {}
	self.Running = false
	self.PlayersBound = false
	self.Connection = nil
	self.PlayerAddedConnection = nil
	self.PlayerRemovingConnection = nil
	return self
end

function NuclideChams:Start()
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

function NuclideChams:Stop()
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

function NuclideChams:_update()
	if not self.Config.Enabled then
		return
	end
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	for _, t in pairs(self.Targets) do
		t:Update(cam)
	end
end

function NuclideChams:Track(model)
	if not model or self.Targets[model] then
		return nil
	end
	local target = Target.new(self, model, false)
	self.Targets[model] = target
	return target
end

function NuclideChams:Untrack(model)
	local t = self.Targets[model]
	if t then
		self.Targets[model] = nil
		t:Destroy()
	end
	return self
end

function NuclideChams:_removeTarget(target)
	if self.Targets[target.Key] == target then
		self.Targets[target.Key] = nil
		target:Destroy()
	end
end

function NuclideChams:TrackPlayers()
	if self.PlayersBound then
		return self
	end
	self.PlayersBound = true
	local function bind(pl)
		if self.Targets[pl] then
			return
		end
		self.Targets[pl] = Target.new(self, pl, true)
	end
	for _, pl in ipairs(Players:GetPlayers()) do
		bind(pl)
	end
	self.PlayerAddedConnection = Players.PlayerAdded:Connect(bind)
	self.PlayerRemovingConnection = Players.PlayerRemoving:Connect(function(pl)
		local t = self.Targets[pl]
		if t then
			self.Targets[pl] = nil
			t:Destroy()
		end
	end)
	return self
end

function NuclideChams:Clear()
	for _, t in pairs(self.Targets) do
		t:Destroy()
	end
	table.clear(self.Targets)
	return self
end

function NuclideChams:Enable()
	self.Config.Enabled = true
	return self
end

function NuclideChams:Disable()
	self.Config.Enabled = false
	for _, t in pairs(self.Targets) do
		t:SetVisible(false)
	end
	return self
end

function NuclideChams:Toggle()
	if self.Config.Enabled then
		self:Disable()
	else
		self:Enable()
	end
	return self
end

function NuclideChams:IsEnabled()
	return self.Config.Enabled
end

function NuclideChams:SetConfig(over)
	for k, v in pairs(over) do
		self.Config[k] = v
	end
	local c = self.Config
	c.MaxDistance = math.max(c.MaxDistance, 0)
	c.FillTransparency = math.clamp(c.FillTransparency, 0, 1)
	c.OutlineTransparency = math.clamp(c.OutlineTransparency, 0, 1)
	c.MeasureInterval = math.max(c.MeasureInterval, 0.05)
	for _, t in pairs(self.Targets) do
		t:ApplyConfig()
	end
	return self
end

function NuclideChams:Unload()
	self:Stop()
	if getgenv then
		getgenv().NuclideChams = nil
	else
		shared.NuclideChams = nil
	end
	return self
end

if true then
	local inst = NuclideChams.new()
	inst:Start()
	if getgenv then
		getgenv().NuclideChams = inst
	else
		shared.NuclideChams = inst
	end
end
