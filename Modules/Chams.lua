local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local RaycastCache = nil
local function getRaycastParams()
	if not RaycastCache then
		RaycastCache = RaycastParams.new()
		RaycastCache.FilterType = Enum.RaycastFilterType.Exclude
		RaycastCache.IgnoreWater = true
	end
	return RaycastCache
end

local ChamsInstance = {}
ChamsInstance.__index = ChamsInstance

function ChamsInstance.new(group, key)
	local self = setmetatable({}, ChamsInstance)
	self.Group = group
	self.Key = key
	self.Model = nil
	self.RootPart = nil
	self.Visible = false
	self.LastVisCheck = 0
	self.IsRayVisible = true
	self.Connections = {}

	self.Highlight = Instance.new("Highlight")
	self.Highlight.Enabled = false
	pcall(function()
		self.Highlight.Parent = game:GetService("CoreGui")
	end)
	if not self.Highlight.Parent then
		pcall(function()
			self.Highlight.Parent = Workspace
		end)
	end

	if key:IsA("Player") then
		table.insert(self.Connections, key.CharacterAdded:Connect(function(ch)
			self:Bind(ch)
		end))
		table.insert(self.Connections, key.CharacterRemoving:Connect(function()
			self:Unbind()
		end))
		if key.Character then
			task.spawn(self.Bind, self, key.Character)
		end
	else
		self:Bind(key)
	end

	return self
end

function ChamsInstance:Bind(model)
	self.Model = model
	self.RootPart = model:IsA("BasePart") and model 
		or model.PrimaryPart 
		or model:FindFirstChild("HumanoidRootPart") 
		or model:FindFirstChildOfClass("BasePart")
	self.Highlight.Adornee = model
end

function ChamsInstance:Unbind()
	self.Model = nil
	self.RootPart = nil
	self.Highlight.Adornee = nil
	self:SetVisible(false)
end

function ChamsInstance:Update(camera)
	local cfg = self.Group.Config
	local model = self.Model
	if not model or model.Parent == nil then
		self:SetVisible(false)
		return
	end

	local origin = self.RootPart and self.RootPart.Position
	if not origin then
		self:SetVisible(false)
		return
	end

	local dist = (camera.CFrame.Position - origin).Magnitude
	if dist > cfg.MaxDistance then
		self:SetVisible(false)
		return
	end

	local now = os.clock()
	if now - self.LastVisCheck >= 0.15 then
		self.LastVisCheck = now
		local params = getRaycastParams()
		params.FilterDescendantsInstances = { model, LocalPlayer and LocalPlayer.Character }
		local result = Workspace:Raycast(camera.CFrame.Position, origin - camera.CFrame.Position, params)
		self.IsRayVisible = result == nil
	end

	local chosen = self.IsRayVisible and cfg.VisibleColor or cfg.InvisibleColor
	self.Highlight.FillColor = chosen
	self.Highlight.OutlineColor = chosen
	self.Highlight.FillTransparency = cfg.FillTransparency
	self.Highlight.OutlineTransparency = cfg.OutlineTransparency
	self.Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

	self:SetVisible(true)
end

function ChamsInstance:SetVisible(v)
	self.Visible = v
	self.Highlight.Enabled = v and self.Group.Enabled
end

function ChamsInstance:Destroy()
	for _, c in ipairs(self.Connections) do
		c:Disconnect()
	end
	table.clear(self.Connections)
	self.Highlight:Destroy()
end

local ChamsGroup = {}
ChamsGroup.__index = ChamsGroup

function ChamsGroup.new()
	local self = setmetatable({}, ChamsGroup)
	self.Enabled = false
	self.Targets = {}
	self.FolderConnections = {}
	self.Config = {
		VisibleColor = Color3.fromRGB(0, 255, 120),
		InvisibleColor = Color3.fromRGB(255, 80, 80),
		FillTransparency = 0.5,
		OutlineTransparency = 0,
		MaxDistance = 5000,
	}
	return self
end

function ChamsGroup:Add(key)
	if self.Targets[key] then return end
	self.Targets[key] = ChamsInstance.new(self, key)
end

function ChamsGroup:Remove(key)
	local inst = self.Targets[key]
	if inst then
		inst:Destroy()
		self.Targets[key] = nil
	end
end

function ChamsGroup:TrackFolder(folder)
	local function onAdded(child)
		self:Add(child)
	end
	local function onRemoved(child)
		self:Remove(child)
	end

	for _, child in ipairs(folder:GetChildren()) do
		onAdded(child)
	end

	table.insert(self.FolderConnections, folder.ChildAdded:Connect(onAdded))
	table.insert(self.FolderConnections, folder.ChildRemoved:Connect(onRemoved))
end

function ChamsGroup:UpdateAll(camera)
	if not self.Enabled then return end
	for _, inst in pairs(self.Targets) do
		inst:Update(camera)
	end
end

function ChamsGroup:SetEnabled(val)
	self.Enabled = val
	for _, inst in pairs(self.Targets) do
		inst:SetVisible(val)
	end
end

function ChamsGroup:SetConfig(newCfg)
	for k, v in pairs(newCfg) do
		self.Config[k] = v
	end
end

function ChamsGroup:Clear()
	for _, conn in ipairs(self.FolderConnections) do
		conn:Disconnect()
	end
	table.clear(self.FolderConnections)

	for _, inst in pairs(self.Targets) do
		inst:Destroy()
	end
	table.clear(self.Targets)
end

local Chams = {}
Chams.__index = Chams
Chams.GroupClass = ChamsGroup

function Chams.new()
	local self = setmetatable({}, Chams)
	self.Groups = {}
	self.Connection = nil
	return self
end

function Chams:CreateGroup(id)
	local g = ChamsGroup.new()
	self.Groups[id] = g
	return g
end

function Chams:Start()
	if self.Connection then return end
	self.Connection = RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if not camera then return end
		for _, g in pairs(self.Groups) do
			g:UpdateAll(camera)
		end
	end)
end

function Chams:Stop()
	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end
	for _, g in pairs(self.Groups) do
		g:SetEnabled(false)
	end
end

function Chams:Destroy()
	self:Stop()
	for id, g in pairs(self.Groups) do
		g:Clear()
		self.Groups[id] = nil
	end
end

return Chams
