local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local PROGRESS_PER_CLICK = 2
local STAGE_THRESHOLDS = {26, 52, 78, 100}
local INTERACT_DISTANCE = 12
local SCAN_INTERVAL = 0.5

local AutoGenerator = {}
AutoGenerator.__index = AutoGenerator

function AutoGenerator.new()
	local self = setmetatable({}, AutoGenerator)

	self.Enabled = false
	self.DelayMs = 100
	self.StagesCompleted = 0
	self.ClicksSent = 0

	self._mapFolder = nil
	self._remotes = {RF = nil, RE = nil}
	self._currentGenerator = nil
	self._insideGenerator = false
	self._lastClick = 0
	self._connections = {}
	self._running = false
	self._nextScan = 0
	self._mapWatcher = nil

	return self
end

function AutoGenerator:SetDelay(ms)
	self.DelayMs = math.clamp(math.floor(ms or 100), 1, 1000)
end

function AutoGenerator:ResetStats()
	self.StagesCompleted = 0
	self.ClicksSent = 0
end

function AutoGenerator:GetStats()
	return {
		enabled = self.Enabled,
		delayMs = self.DelayMs,
		stagesCompleted = self.StagesCompleted,
		clicksSent = self.ClicksSent,
		currentGenerator = self._currentGenerator,
		insideGenerator = self._insideGenerator,
		progress = self:_getCurrentProgress(),
		stage = self:_getCurrentStage(),
		clicksUntilNextStage = self:_clicksUntilNextStage(),
		clicksUntilDone = self:_clicksUntilDone(),
	}
end

function AutoGenerator:Start()
	if self._running then return end
	self._running = true

	self:_bindMap()

	local conn = RunService.Heartbeat:Connect(function(dt)
		if not self.Enabled then return end
		self:_tick(dt)
	end)
	table.insert(self._connections, conn)
end

function AutoGenerator:Stop()
	self.Enabled = false
	self._running = false
	self:_disconnectAll()
	self._mapFolder = nil
	self._remotes = {RF = nil, RE = nil}
	self._currentGenerator = nil
	self._insideGenerator = false
end

function AutoGenerator:SetEnabled(value)
	self.Enabled = value and true or false
	if not self.Enabled then
		self._currentGenerator = nil
		self._insideGenerator = false
	end
end

function AutoGenerator:_disconnectAll()
	for _, c in ipairs(self._connections) do
		c:Disconnect()
	end
	table.clear(self._connections)
	if self._mapWatcher then
		self._mapWatcher:Disconnect()
		self._mapWatcher = nil
	end
end

function AutoGenerator:_bindMap()
	local function resolve()
		local map = Workspace:FindFirstChild("Map")
		if not map then return nil end
		local ingame = map:FindFirstChild("Ingame")
		if not ingame then return nil end
		return ingame:FindFirstChild("Map")
	end

	local function onMapChanged()
		local folder = resolve()
		if folder == self._mapFolder then return end
		self._mapFolder = folder
		self._remotes = {RF = nil, RE = nil}
		self._currentGenerator = nil
		self._insideGenerator = false
		if folder then
			self:_resolveRemotes(folder)
		end
	end

	onMapChanged()
	self._mapWatcher = Workspace.DescendantAdded:Connect(onMapChanged)
	self._mapWatcher = Workspace.DescendantRemoved:Connect(onMapChanged)
	task.spawn(function()
		while self._running do
			onMapChanged()
			task.wait(2)
		end
	end)
end

function AutoGenerator:_resolveRemotes(mapFolder)
	local children = mapFolder:GetChildren()
	local remotesParent = children[13]
	if not remotesParent then return end
	local remotesFolder = remotesParent:FindFirstChild("Remotes")
	if not remotesFolder then
		for _, child in ipairs(children) do
			local r = child:FindFirstChild("Remotes")
			if r then
				remotesParent = child
				remotesFolder = r
				break
			end
		end
	end
	if not remotesFolder then return end
	self._remotes.RF = remotesFolder:FindFirstChild("RF")
	self._remotes.RE = remotesFolder:FindFirstChild("RE")
end

function AutoGenerator:_getLocalCharacter()
	local player = Players.LocalPlayer
	if not player then return nil end
	return player.Character
end

function AutoGenerator:_getRootPart(character)
	if not character then return nil end
	return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
end

function AutoGenerator:_getGenerators()
	if not self._mapFolder then return {} end
	local result = {}
	for _, child in ipairs(self._mapFolder:GetChildren()) do
		if child.Name == "Generator" then
			table.insert(result, child)
		end
	end
	return result
end

function AutoGenerator:_getNearestGenerator()
	local character = self:_getLocalCharacter()
	local root = self:_getRootPart(character)
	if not root then return nil end
	local best, bestDist = nil, INTERACT_DISTANCE
	for _, gen in ipairs(self:_getGenerators()) do
		local primary = gen.PrimaryPart
		if primary then
			local dist = (primary.Position - root.Position).Magnitude
			if dist < bestDist then
				best = gen
				bestDist = dist
			end
		end
	end
	return best
end

function AutoGenerator:_getProgressValue(generator)
	if not generator then return nil end
	local progress = generator:FindFirstChild("Progress")
	if not progress then return nil end
	local data = progress:FindFirstChild("Data")
	if not data then return nil end
	local val = data:FindFirstChild("Value")
	if not val or not val:IsA("NumberValue") then return nil end
	return val.Value
end

function AutoGenerator:_getCurrentProgress()
	return self:_getProgressValue(self._currentGenerator)
end

function AutoGenerator:_getCurrentStage()
	local progress = self:_getCurrentProgress()
	if not progress then return 0 end
	if progress >= 100 then return 4 end
	if progress >= 78 then return 3 end
	if progress >= 52 then return 2 end
	if progress >= 26 then return 1 end
	return 0
end

function AutoGenerator:_clicksUntilNextStage()
	local progress = self:_getCurrentProgress()
	if not progress then return 0 end
	local target = 100
	for _, threshold in ipairs(STAGE_THRESHOLDS) do
		if threshold > progress then
			target = threshold
			break
		end
	end
	return math.ceil((target - progress) / PROGRESS_PER_CLICK)
end

function AutoGenerator:_clicksUntilDone()
	local progress = self:_getCurrentProgress()
	if not progress then return 0 end
	return math.ceil((100 - progress) / PROGRESS_PER_CLICK)
end

function AutoGenerator:_enterGenerator(generator)
	if self._insideGenerator and self._currentGenerator == generator then return end
	local rf = self._remotes.RF
	if not rf or not generator then return end
	local success, err = pcall(function()
		rf:InvokeServer("Enter")
	end)
	if success then
		self._insideGenerator = true
		self._currentGenerator = generator
	else
		warn("[AutoGenerator] Enter failed:", err)
	end
end

function AutoGenerator:_clickRepair()
	local re = self._remotes.RE
	if not re then return end
	local success = pcall(function()
		re:FireServer()
	end)
	if success then
		self.ClicksSent = self.ClicksSent + 1
		local stage = self:_getCurrentStage()
		local progress = self:_getCurrentProgress()
		if progress and progress % 26 < PROGRESS_PER_CLICK and progress >= 26 then
			self.StagesCompleted = self.StagesCompleted + 1
		end
	end
end

function AutoGenerator:_tick(dt)
	self._nextScan = self._nextScan - dt
	if self._nextScan > 0 then return end
	self._nextScan = SCAN_INTERVAL

	if not self._remotes.RF or not self._remotes.RE then
		if self._mapFolder then
			self:_resolveRemotes(self._mapFolder)
		end
		return
	end

	local nearest = self:_getNearestGenerator()
	if not nearest then
		self._currentGenerator = nil
		self._insideGenerator = false
		return
	end

	local progress = self:_getProgressValue(nearest)
	if progress == nil or progress >= 100 then
		self._currentGenerator = nil
		self._insideGenerator = false
		return
	end

	self._currentGenerator = nearest
	self:_enterGenerator(nearest)

	if not self._insideGenerator then return end

	local now = tick() * 1000
	if now - self._lastClick >= self.DelayMs then
		local currentProgress = self:_getCurrentProgress()
		if currentProgress and currentProgress < 100 then
			self:_clickRepair()
			self._lastClick = now
		else
			self._insideGenerator = false
			self._currentGenerator = nil
		end
	end
end

return AutoGenerator
