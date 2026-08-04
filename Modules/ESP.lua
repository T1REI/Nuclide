local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local CORNER_OFFSETS = {
	{ -1, -1, -1 }, { 1, -1, -1 }, { 1, 1, -1 }, { -1, 1, -1 },
	{ -1, -1, 1 }, { 1, -1, 1 }, { 1, 1, 1 }, { -1, 1, 1 },
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

local function isAccessoryDescendant(part, model)
	local cur = part.Parent
	while cur and cur ~= model do
		if cur:IsA("Accessory") then
			return true
		end
		cur = cur.Parent
	end
	return false
end

local ESPInstance = {}
ESPInstance.__index = ESPInstance

function ESPInstance.new(group, key)
	local self = setmetatable({}, ESPInstance)
	self.Group = group
	self.Key = key
	self.Model = nil
	self.RootPart = nil
	self.Humanoid = nil
	self.CachedCFrame = nil
	self.Size = Vector3.new(2, 5, 1)
	self.SizeVersion = 0
	self.MeasuredAt = 0
	self.Visible = false
	self.LastCamera = nil
	self.LastCenter = nil
	self.LastRot = nil
	self.LastSizeVersion = 0
	self.LastVisCheck = 0
	self.IsRayVisible = true
	self.CurrentColor = group.Config.VisibleColor
	self.Lines = {}
	self.Connections = {}

	if Drawing then
		local cfg = group.Config
		for i = 1, 8 do
			local l = Drawing.new("Line")
			l.Color = cfg.VisibleColor
			l.Thickness = 1
			l.Transparency = 1
			l.Visible = false
			self.Lines[i] = l
		end

		self.HealthBg = Drawing.new("Line")
		self.HealthBg.Color = Color3.fromRGB(0, 0, 0)
		self.HealthBg.Thickness = 3
		self.HealthBg.Transparency = 1
		self.HealthBg.Visible = false

		self.HealthFill = Drawing.new("Line")
		self.HealthFill.Color = Color3.fromRGB(0, 255, 0)
		self.HealthFill.Thickness = 2
		self.HealthFill.Transparency = 1
		self.HealthFill.Visible = false

		self.NameTag = Drawing.new("Text")
		self.NameTag.Size = 13
		self.NameTag.Color = cfg.VisibleColor
		self.NameTag.Outline = true
		self.NameTag.OutlineColor = Color3.fromRGB(0, 0, 0)
		self.NameTag.Transparency = 1
		self.NameTag.Visible = false

		self.DistanceTag = Drawing.new("Text")
		self.DistanceTag.Size = 12
		self.DistanceTag.Color = cfg.VisibleColor
		self.DistanceTag.Outline = true
		self.DistanceTag.OutlineColor = Color3.fromRGB(0, 0, 0)
		self.DistanceTag.Transparency = 1
		self.DistanceTag.Visible = false
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

function ESPInstance:Bind(model)
	self.Model = model
	self.RootPart = model:IsA("BasePart") and model 
		or model.PrimaryPart 
		or model:FindFirstChild("HumanoidRootPart") 
		or model:FindFirstChildOfClass("BasePart")
	self.Humanoid = model:FindFirstChildOfClass("Humanoid")
	self:_measure()
end

function ESPInstance:Unbind()
	self.Model = nil
	self.RootPart = nil
	self.Humanoid = nil
	self.CachedCFrame = nil
	self:SetVisible(false)
end

function ESPInstance:_measure()
	local model = self.Model
	if not model then return end

	local cfg = self.Group.Config

	if not cfg.AdaptWidth and (self.Key:IsA("Player") or self.Humanoid) then
		local standardSize = Vector3.new(2.2, 5.5, 1.5)
		if (standardSize - self.Size).Magnitude > 0.12 then
			self.Size = standardSize
			self.SizeVersion = self.SizeVersion + 1
		end
		return
	end

	if model:IsA("BasePart") then
		self.Size = model.Size
		self.SizeVersion = self.SizeVersion + 1
		return
	end

	local ref = self.RootPart and self.RootPart.CFrame
	if not ref then
		local ok, cf = pcall(model.GetBoundingBox, model)
		if ok and cf then
			ref = cf
			self.CachedCFrame = cf
		end
	end
	if not ref then return end

	local inv = ref:Inverse()
	local minX, minY, minZ = math.huge, math.huge, math.huge
	local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
	local found = false

	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			if not isAccessoryDescendant(part, model) then
				local sx, sy, sz = part.Size.X * 0.5, part.Size.Y * 0.5, part.Size.Z * 0.5
				local pcf = part.CFrame
				for dx = -1, 1, 2 do
					for dy = -1, 1, 2 do
						for dz = -1, 1, 2 do
							local world = pcf * Vector3.new(sx * dx, sy * dy, sz * dz)
							local lp = inv * world
							if lp.X < minX then minX = lp.X end
							if lp.X > maxX then maxX = lp.X end
							if lp.Y < minY then minY = lp.Y end
							if lp.Y > maxY then maxY = lp.Y end
							if lp.Z < minZ then minZ = lp.Z end
							if lp.Z > maxZ then maxZ = lp.Z end
						end
					end
				end
				found = true
			end
		end
	end

	if not found then return end

	local sx = (maxX - minX) * 0.65
	local sy = maxY - minY
	local sz = (maxZ - minZ) * 0.65
	if sx < 0.01 or sy < 0.01 or sz < 0.01 then return end

	local size = Vector3.new(sx, sy, sz)
	if self.Key:IsA("Player") or self.Humanoid then
		size = Vector3.new(
			math.clamp(size.X, 1.2, 2.5),
			math.clamp(size.Y, 3.5, 6.5),
			math.clamp(size.Z, 1.0, 2.0)
		)
	end

	if (size - self.Size).Magnitude > 0.12 then
		self.Size = size
		self.SizeVersion = self.SizeVersion + 1
	end
end

function ESPInstance:Update(camera)
	local cfg = self.Group.Config
	local model = self.Model
	if not model or model.Parent == nil then
		self:SetVisible(false)
		return
	end

	if self.Key:IsA("Player") and not cfg.Yourself and self.Key == LocalPlayer then
		self:SetVisible(false)
		return
	end

	if not self.RootPart or self.RootPart.Parent == nil then
		self.RootPart = model:IsA("BasePart") and model 
			or model.PrimaryPart 
			or model:FindFirstChild("HumanoidRootPart") 
			or model:FindFirstChildOfClass("BasePart")
	end

	if not self.Humanoid or self.Humanoid.Parent == nil then
		self.Humanoid = model:FindFirstChildOfClass("Humanoid")
	end

	local now = os.clock()
	if now >= self.MeasuredAt then
		self.MeasuredAt = now + 1
		self:_measure()
	end

	local cf = self.RootPart and self.RootPart.CFrame or self.CachedCFrame
	if not cf or not self.Size then
		self:SetVisible(false)
		return
	end

	local origin = cf.Position
	local camPos = camera.CFrame.Position
	local dist = (camPos - origin).Magnitude
	if dist > cfg.MaxDistance then
		self:SetVisible(false)
		return
	end

	local center, onScreen = camera:WorldToViewportPoint(origin)
	if not onScreen or center.Z <= 0 then
		self:SetVisible(false)
		return
	end

	local camCF = camera.CFrame
	local rot = cf.Rotation
	local camMoved = self.LastCamera ~= camCF
	local rotated = self.LastRot ~= rot
	local centerMoved = true
	if self.LastCenter then
		local dx = center.X - self.LastCenter.X
		local dy = center.Y - self.LastCenter.Y
		centerMoved = dx * dx + dy * dy >= 0.5
	end
	if not camMoved and not rotated and not centerMoved and self.LastSizeVersion == self.SizeVersion and self.Visible then
	else
		self.LastCamera = camCF
		self.LastRot = rot
		self.LastCenter = center
		self.LastSizeVersion = self.SizeVersion
	end

	local half = self.Size * 0.5
	local right = cf.RightVector * half.X
	local up = cf.UpVector * half.Y
	local look = cf.LookVector * half.Z
	local minX, minY = math.huge, math.huge
	local maxX, maxY = -math.huge, -math.huge
	local behind = false

	for i = 1, 8 do
		local o = CORNER_OFFSETS[i]
		local world = Vector3.new(
			origin.X + right.X * o[1] + up.X * o[2] + look.X * o[3],
			origin.Y + right.Y * o[1] + up.Y * o[2] + look.Y * o[3],
			origin.Z + right.Z * o[1] + up.Z * o[2] + look.Z * o[3]
		)
		local p = camera:WorldToViewportPoint(world)
		if p.Z <= 0 then
			behind = true
		else
			if p.X < minX then minX = p.X end
			if p.X > maxX then maxX = p.X end
			if p.Y < minY then minY = p.Y end
			if p.Y > maxY then maxY = p.Y end
		end
	end

	local vp = camera.ViewportSize
	if behind then
		local pps = (vp.Y * 0.5) / math.tan(math.rad(camera.FieldOfView) * 0.5) / math.max(dist, 1)
		minX = center.X - self.Size.X * pps * 0.5
		maxX = center.X + self.Size.X * pps * 0.5
		minY = center.Y - self.Size.Y * pps * 0.5
		maxY = center.Y + self.Size.Y * pps * 0.5
	end

	minX = math.floor(minX + 0.5)
	maxX = math.floor(maxX + 0.5)
	minY = math.floor(minY + 0.5)
	maxY = math.floor(maxY + 0.5)

	if maxX < 0 or minX > vp.X or maxY < 0 or minY > vp.Y then
		self:SetVisible(false)
		return
	end

	if not Drawing then return end

	if now - self.LastVisCheck >= 0.15 then
		self.LastVisCheck = now
		local params = getRaycastParams()
		params.FilterDescendantsInstances = { model, LocalPlayer and LocalPlayer.Character }
		local dir = origin - camPos
		local result = Workspace:Raycast(camPos, dir, params)
		self.IsRayVisible = result == nil
	end

	local chosen = self.IsRayVisible and cfg.VisibleColor or cfg.InvisibleColor
	self.CurrentColor = chosen

	local width = maxX - minX
	local height = maxY - minY
	local clen = math.clamp(math.min(width, height) * 0.2, 6, 42)

	if cfg.Corner then
		local l = self.Lines
		l[1].From = Vector2.new(minX, minY)
		l[1].To = Vector2.new(minX + clen, minY)
		l[2].From = Vector2.new(minX, minY)
		l[2].To = Vector2.new(minX, minY + clen)
		l[3].From = Vector2.new(maxX, minY)
		l[3].To = Vector2.new(maxX - clen, minY)
		l[4].From = Vector2.new(maxX, minY)
		l[4].To = Vector2.new(maxX, minY + clen)
		l[5].From = Vector2.new(maxX, maxY)
		l[5].To = Vector2.new(maxX - clen, maxY)
		l[6].From = Vector2.new(maxX, maxY)
		l[6].To = Vector2.new(maxX, maxY - clen)
		l[7].From = Vector2.new(minX, maxY)
		l[7].To = Vector2.new(minX + clen, maxY)
		l[8].From = Vector2.new(minX, maxY)
		l[8].To = Vector2.new(minX, maxY - clen)
		for i = 1, 8 do
			l[i].Color = chosen
			l[i].Visible = true
		end
	else
		for i = 1, 8 do
			self.Lines[i].Visible = false
		end
	end

	if cfg.HealthBar and self.Humanoid then
		local barX = minX - 6
		self.HealthBg.From = Vector2.new(barX, minY)
		self.HealthBg.To = Vector2.new(barX, maxY)
		self.HealthBg.Visible = true

		local ratio = math.clamp(self.Humanoid.Health / self.Humanoid.MaxHealth, 0, 1)
		local healthY = maxY - (height * ratio)
		self.HealthFill.From = Vector2.new(barX, maxY)
		self.HealthFill.To = Vector2.new(barX, healthY)
		self.HealthFill.Color = Color3.fromRGB(255 - (255 * ratio), 255 * ratio, 0)
		self.HealthFill.Visible = true
	else
		self.HealthBg.Visible = false
		self.HealthFill.Visible = false
	end

	if cfg.Nametag then
		local nameStr = self.Key:IsA("Player") and self.Key.DisplayName or model.Name
		self.NameTag.Text = nameStr
		local bounds = self.NameTag.TextBounds
		self.NameTag.Position = Vector2.new((minX + maxX) * 0.5 - bounds.X * 0.5, minY - bounds.Y - 2)
		self.NameTag.Color = chosen
		self.NameTag.Visible = true
	else
		self.NameTag.Visible = false
	end

	if cfg.Distance then
		self.DistanceTag.Text = string.format("%dm", math.floor(dist))
		local bounds = self.DistanceTag.TextBounds
		self.DistanceTag.Position = Vector2.new((minX + maxX) * 0.5 - bounds.X * 0.5, maxY + 2)
		self.DistanceTag.Color = chosen
		self.DistanceTag.Visible = true
	else
		self.DistanceTag.Visible = false
	end

	self:SetVisible(true)
end

function ESPInstance:SetVisible(v)
	self.Visible = v
	self:_syncVisible()
end

function ESPInstance:_syncVisible()
	if not Drawing then return end
	local show = self.Visible and self.Group.Enabled
	if not show then
		for i = 1, 8 do self.Lines[i].Visible = false end
		self.HealthBg.Visible = false
		self.HealthFill.Visible = false
		self.NameTag.Visible = false
		self.DistanceTag.Visible = false
	end
end

function ESPInstance:Destroy()
	for _, c in ipairs(self.Connections) do
		c:Disconnect()
	end
	table.clear(self.Connections)
	if Drawing then
		for i = 1, 8 do self.Lines[i]:Remove() end
		self.HealthBg:Remove()
		self.HealthFill:Remove()
		self.NameTag:Remove()
		self.DistanceTag:Remove()
	end
end

local ESPGroup = {}
ESPGroup.__index = ESPGroup

function ESPGroup.new()
	local self = setmetatable({}, ESPGroup)
	self.Enabled = false
	self.Targets = {}
	self.FolderConnections = {}
	self.Config = {
		Corner = true,
		Nametag = true,
		HealthBar = true,
		Distance = true,
		VisibleColor = Color3.fromRGB(255, 255, 255),
		InvisibleColor = Color3.fromRGB(255, 0, 0),
		MaxDistance = 5000,
		Yourself = false,
		AdaptWidth = true,
	}
	return self
end

function ESPGroup:Add(key)
	if self.Targets[key] then return end
	self.Targets[key] = ESPInstance.new(self, key)
end

function ESPGroup:Remove(key)
	local inst = self.Targets[key]
	if inst then
		inst:Destroy()
		self.Targets[key] = nil
	end
end

function ESPGroup:TrackFolder(folder)
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

function ESPGroup:UpdateAll(camera)
	if not self.Enabled then return end
	for _, inst in pairs(self.Targets) do
		inst:Update(camera)
	end
end

function ESPGroup:SetEnabled(val)
	self.Enabled = val
	if not val then
		for _, inst in pairs(self.Targets) do
			inst:SetVisible(false)
		end
	end
end

function ESPGroup:SetConfig(newCfg)
	for k, v in pairs(newCfg) do
		self.Config[k] = v
	end
end

function ESPGroup:Clear()
	for _, conn in ipairs(self.FolderConnections) do
		conn:Disconnect()
	end
	table.clear(self.FolderConnections)

	for _, inst in pairs(self.Targets) do
		inst:Destroy()
	end
	table.clear(self.Targets)
end

local ESP = {}
ESP.__index = ESP
ESP.GroupClass = ESPGroup

function ESP.new()
	local self = setmetatable({}, ESP)
	self.Groups = {}
	self.Connection = nil
	return self
end

function ESP:CreateGroup(id)
	local g = ESPGroup.new()
	self.Groups[id] = g
	return g
end

function ESP:Start()
	if self.Connection then return end
	self.Connection = RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if not camera then return end
		for _, g in pairs(self.Groups) do
			g:UpdateAll(camera)
		end
	end)
end

function ESP:Stop()
	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end
	for _, g in pairs(self.Groups) do
		g:SetEnabled(false)
	end
end

function ESP:Destroy()
	self:Stop()
	for id, g in pairs(self.Groups) do
		g:Clear()
		self.Groups[id] = nil
	end
end

return ESP
