local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local PROGRESS_PER_CLICK = 2
local STAGE_COMPLETE = 100
local STAGE_THRESHOLDS = {26, 52, 78, 100}
local INTERACT_DISTANCE = 20
local ENTER_COOLDOWN_MS = 800
local SCAN_INTERVAL = 0.2
local MAP_REFRESH_INTERVAL = 1.5

local AutoGenerator = {}
AutoGenerator.__index = AutoGenerator

function AutoGenerator.new()
	local self = setmetatable({}, AutoGenerator)

	self.Enabled = false
	self.DelayMs = 100
	self.StagesCompleted = 0
	self.GeneratorsCompleted = 0

	self._mapFolder = nil
	self._remotes = {RF = nil, RE = nil}
	self._currentGenerator = nil
	self._insideGenerator = false
	self._lastClick = 0
	self._lastEnter = 0
	self._lastSeenProgress = {}
	self._connections = {}
	self._running = false
	self._nextScan = 0
	self._nextMapRefresh = 0
	self._stagesCountedForCurrent = 0

	return self
end

function AutoGenerator:SetDelay(ms)
	self.DelayMs = math.clamp(math.floor(ms or 100), 1, 1000)
end

function AutoGenerator:ResetStats()
	self.StagesCompleted = 0
	self.GeneratorsCompleted = 0
	self._lastSeenProgress = {}
	self._stagesCountedForCurrent = 0
end

function AutoGenerator:Diagnostics()
	local map = Workspace:FindFirstChild("Map")
	local ingame = map and map:FindFirstChild("Ingame")
	local folder = ingame and ingame:FindFirstChild("Map")
	local generators = folder and folder:GetChildren() or {}
	local genCount = 0
	for _, c in ipairs(generators) do
		if c.Name == "Generator" then genCount = genCount + 1 end
	end
	return {
		mapLoaded = folder ~= nil,
		rfFound = self._remotes.RF ~= nil,
		reFound = self._remotes.RE ~= nil,
		generatorCount = genCount,
		enabled = self.Enabled,
		currentGenerator = self._currentGenerator ~= nil,
		inside = self._insideGenerator,
	}
end

function AutoGenerator:GetStats()
	return {
		stagesCompleted = self.StagesCompleted,
		generatorsCompleted = self.GeneratorsCompleted,
	}
end

function AutoGenerator:Start()
	if self._running then return end
	self._running = true
	self:_refreshMap()

	local conn = RunService.Heartbeat:Connect(function(dt)
		if not self.Enabled then return end
		self:_tick(dt)
	end)
	table.insert(self._connections, conn)
end

function AutoGenerator:Stop()
	self.Enabled = false
	self._running = false
	for _, c in ipairs(self._connections) do
		c:Disconnect()
	end
	table.clear(self._connections)
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
		self._stagesCountedForCurrent = 0
	end
end

function AutoGenerator:_refreshMap()
	local map = Workspace:FindFirstChild("Map")
	if not map then
		self._mapFolder = nil
		self._remotes = {RF = nil, RE = nil}
		return
	end
	local ingame = map:FindFirstChild("Ingame")
	if not ingame then
		self._mapFolder = nil
		self._remotes = {RF = nil, RE = nil}
		return
	end
	local mapFolder = ingame:FindFirstChild("Map")
	if mapFolder ~= self._mapFolder then
		self._mapFolder = mapFolder
		self._remotes = {RF = nil, RE = nil}
		self._currentGenerator = nil
		self._insideGenerator = false
		if mapFolder then
			self:_resolveRemotes(mapFolder)
		end
	end
end

function AutoGenerator:_resolveRemotes(mapFolder)
	self._remotes = {RF = nil, RE = nil}
	if not mapFolder then return end

	local children = mapFolder:GetChildren()

	local function tryRemotes(parent)
		if not parent then return end
		local r = parent:FindFirstChild("Remotes")
		if not r then return end
		local rf = r:FindFirstChild("RF")
		local re = r:FindFirstChild("RE")
		if rf and re then
			self._remotes.RF = rf
			self._remotes.RE = re
			return true
		end
		return false
	end

	if tryRemotes(children[13]) then return end
	if tryRemotes(children[14]) then return end
	for _, child in ipairs(children) do
		if tryRemotes(child) then return end
	end
end

function AutoGenerator:_getLocalCharacter()
	local player = Players.LocalPlayer
	if not player then return nil end
	return player.Character
end

function AutoGenerator:_getRootPart(character)
	if not character then return nil end
	return character:FindFirstChild("HumanoidRootPart")
		or character:FindFirstChild("Torso")
		or character:FindFirstChild("UpperTorso")
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
		else
			for _, part in ipairs(gen:GetChildren()) do
				if part:IsA("BasePart") then
					local dist = (part.Position - root.Position).Magnitude
					if dist < bestDist then
						best = gen
						bestDist = dist
					end
					break
				end
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
	if not val then
		for _, child in ipairs(data:GetChildren()) do
			if child:IsA("NumberValue") then val = child; break end
		end
	end
	if not val or not val:IsA("NumberValue") then return nil end
	return val.Value
end

function AutoGenerator:_enterGenerator(generator)
	if not generator then return false end
	local rf = self._remotes.RF
	if not rf then return false end
	local now = tick() * 1000
	if self._insideGenerator and self._currentGenerator == generator then
		if now - self._lastEnter < ENTER_COOLDOWN_MS then return true end
	end
	if now - self._lastEnter < 300 then return self._insideGenerator end
	local ok = pcall(function()
		rf:InvokeServer("Enter")
	end)
	if ok then
		self._insideGenerator = true
		self._currentGenerator = generator
		self._lastEnter = now
		self._lastClick = now + 300
		self._stagesCountedForCurrent = self:_countStagesFor(generator)
		return true
	end
	return false
end

function AutoGenerator:_countStagesFor(generator)
	local progress = self:_getProgressValue(generator) or 0
	local count = 0
	for _, t in ipairs(STAGE_THRESHOLDS) do
		if progress >= t then count = count + 1 end
	end
	return count
end

function AutoGenerator:_clickRepair()
	local re = self._remotes.RE
	if not re then return false end
	local beforeProgress = self:_getProgressValue(self._currentGenerator) or 0
	local stagesBefore = 0
	for _, t in ipairs(STAGE_THRESHOLDS) do
		if beforeProgress >= t then stagesBefore = stagesBefore + 1 end
	end

	local ok = pcall(function()
		re:FireServer()
	end)
	if not ok then return false end

	task.wait(0.05)
	local afterProgress = self:_getProgressValue(self._currentGenerator) or beforeProgress
	local stagesAfter = 0
	for _, t in ipairs(STAGE_THRESHOLDS) do
		if afterProgress >= t then stagesAfter = stagesAfter + 1 end
	end
	if stagesAfter > stagesBefore then
		self.StagesCompleted = self.StagesCompleted + (stagesAfter - stagesBefore)
	end

	if afterProgress >= STAGE_COMPLETE then
		self.GeneratorsCompleted = self.GeneratorsCompleted + 1
		self._insideGenerator = false
		self._currentGenerator = nil
		self._stagesCountedForCurrent = 0
		return true, true
	end

	return true, false
end

function AutoGenerator:_tick(dt)
	self._nextMapRefresh = self._nextMapRefresh - dt
	if self._nextMapRefresh <= 0 then
		self._nextMapRefresh = MAP_REFRESH_INTERVAL
		self:_refreshMap()
	end

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
	if progress == nil then return end

	if progress >= STAGE_COMPLETE then
		if self._currentGenerator == nearest then
			self._insideGenerator = false
			self._currentGenerator = nil
		end
		return
	end

	if self._currentGenerator ~= nearest then
		self._currentGenerator = nearest
		self._insideGenerator = false
	end

	if not self:_enterGenerator(nearest) then return end

	local now = tick() * 1000
	if now - self._lastClick >= self.DelayMs then
		local currentProgress = self:_getCurrentProgress()
		if currentProgress and currentProgress < STAGE_COMPLETE then
			local clicked, finished = self:_clickRepair()
			if clicked then
				self._lastClick = now
			end
			if finished then return end
		else
			self._insideGenerator = false
			self._currentGenerator = nil
		end
	end
end

function AutoGenerator:_getCurrentProgress()
	return self:_getProgressValue(self._currentGenerator)
end

return AutoGenerator
