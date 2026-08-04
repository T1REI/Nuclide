local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local STAGE_COMPLETE = 100
local STAGE_THRESHOLDS = {26, 52, 78, 100}
local INTERACT_DISTANCE = 8
local ENTER_RETRY_MS = 600
local FIRE_COOLDOWN_MS = 120
local SCAN_INTERVAL = 0.15
local MAP_REFRESH_INTERVAL = 1.0

local ERROR_MESSAGES = {
	tooFar = "Too far from generator",
	positionOccupied = "Position is occupied, retrying...",
	tooMany = "Too many players on generator",
	alreadyFixed = "Generator already fixed",
	dead = "Player is dead",
	isKiller = "Cannot repair as killer",
	isUnknownTeam = "Spectator cannot repair",
	leftAlready = "Already left",
}

local AutoGenerator = {}
AutoGenerator.__index = AutoGenerator

function AutoGenerator.new()
	local self = setmetatable({}, AutoGenerator)

	self.Enabled = false
	self.DelayMs = 100
	self.StagesCompleted = 0
	self.GeneratorsCompleted = 0
	self.LastError = "Idle"

	self._mapFolder = nil
	self._currentGenerator = nil
	self._insideGenerator = false
	self._lastEnter = 0
	self._lastFire = 0
	self._connections = {}
	self._running = false
	self._nextScan = 0
	self._nextMapRefresh = 0
	self._stageAtEnter = 0

	return self
end

function AutoGenerator:SetDelay(ms)
	self.DelayMs = math.clamp(math.floor(ms or 100), 1, 1000)
end

function AutoGenerator:ResetStats()
	self.StagesCompleted = 0
	self.GeneratorsCompleted = 0
end

function AutoGenerator:Diagnostics()
	local folder = self:_getMapFolder()
	local generators = folder and self:_findGenerators(folder) or {}
	local gen = self._currentGenerator
	local rf, re = gen and self:_getGeneratorRemotes(gen)
	return {
		mapLoaded = folder ~= nil,
		generatorCount = #generators,
		hasTarget = gen ~= nil,
		rfFound = rf ~= nil,
		reFound = re ~= nil,
		inside = self._insideGenerator,
		lastError = self.LastError,
		enabled = self.Enabled,
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
	self._currentGenerator = nil
	self._insideGenerator = false
	self.LastError = "Idle"
end

function AutoGenerator:SetEnabled(value)
	self.Enabled = value and true or false
	if not self.Enabled then
		self._currentGenerator = nil
		self._insideGenerator = false
		self.LastError = "Idle"
	end
end

function AutoGenerator:_getMapFolder()
	local map = Workspace:FindFirstChild("Map")
	if not map then return nil end
	local ingame = map:FindFirstChild("Ingame")
	if not ingame then return nil end
	return ingame:FindFirstChild("Map")
end

function AutoGenerator:_findGenerators(mapFolder)
	local result = {}
	for _, child in ipairs(mapFolder:GetChildren()) do
		if child.Name == "Generator" or child:FindFirstChild("Remotes") then
			if child:IsA("Model") then
				table.insert(result, child)
			end
		end
	end
	return result
end

function AutoGenerator:_getGeneratorRemotes(generator)
	if not generator then return nil, nil end
	local remotes = generator:FindFirstChild("Remotes")
	if not remotes then return nil, nil end
	local rf = remotes:FindFirstChild("RF")
	local re = remotes:FindFirstChild("RE")
	if not rf then
		rf = remotes:FindFirstChildOfClass("RemoteFunction")
	end
	if not re then
		re = remotes:FindFirstChildOfClass("RemoteEvent")
	end
	return rf, re
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

function AutoGenerator:_getNearestGenerator()
	local folder = self:_getMapFolder()
	if not folder then return nil, math.huge end
	local character = self:_getLocalCharacter()
	local root = self:_getRootPart(character)
	if not root then return nil, math.huge end

	local best, bestDist = nil, INTERACT_DISTANCE
	for _, gen in ipairs(self:_findGenerators(folder)) do
		local rf, re = self:_getGeneratorRemotes(gen)
		if rf and re then
			local progress = self:_getProgressValue(gen)
			if progress and progress < STAGE_COMPLETE then
				local part = gen.PrimaryPart
				if not part then
					for _, d in ipairs(gen:GetDescendants()) do
						if d:IsA("BasePart") then part = d; break end
					end
				end
				if part then
					local dist = (part.Position - root.Position).Magnitude
					if dist < bestDist then
						best = gen
						bestDist = dist
					end
				end
			end
		end
	end
	return best, bestDist
end

function AutoGenerator:_getProgressValue(generator)
	if not generator then return nil end
	local progress = generator:FindFirstChild("Progress")
	if not progress then
		for _, d in ipairs(generator:GetDescendants()) do
			if d.Name == "Progress" and d:IsA("NumberValue") then
				progress = d
				break
			end
		end
	end
	if not progress then return nil end
	if progress:IsA("NumberValue") then return progress.Value end
	local val = progress:FindFirstChild("Value")
	if val and val:IsA("NumberValue") then return val.Value end
	for _, d in ipairs(progress:GetDescendants()) do
		if d:IsA("NumberValue") then return d.Value end
	end
	return nil
end

function AutoGenerator:_countStages(progress)
	local count = 0
	for _, t in ipairs(STAGE_THRESHOLDS) do
		if progress >= t then count = count + 1 end
	end
	return count
end

function AutoGenerator:_tryEnter(generator)
	local rf, re = self:_getGeneratorRemotes(generator)
	if not rf then
		self.LastError = "RF not found"
		return false
	end
	local now = tick() * 1000
	if self._insideGenerator and self._currentGenerator == generator then
		if now - self._lastEnter < ENTER_RETRY_MS then return true end
	end
	if now - self._lastEnter < 250 then return self._insideGenerator end

	local ok, status, part, numVal = pcall(function()
		return rf:InvokeServer("Enter")
	end)

	if not ok then
		self.LastError = "Invoke error: " .. tostring(status)
		self._insideGenerator = false
		return false
	end

	if status == "fixing" then
		self._insideGenerator = true
		self._currentGenerator = generator
		self._lastEnter = now
		self._stageAtEnter = self:_countStages(self:_getProgressValue(generator) or 0)
		self.LastError = "Repairing"
		self._lastFire = now + 400
		return true
	end

	self._insideGenerator = false
	if status == nil then
		self.LastError = "No response from server"
	elseif type(status) == "string" then
		self.LastError = ERROR_MESSAGES[status] or ("Server: " .. status)
	else
		self.LastError = "Unexpected response: " .. tostring(status)
	end
	self._lastEnter = now
	return false
end

function AutoGenerator:_sendRepair()
	local gen = self._currentGenerator
	if not gen then
		self._insideGenerator = false
		return false
	end
	local rf, re = self:_getGeneratorRemotes(gen)
	if not re then
		self.LastError = "RE not found"
		return false
	end

	local beforeProgress = self:_getProgressValue(gen) or 0
	local stagesBefore = self:_countStages(beforeProgress)

	local ok, err = pcall(function()
		re:FireServer()
	end)

	if not ok then
		self.LastError = "Fire error: " .. tostring(err)
		self._insideGenerator = false
		return false
	end

	task.wait(0.08)

	local afterProgress = self:_getProgressValue(gen) or beforeProgress
	local stagesAfter = self:_countStages(afterProgress)
	if stagesAfter > stagesBefore then
		self.StagesCompleted = self.StagesCompleted + (stagesAfter - stagesBefore)
	end

	if afterProgress >= STAGE_COMPLETE then
		self.GeneratorsCompleted = self.GeneratorsCompleted + 1
		self._insideGenerator = false
		self._currentGenerator = nil
		self.LastError = "Generator complete"
		self._stageAtEnter = 0
		return true, true
	end

	return true, false
end

function AutoGenerator:_tick(dt)
	self._nextMapRefresh = self._nextMapRefresh - dt
	if self._nextMapRefresh <= 0 then
		self._nextMapRefresh = MAP_REFRESH_INTERVAL
		self._mapFolder = self:_getMapFolder()
	end

	self._nextScan = self._nextScan - dt
	if self._nextScan > 0 then return end
	self._nextScan = SCAN_INTERVAL

	local nearest, dist = self:_getNearestGenerator()
	if not nearest then
		if self._insideGenerator then
			self._insideGenerator = false
		end
		self._currentGenerator = nil
		self.LastError = self.Enabled and "Looking for generator..." or "Idle"
		return
	end

	if self._currentGenerator ~= nearest then
		self._currentGenerator = nearest
		self._insideGenerator = false
	end

	local entered = self:_tryEnter(nearest)
	if not entered then return end

	local now = tick() * 1000
	local effectiveDelay = math.max(self.DelayMs, FIRE_COOLDOWN_MS)
	if now - self._lastFire < effectiveDelay then return end

	local progress = self:_getProgressValue(self._currentGenerator)
	if progress == nil or progress >= STAGE_COMPLETE then
		self._insideGenerator = false
		self._currentGenerator = nil
		return
	end

	local clicked, done = self:_sendRepair()
	if clicked then
		self._lastFire = now
	end
end

return AutoGenerator
