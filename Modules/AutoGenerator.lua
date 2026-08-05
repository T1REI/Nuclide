local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local STAGE_COMPLETE = 100
local STAGE_POINTS = {26, 52, 78, 100}
local FIRE_COOLDOWN_MS = 50
local INTERACT_RADIUS = 10
local MAP_REFRESH_INTERVAL = 1.0
local TICK_INTERVAL = 0.05

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
	self._currentGenRemotes = nil
	self._insideGenerator = false
	self._nextFireAt = 0
	self._connections = {}
	self._running = false
	self._nextMapRefresh = 0
	self._startedProgress = 0
	self._stagesAtEnter = 0
	self._stagesCountedFromEnter = 0
	self._enteredGenerator = nil
	self._enterSignals = 0
	self._completedFlag = false

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
		generatorCount = #gens,
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

	local heartbeat = RunService.Heartbeat:Connect(function(dt)
		if self.Enabled then
			self:_tick(dt)
		end
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

		local pg = player:FindFirstChild("PlayerGui")
		if pg then
			self:_bindPlayerGui(pg)
		else
			local pgConn
			pgConn = player.ChildAdded:Connect(function(child)
				if child:IsA("PlayerGui") then
					self:_bindPlayerGui(child)
					pgConn:Disconnect()
				end
			end)
			table.insert(self._connections, pgConn)
		end
	end
end

function AutoGenerator:Stop()
	self.Enabled = false
	self._running = false
	for _, c in ipairs(self._connections) do
		pcall(c.Disconnect, c)
	end
	table.clear(self._connections)
	self._mapFolder = nil
	self._currentGenerator = nil
	self._currentGenRemotes = nil
	self._insideGenerator = false
	self._enteredGenerator = nil
	self._enterSignals = 0
	self._completedFlag = false
	self.Status = "Idle"
end

function AutoGenerator:SetEnabled(value)
	self.Enabled = value and true or false
	if not self.Enabled then
		self._currentGenerator = nil
		self._currentGenRemotes = nil
		self._insideGenerator = false
		self._enteredGenerator = nil
		self._stagesAtEnter = 0
		self._stagesCountedFromEnter = 0
		self._enterSignals = 0
		self._completedFlag = false
		self.Status = "Disabled"
	else
		self.Status = "Waiting - enter a generator manually"
	end
end

function AutoGenerator:_signalEnter()
	self._enterSignals = self._enterSignals + 1
	if self._insideGenerator then return end
	local gen = self:_findCurrentGenerator()
	if not gen then
		self.Status = "Signal received but generator not found"
		return
	end
	local _, re = self:_getGeneratorRemotes(gen)
	if not re then
		self.Status = "Generator RE missing"
		return
	end
	local progress = self:_getProgressValue(gen) or 0
	self._insideGenerator = true
	self._currentGenerator = gen
	self._currentGenRemotes = re
	self._startedProgress = progress
	self._stagesAtEnter = self:_countStagesAt(progress)
	self._stagesCountedFromEnter = 0
	self._enteredGenerator = gen
	self._completedFlag = false
	self._nextFireAt = 0
	self.Status = string.format("Repairing - %d%%", progress)
end

function AutoGenerator:_signalLeave()
	self._enterSignals = math.max(0, self._enterSignals - 1)
	if self._enterSignals > 0 then return end
	if not self._insideGenerator then return end
	self:_finalizeGenerator(false)
end

function AutoGenerator:_finalizeGenerator(completed)
	self._insideGenerator = false
	self._currentGenerator = nil
	self._currentGenRemotes = nil
	self._enteredGenerator = nil
	self._stagesAtEnter = 0
	self._stagesCountedFromEnter = 0
	if completed and not self._completedFlag then
		self.GeneratorsCompleted = self.GeneratorsCompleted + 1
		self._completedFlag = true
		self.Status = "Generator completed - waiting for next"
	else
		self.Status = self.Enabled and "Waiting - enter a generator manually" or "Idle"
	end
end

function AutoGenerator:_bindCharacter(character)
	local addedConn = character.ChildAdded:Connect(function(child)
		if child.Name == "SpeedMultipliers" then
			self:_bindSpeedMultipliers(child)
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if child.Name == "SpeedMultipliers" then
			self:_signalLeave()
		end
	end)
	table.insert(self._connections, addedConn)

	local speedMuls = character:FindFirstChild("SpeedMultipliers")
	if speedMuls then
		self:_bindSpeedMultipliers(speedMuls)
	else
		self:_signalLeave()
	end
end

function AutoGenerator:_bindSpeedMultipliers(folder)
	local fixing = folder:FindFirstChild("FixingGenerator")
	if fixing then
		self:_signalEnter()
	else
		self:_signalLeave()
	end
	local onAdded = folder.ChildAdded:Connect(function(child)
		if child.Name == "FixingGenerator" then
			self:_signalEnter()
		end
	end)
	local onRemoved = folder.ChildRemoved:Connect(function(child)
		if child.Name == "FixingGenerator" then
			self:_signalLeave()
		end
	end)
	table.insert(self._connections, onAdded)
	table.insert(self._connections, onRemoved)
end

function AutoGenerator:_bindPlayerGui(pg)
	local function attach(tempUi)
		local function check()
			local found = false
			for _, child in ipairs(tempUi:GetChildren()) do
				if child:FindFirstChild("BarHolder", true) then
					found = true
					break
				end
			end
			if found then
				self:_signalEnter()
			else
				self:_signalLeave()
			end
		end
		check()
		local addConn = tempUi.ChildAdded:Connect(check)
		local remConn = tempUi.ChildRemoved:Connect(function()
			task.wait(0.1)
			check()
		end)
		table.insert(self._connections, addConn)
		table.insert(self._connections, remConn)
	end

	local tempUi = pg:FindFirstChild("TemporaryUI")
	if tempUi then
		attach(tempUi)
	end

	local addedConn = pg.ChildAdded:Connect(function(child)
		if child.Name == "TemporaryUI" then
			attach(child)
		end
	end)
	table.insert(self._connections, addedConn)
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
			local progress = child:FindFirstChild("Progress")
			if remotes and progress then
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
	if not root then return self._currentGenerator end

	local best, bestDist = nil, INTERACT_RADIUS
	for _, gen in ipairs(self:_findGenerators(folder)) do
		local _, re = self:_getGeneratorRemotes(gen)
		if re then
			local p = self:_getProgressValue(gen)
			if p ~= nil and p < STAGE_COMPLETE then
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
	if not progress then return nil end
	if progress:IsA("NumberValue") then return progress.Value end
	local val = progress:FindFirstChild("Value")
	if val and val:IsA("NumberValue") then return val.Value end
	for _, d in ipairs(progress:GetDescendants()) do
		if d:IsA("NumberValue") then return d.Value end
	end
	return nil
end

function AutoGenerator:_countStagesAt(progress)
	local count = 0
	for _, t in ipairs(STAGE_POINTS) do
		if progress >= t then count = count + 1 end
	end
	return count
end

function AutoGenerator:_sendRepair()
	local re = self._currentGenRemotes
	if not re then return false end
	local gen = self._currentGenerator
	if not gen then return false end

	local ok = pcall(re.FireServer, re)
	if not ok then
		self.Status = "Repair event failed"
		return false
	end

	task.wait(0.05)

	local newProgress = self:_getProgressValue(gen)
	if newProgress == nil then return true end

	local stagesNow = self:_countStagesAt(newProgress)
	local totalNewStages = math.max(0, stagesNow - self._stagesAtEnter - self._stagesCountedFromEnter)
	if totalNewStages > 0 then
		self.StagesCompleted = self.StagesCompleted + totalNewStages
		self._stagesCountedFromEnter = self._stagesCountedFromEnter + totalNewStages
	end

	if newProgress >= STAGE_COMPLETE then
		self.Status = "Repairing - 100%"
	else
		self.Status = string.format("Repairing - %d%%", newProgress)
	end

	return true
end

function AutoGenerator:_tick(dt)
	self._nextMapRefresh = self._nextMapRefresh - dt
	if self._nextMapRefresh <= 0 then
		self._nextMapRefresh = MAP_REFRESH_INTERVAL
		self._mapFolder = self:_getMapFolder()
	end

	if not self._insideGenerator then return end
	local gen = self._currentGenerator
	if not gen then
		self:_signalLeave()
		return
	end

	local progress = self:_getProgressValue(gen)
	if progress == nil then return end

	if progress >= STAGE_COMPLETE then
		self:_finalizeGenerator(true)
		return
	end

	local _, re = self:_getGeneratorRemotes(gen)
	if re ~= self._currentGenRemotes then
		self._currentGenRemotes = re
	end
	if not re then return end

	local now = tick() * 1000
	local delay = math.max(self.DelayMs, FIRE_COOLDOWN_MS)
	if now < self._nextFireAt then return end

	self:_sendRepair()
	self._nextFireAt = now + delay
end

return AutoGenerator
