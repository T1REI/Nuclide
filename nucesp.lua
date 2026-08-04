local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local CORNER_OFFSETS = {
	{ -1, -1, -1 }, { 1, -1, -1 }, { 1, 1, -1 }, { -1, 1, -1 },
	{ -1, -1, 1 }, { 1, -1, 1 }, { 1, 1, 1 }, { -1, 1, 1 },
}

local GRADIENT_SEGMENTS = 8

local DEFAULT_CONFIG = {
	Enabled = false,
	Corner = true,
	Yourself = false,
	DeadCheck = true,
	TeamCheck = false,
	VisibleColor = Color3.fromRGB(255, 255, 255),
	InvisibleColor = Color3.fromRGB(255, 80, 80),
	Thickness = 1,
	Transparency = 0,
	HealthBar = true,
	HealthText = true,
	Nametag = true,
	Distance = true,
	MaxDistance = 5000,
	CornerLengthFraction = 0.2,
	MeasureInterval = 1,
	HealthBarWidth = 4,
	TextSize = 13,
	NametagSize = 13,
	NametagColor = nil,
	NametagFormatter = nil,
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
	self.CurrentColor = manager.Config.VisibleColor
	self.Lines = {}
	self.HealthFills = {}
	self.Connections = {}
	if Drawing then
		local cfg = manager.Config
		local trans = 1 - cfg.Transparency
		for i = 1, 8 do
			local l = Drawing.new("Line")
			l.Color = cfg.VisibleColor
			l.Thickness = cfg.Thickness
			l.Transparency = trans
			l.Visible = false
			self.Lines[i] = l
		end
		self.HealthBg = Drawing.new("Line")
		self.HealthBg.Color = Color3.fromRGB(0, 0, 0)
		self.HealthBg.Thickness = cfg.HealthBarWidth + 2
		self.HealthBg.Transparency = trans
		self.HealthBg.Visible = false

		for i = 1, GRADIENT_SEGMENTS do
			local l = Drawing.new("Line")
			l.Thickness = cfg.HealthBarWidth
			l.Transparency = trans
			l.Visible = false
			self.HealthFills[i] = l
		end

		self.HealthText = Drawing.new("Text")
		self.HealthText.Size = cfg.TextSize
		self.HealthText.Color = cfg.VisibleColor
		self.HealthText.Outline = true
		self.HealthText.OutlineColor = Color3.fromRGB(0, 0, 0)
		self.HealthText.Transparency = trans
		self.HealthText.Visible = false

		self.NameTag = Drawing.new("Text")
		self.NameTag.Size = cfg.TextSize
		self.NameTag.Color = cfg.VisibleColor
		self.NameTag.Outline = true
		self.NameTag.OutlineColor = Color3.fromRGB(0, 0, 0)
		self.NameTag.Transparency = trans
		self.NameTag.Visible = false

		self.DistanceTag = Drawing.new("Text")
		self.DistanceTag.Size = math.max(cfg.TextSize - 1, 11)
		self.DistanceTag.Color = cfg.VisibleColor
		self.DistanceTag.Outline = true
		self.DistanceTag.OutlineColor = Color3.fromRGB(0, 0, 0)
		self.DistanceTag.Transparency = trans
		self.DistanceTag.Visible = false
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
	local hrp = character:WaitForChild("HumanoidRootPart", 10)
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum then
		character:WaitForChild("Humanoid", 10)
		hum = character:FindFirstChildOfClass("Humanoid")
	end
	if character ~= self.Model then
		return
	end
	self.RootPart = hrp
	self.Humanoid = hum
	task.wait()
	self:_measure()
end

function Target:BindModel(model)
	self.Model = model
	self.RootPart = model.PrimaryPart
		or model:FindFirstChild("HumanoidRootPart")
		or model:FindFirstChildOfClass("BasePart")
	self.Humanoid = model:FindFirstChildOfClass("Humanoid")
	self:_measure()
end

function Target:Unbind()
	self.Model = nil
	self.RootPart = nil
	self.Humanoid = nil
	self.CachedCFrame = nil
	self:SetVisible(false)
end

function Target:_measure()
	local model = self.Model
	if not model then
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
	if not ref then
		return
	end
	local inv = ref:Inverse()
	local minX, minY, minZ = math.huge, math.huge, math.huge
	local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
	local found = false

	if self.Player then
		for _, child in ipairs(model:GetChildren()) do
			if child:IsA("BasePart") then
				local sx, sy, sz = child.Size.X * 0.5, child.Size.Y * 0.5, child.Size.Z * 0.5
				local pcf = child.CFrame
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
	else
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				if isAccessoryDescendant(part, model) then
					continue
				end
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

	if not found then
		return
	end

	local sx = maxX - minX
	local sy = maxY - minY
	local sz = maxZ - minZ
	if sx < 0.01 or sy < 0.01 or sz < 0.01 then
		return
	end

	local size = Vector3.new(sx, sy, sz)
	if self.Player then
		size = Vector3.new(
			math.clamp(size.X, 2, 4.5),
			math.clamp(size.Y, 3, 7.5),
			math.clamp(size.Z, 1, 3.5)
		)
	end

	if (size - self.Size).Magnitude > 0.12 then
		self.Size = size
		self.SizeVersion = self.SizeVersion + 1
	end
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

	local now = os.clock()
	if now >= self.MeasuredAt then
		self.MeasuredAt = now + cfg.MeasureInterval
		self:_measure()
	end

	local cf = self.RootPart and self.RootPart.CFrame or self.CachedCFrame
	if not cf or not self.Size then
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

	if not Drawing then
		return
	end

	if now - self.LastVisCheck >= 0.12 then
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
	local clen = math.clamp(math.min(width, height) * cfg.CornerLengthFraction, 6, 42)
	local trans = 1 - cfg.Transparency

	if cfg.Corner then
		local l = self.Lines
		l[1].From = Vector2.new(minX, minY); l[1].To = Vector2.new(minX + clen, minY)
		l[2].From = Vector2.new(minX, minY); l[2].To = Vector2.new(minX, minY + clen)
		l[3].From = Vector2.new(maxX, minY); l[3].To = Vector2.new(maxX - clen, minY)
		l[4].From = Vector2.new(maxX, minY); l[4].To = Vector2.new(maxX, minY + clen)
		l[5].From = Vector2.new(maxX, maxY); l[5].To = Vector2.new(maxX - clen, maxY)
		l[6].From = Vector2.new(maxX, maxY); l[6].To = Vector2.new(maxX, maxY - clen)
		l[7].From = Vector2.new(minX, maxY); l[7].To = Vector2.new(minX + clen, maxY)
		l[8].From = Vector2.new(minX, maxY); l[8].To = Vector2.new(minX, maxY - clen)
		for i = 1, 8 do
			l[i].Color = chosen
			l[i].Thickness = cfg.Thickness
			l[i].Transparency = trans
		end
	end

	if cfg.HealthBar and self.Humanoid then
		local barW = cfg.HealthBarWidth
		local xmid = minX - 7 - barW + barW * 0.5
		self.HealthBg.From = Vector2.new(xmid, minY)
		self.HealthBg.To = Vector2.new(xmid, maxY)
		self.HealthBg.Thickness = barW + 2
		self.HealthBg.Transparency = trans

		local frac = math.clamp(self.Humanoid.Health / self.Humanoid.MaxHealth, 0, 1)
		local totalH = maxY - minY
		local fillH = totalH * frac
		local fillTop = maxY - fillH
		local segH = totalH / GRADIENT_SEGMENTS

		local light = chosen:Lerp(Color3.new(1, 1, 1), 0.45)
		local dark = chosen:Lerp(Color3.new(0, 0, 0), 0.45)

		for j = 0, GRADIENT_SEGMENTS - 1 do
			local line = self.HealthFills[j + 1]
			local bottomY = maxY - j * segH
			local topY = maxY - (j + 1) * segH
			if bottomY <= fillTop then
				line.Visible = false
			else
				local clippedTop = math.max(topY, fillTop)
				line.From = Vector2.new(xmid, bottomY)
				line.To = Vector2.new(xmid, clippedTop)
				local t = j / (GRADIENT_SEGMENTS - 1)
				line.Color = dark:Lerp(light, t)
				line.Thickness = barW
				line.Transparency = trans
				line.Visible = true
			end
		end
	else
		for i = 1, GRADIENT_SEGMENTS do
			self.HealthFills[i].Visible = false
		end
	end

	if cfg.HealthText and self.Humanoid then
		self.HealthText.Text = tostring(math.clamp(math.floor(self.Humanoid.Health + 0.5), 0, 9999))
		local b = self.HealthText.TextBounds
		local bx = minX - 7 - cfg.HealthBarWidth
		self.HealthText.Position = Vector2.new(bx - b.X - 3, (minY + maxY) * 0.5 - b.Y * 0.5)
		self.HealthText.Color = chosen
		self.HealthText.Transparency = trans
	end

	if cfg.Nametag then
		local baseName = self.Player and self.Player.DisplayName or model.Name
		local custom = self.Manager.CustomNametags[self.Key] or self.Manager.CustomNametags[self.Player] or self.Manager.CustomNametags[model]
		local name
		if custom ~= nil then
			name = tostring(custom)
		elseif cfg.NametagFormatter and type(cfg.NametagFormatter) == "function" then
			local ok, result = pcall(cfg.NametagFormatter, self.Player, model, dist, self.Humanoid and self.Humanoid.Health, self.Humanoid and self.Humanoid.MaxHealth, baseName)
			if ok and result ~= nil then
				name = tostring(result)
			else
				name = baseName
			end
		else
			name = baseName
		end
		self.NameTag.Text = name
		local b = self.NameTag.TextBounds
		self.NameTag.Position = Vector2.new((minX + maxX) * 0.5 - b.X * 0.5, minY - b.Y - 3)
		self.NameTag.Color = cfg.NametagColor or chosen
		self.NameTag.Transparency = trans
		self.NameTag.Size = cfg.NametagSize or cfg.TextSize
	end

	if cfg.Distance then
		self.DistanceTag.Text = string.format("%dm", math.floor(dist + 0.5))
		local b = self.DistanceTag.TextBounds
		self.DistanceTag.Position = Vector2.new((minX + maxX) * 0.5 - b.X * 0.5, maxY + 2)
		self.DistanceTag.Color = chosen
		self.DistanceTag.Transparency = trans
	end

	self:SetVisible(true)
end

function Target:SetVisible(v)
	self.Visible = v
	self:_syncVisible()
end

function Target:_syncVisible()
	if not Drawing then
		return
	end
	local cfg = self.Manager.Config
	local show = self.Visible and cfg.Enabled
	self.HealthBg.Visible = show and cfg.HealthBar and self.Humanoid ~= nil
	for i = 1, GRADIENT_SEGMENTS do
		local l = self.HealthFills[i]
		if not (show and cfg.HealthBar and self.Humanoid) then
			l.Visible = false
		end
	end
	self.HealthText.Visible = show and cfg.HealthText and self.Humanoid ~= nil
	self.NameTag.Visible = show and cfg.Nametag
	self.DistanceTag.Visible = show and cfg.Distance

	local boxShow = show and cfg.Corner
	for i = 1, 8 do
		self.Lines[i].Visible = boxShow
	end
	if show then
		for i = 1, 8 do
			self.Lines[i].Color = self.CurrentColor
		end
		self.NameTag.Color = cfg.NametagColor or self.CurrentColor
		self.DistanceTag.Color = self.CurrentColor
		self.HealthText.Color = self.CurrentColor
	end
end

function Target:ApplyConfig()
	if not Drawing then
		return
	end
	local cfg = self.Manager.Config
	local trans = 1 - cfg.Transparency
	for i = 1, 8 do
		self.Lines[i].Thickness = cfg.Thickness
		self.Lines[i].Transparency = trans
		self.Lines[i].Color = self.CurrentColor
	end
	self.HealthBg.Thickness = cfg.HealthBarWidth + 2
	self.HealthBg.Transparency = trans
	for i = 1, GRADIENT_SEGMENTS do
		self.HealthFills[i].Thickness = cfg.HealthBarWidth
		self.HealthFills[i].Transparency = trans
	end
	self.HealthText.Size = cfg.TextSize
	self.HealthText.Transparency = trans
	self.HealthText.Color = self.CurrentColor
	self.NameTag.Size = cfg.NametagSize or cfg.TextSize
	self.NameTag.Transparency = trans
	self.NameTag.Color = cfg.NametagColor or self.CurrentColor
	self.DistanceTag.Size = math.max(cfg.TextSize - 1, 11)
	self.DistanceTag.Transparency = trans
	self.DistanceTag.Color = self.CurrentColor
	self:_syncVisible()
end

function Target:Destroy()
	for _, c in ipairs(self.Connections) do
		c:Disconnect()
	end
	table.clear(self.Connections)
	if Drawing then
		for i = 1, 8 do
			self.Lines[i]:Remove()
		end
		self.HealthBg:Remove()
		for i = 1, GRADIENT_SEGMENTS do
			self.HealthFills[i]:Remove()
		end
		self.HealthText:Remove()
		self.NameTag:Remove()
		self.DistanceTag:Remove()
	end
	table.clear(self.Lines)
	table.clear(self.HealthFills)
end

local NuclideESP = {}
NuclideESP.__index = NuclideESP
NuclideESP.Name = "NuclideESP"
NuclideESP.Version = "0.0.1"

function NuclideESP.new()
	local self = setmetatable({}, NuclideESP)
	self.Config = {}
	for k, v in pairs(DEFAULT_CONFIG) do
		self.Config[k] = v
	end
	self.Targets = {}
	self.CustomNametags = {}
	self.Running = false
	self.PlayersBound = false
	self.Connection = nil
	self.PlayerAddedConnection = nil
	self.PlayerRemovingConnection = nil
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
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	for _, t in pairs(self.Targets) do
		t:Update(cam)
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
	local t = self.Targets[model]
	if t then
		self.Targets[model] = nil
		t:Destroy()
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

function NuclideESP:Clear()
	for _, t in pairs(self.Targets) do
		t:Destroy()
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
	for _, t in pairs(self.Targets) do
		t:SetVisible(false)
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

function NuclideESP:SetConfig(over)
	for k, v in pairs(over) do
		self.Config[k] = v
	end
	local c = self.Config
	c.MaxDistance = math.max(c.MaxDistance, 0)
	c.Thickness = math.clamp(c.Thickness, 1, 8)
	c.Transparency = math.clamp(c.Transparency, 0, 1)
	c.CornerLengthFraction = math.clamp(c.CornerLengthFraction, 0.05, 0.5)
	c.MeasureInterval = math.max(c.MeasureInterval, 0.2)
	c.HealthBarWidth = math.clamp(c.HealthBarWidth, 1, 10)
	c.TextSize = math.clamp(c.TextSize, 8, 24)
	c.NametagSize = math.clamp(c.NametagSize or c.TextSize, 8, 32)
	for _, t in pairs(self.Targets) do
		t:ApplyConfig()
	end
	return self
end

function NuclideESP:SetNametag(targetKey, text)
	self.CustomNametags[targetKey] = text
	return self
end

function NuclideESP:ClearNametag(targetKey)
	self.CustomNametags[targetKey] = nil
	return self
end

function NuclideESP:SetNametagFormatter(formatter)
	self.Config.NametagFormatter = formatter
	return self
end

function NuclideESP:ClearAllNametags()
	table.clear(self.CustomNametags)
	return self
end

function NuclideESP:Unload()
	self:Stop()
	if getgenv then
		getgenv().NuclideESP = nil
	else
		shared.NuclideESP = nil
	end
	return self
end

if Drawing then
	local inst = NuclideESP.new()
	inst:Start()
	if getgenv then
		getgenv().NuclideESP = inst
	else
		shared.NuclideESP = inst
	end
else
	warn("NuclideESP: Drawing API is not available (requires an executor).")
end
