local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local STAGE_COMPLETE = 100
local STAGE_THRESHOLDS = {26, 52, 78, 100}
local FIRE_COOLDOWN_MS = 120
local INTERACT_RADIUS = 10
local MAP_REFRESH_INTERVAL = 1.0
local CHECK_INTERVAL = 0.15

local AutoGenerator = {}
AutoGenerator.__index = AutoGenerator

function AutoGenerator.new()
	local self = setmetatable({}, AutoGenerator)

	self.Enabled = false
	self.DelayMs = 100
	self.StagesCompleted = 0
	self.GeneratorsCompleted = 0
	self.Status = "Disabled"

	self._mapFolder = nil
	self._currentGenerator = nil
	self._insideGenerator = false
	self._lastFire = 0
	self._connections = {}
	self._running = false
	self._nextCheck = 0
	self._nextMapRefresh = 0
	self._lastProgress = 0
	self._speedMulConn = nil
	self._tempUiConn = nil
	self._watchedCharacter = nil

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
	local gens = folder and self:_findGenerators(folder) or {}
	local progress = self._currentGenerator and self:_getProgressValue(self._currentGenerator)
	return {
		mapLoaded = folder ~= nil,
		generatorCount = gens and #gens or 0,
		inside = self._insideGenerator,
		hasTarget = self._currentGenerator ~= nil,
		progress = progress,
		status = self.Status,
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
	self:_watchCharacter()

	local heartbeat = RunService.Heartbeat:Connect(function(dt)
		if not self.Enabled then return end
		self:_tick(dt)
	end)
	table.insert(self._connections, heartbeat)

	local player = Players.LocalPlayer
	if player then
		local charAdded = player.CharacterAdded:Connect(function(char)
			self:_bindCharacter(char)
		end)
		table.insert(self._connections, charAdded)
		if player.Character then
			self:_bindCharacter(player.Character)
		end
	end
end

function AutoGenerator:Stop()
	self.Enabled = false
	self._running = false
	for _, c in ipairs(self._connections) do
		c:Disconnect()
	end
	table.clear(self._connections)
	self:_unbindCharacter()
	self._mapFolder = nil
	self._currentGenerator = nil
	self._insideGenerator = false
	self.Status = "Idle"
end

function AutoGenerator:SetEnabled(value)
	self.Enabled = value and true or false
	if not self.Enabled then
		self._currentGenerator = nil
		self._insideGenerator = false
		self.Status = "Waiting - enter a generator manually"
	else
		self.Status = "Waiting - enter a generator manually"
	end
end

function AutoGenerator:_watchCharacter()
	local player = Players.LocalPlayer
	if not player then return end
	if player.Character and player.Character ~= self._watchedCharacter then
		self:_bindCharacter(player.Character)
	end
end

function AutoGenerator:_unbindCharacter()
	if self._speedMulConn then
		self._speedMulConn:Disconnect()
		self._speedMulConn = nil
	end
	if self._tempUiConn then
		self._tempUiConn:Disconnect()
		self._tempUiConn = nil
	end
	self._watchedCharacter = nil
end

function AutoGenerator:_bindCharacter(character)
	self:_unbindCharacter()
	self._watchedCharacter = character

	self._speedMulConn = character.ChildAdded:Connect(function(child)
		if child.Name == "SpeedMultipliers" then
			self:_bindSpeedMultipliers(child)
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if child.Name == "SpeedMultipliers" then
			self:_onLeaveGenerator("SpeedMultipliers removed")
		end
	end)

	local speedMuls = character:FindFirstChild("SpeedMultipliers")
	if speedMuls then
		self:_bindSpeedMultipliers(speedMuls)
	end

	task.spawn(function()
		self:_bindTemporaryUi()
	end)
end

function AutoGenerator:_bindSpeedMultipliers(folder)
	local fixing = folder:FindFirstChild("FixingGenerator")
	if fixing then
		self:_onEnterGenerator()
	end
	folder.ChildAdded:Connect(function(child)
		if child.Name == "FixingGenerator" then
			self:_onEnterGenerator()
		end
	end)
	folder.ChildRemoved:Connect(function(child)
		if child.Name == "FixingGenerator" then
			self:_onLeaveGenerator("Left generator")
		end
	end)
end

function AutoGenerator:_bindTemporaryUi()
	local player = Players.LocalPlayer
	if not player then return end
	local pg = player:FindFirstChild("PlayerGui")
	if not pg then return end

	local function attach(tempUi)
		if self._tempUiConn then
			self._tempUiConn:Disconnect()
		end
		local function check()
			local found = false
			for _, child in ipairs(tempUi:GetChildren()) do
				if child:FindFirstChild("BarHolder", true) then
					found = true
					break
				end
			end
			if found and not self._insideGenerator then
				self:_onEnterGenerator()
			elseif not found and self._insideGenerator then
				self:_onLeaveGenerator("Fix UI closed")
			end
		end
		check()
		self._tempUiConn = tempUi.ChildAdded:Connect(check)
		tempUi.ChildRemoved:Connect(function(child)
			if child:FindFirstChild("BarHolder", true) then
				task.wait(0.1)
				check()
			end
		end)
	end

	local tempUi = pg:FindFirstChild("TemporaryUI")
	if tempUi then
		attach(tempUi)
	end

	pg.ChildAdded:Connect(function(child)
		if child.Name == "TemporaryUI" then
			attach(child)
		end
	end)
	pg.ChildRemoved:Connect(function(child)
		if child.Name == "TemporaryUI" and self._insideGenerator then
			self:_onLeaveGenerator("TemporaryUI removed")
		end
	end)
end

function AutoGenerator:_onEnterGenerator()
	if self._insideGenerator then return end
	local gen = self:_findCurrentGenerator()
	if not gen then
		self.Status = "Entered generator but cannot locate it (too far?)"
		return
	end
	self._insideGenerator = true
	self._currentGenerator = gen
	self._lastProgress = self:_getProgressValue(gen) or 0
	self._lastFire = tick() * 1000 + 600
	self.Status = string.format("Repairing - %d%%", self._lastProgress)
end

function AutoGenerator:_onLeaveGenerator(reason)
	if not self._insideGenerator and not self._currentGenerator then return end
	self._insideGenerator = false
	self._currentGenerator = nil
	self._lastProgress = 0
	if self.Enabled then
		self.Status = reason and reason or "Left generator"
	else
		self.Status = "Idle"
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
	if not mapFolder then return {} end
	local result = {}
	for _, child in ipairs(mapFolder:GetChildren()) do
		if child:IsA("Model") then
			local remotes = child:FindFirstChild("Remotes")
			local hasProgress = child:FindFirstChild("Progress")
			if remotes and hasProgress then
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
	if not rf then rf = remotes:FindFirstChildOfClass("RemoteFunction") end
	if not re then re = remotes:FindFirstChildOfClass("RemoteEvent") end
	return rf, re
end

function AutoGenerator:_getRootPart()
	local player = Players.LocalPlayer
	if not player then return nil end
	local char = player.Character
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart")
		or char:FindFirstChild("Torso")
		or char:FindFirstChild("UpperTorso")
end

function AutoGenerator:_findCurrentGenerator()
	local folder = self:_getMapFolder()
	if not folder then return nil end
	local root = self:_getRootPart()
	if not root then return nil end

	local best, bestDist = nil, INTERACT_RADIUS
	for _, gen in ipairs(self:_findGenerators(folder)) do
		local _, re = self:_getGeneratorRemotes(gen)
		if re then
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
	return best
end

function AutoGenerator:_getProgressValue(generator)
	if not generator then return nil end
	local progress = generator:FindFirstChild("Progress")
	if not progress then
		for _, d in ipairs(generator:GetDescendants()) do
			if d.Name == "Progress" and d:IsA("NumberValue") then
				return d.Value
			end
		end
		return nil
	end
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

function AutoGenerator:_sendRepair()
	local gen = self._currentGenerator
	if not gen then
		self._insideGenerator = false
		return false
	end
	local _, re = self:_getGeneratorRemotes(gen)
	if not re then
		self.Status = "Generator RE not found"
		return false
	end

	local beforeProgress = self:_getProgressValue(gen) or 0
	local stagesBefore = self:_countStages(beforeProgress)

	local ok = pcall(function()
		re:FireServer()
	end)
	if not ok then
		self.Status = "Failed to send repair"
		return false
	end

	task.wait(0.08)

	local afterProgress = self:_getProgressValue(gen) or beforeProgress
	local stagesAfter = self:_countStages(afterProgress)
	if stagesAfter > stagesBefore then
		self.StagesCompleted = self.StagesCompleted + (stagesAfter - stagesBefore)
	end
	self._lastProgress = afterProgress

	if afterProgress >= STAGE_COMPLETE then
		self.GeneratorsCompleted = self.GeneratorsCompleted + 1
		self._insideGenerator = false
		self._currentGenerator = nil
		self._lastProgress = 0
		self.Status = "Generator completed - waiting for next"
		return true, true
	end

	self.Status = string.format("Repairing - %d%%", afterProgress)
	return true, false
end

function AutoGenerator:_tick(dt)
	self._nextMapRefresh = self._nextMapRefresh - dt
	if self._nextMapRefresh <= 0 then
		self._nextMapRefresh = MAP_REFRESH_INTERVAL
		self._mapFolder = self:_getMapFolder()
	end

	if not self._insideGenerator then
		if self.Enabled and self.Status ~= "Waiting - enter a generator manually" then
			self.Status = "Waiting - enter a generator manually"
		end
		return
	end

	if not self._currentGenerator then
		local gen = self:_findCurrentGenerator()
		if gen then
			self._currentGenerator = gen
		else
			self:_onLeaveGenerator("Lost generator target")
			return
		end
	end

	local progress = self:_getProgressValue(self._currentGenerator)
	if progress == nil then return end
	if progress >= STAGE_COMPLETE then
		self.GeneratorsCompleted = self.GeneratorsCompleted + 1
		self._insideGenerator = false
		self._currentGenerator = nil
		self._lastProgress = 0
		self.Status = "Generator completed - waiting for next"
		return
	end

	local now = tick() * 1000
	local effectiveDelay = math.max(self.DelayMs, FIRE_COOLDOWN_MS)
	if now - self._lastFire < effectiveDelay then return end

	local clicked, done = self:_sendRepair()
	if clicked then
		self._lastFire = now
	end
end

return AutoGenerator
