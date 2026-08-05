local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local STAGE_COMPLETE = 100
local STAGE_POINTS = {26, 52, 78, 100}
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
	self._currentGenRE = nil
	self._insideGenerator = false
	self._repairing = false
	self._nextFireAt = 0
	self._connections = {}
	self._generatorConnections = {}
	self._running = false
	self._nextMapRefresh = 0
	self._stagesAtEnter = 0
	self._stagesReachedSinceEnter = 0

	return self
end

function AutoGenerator:SetDelay(ms)
	self.DelayMs = math.clamp(math.floor(ms or 100), 1, 2000)
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

		local function bindPgWhenReady()
			local pg = player:FindFirstChild("PlayerGui")
			if pg then
				self:_bindPlayerGui(pg)
				return
			end
			local conn
			conn = player.ChildAdded:Connect(function(child)
				if child:IsA("PlayerGui") then
					self:_bindPlayerGui(child)
					conn:Disconnect()
				end
			end)
			table.insert(self._connections, conn)
		end
		bindPgWhenReady()
	end
end

function AutoGenerator:Stop()
	self.Enabled = false
	self._running = false
	self:_disconnectAll()
	self._mapFolder = nil
	self:_detachGenerator(true)
	self.Status = "Idle"
end

function AutoGenerator:SetEnabled(value)
	self.Enabled = value and true or false
	if not self.Enabled then
		self:_detachGenerator(false)
		self.Status = "Disabled"
	else
		self.Status = "Waiting - enter a generator manually"
	end
end

function AutoGenerator:_disconnectAll()
	for _, c in ipairs(self._connections) do
		pcall(c.Disconnect, c)
	end
	table.clear(self._connections)
	self:_detachGenerator(true)
end

function AutoGenerator:_detachGenerator(silent)
	for _, c in ipairs(self._generatorConnections) do
		pcall(c.Disconnect, c)
	end
	table.clear(self._generatorConnections)

	if self._currentGenerator and self._repairing then
		if not silent then
			self.GeneratorsCompleted = self.GeneratorsCompleted + 0
		end
	end

	self._currentGenerator = nil
	self._currentGenRE = nil
	self._insideGenerator = false
	self._repairing = false
	self._stagesAtEnter = 0
	self._stagesReachedSinceEnter = 0
	if self.Enabled and not silent then
		self.Status = "Waiting - enter a generator manually"
	end
end

function AutoGenerator:_onGeneratorComplete()
	if not self._currentGenerator then return end
	self.GeneratorsCompleted = self.GeneratorsCompleted + 1
	self.Status = "Generator completed - waiting for next"
	self:_detachGenerator(true)
end

function AutoGenerator:_signalEnter()
	if self._insideGenerator and self._repairing then return end
	if self._repairing then return end
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

	if progress >= STAGE_COMPLETE then
		self.Status = "Generator already complete"
		return
	end

	self._insideGenerator = true
	self._repairing = true
	self._currentGenerator = gen
	self._currentGenRE = re
	self._stagesAtEnter = self:_countStagesAt(progress)
	self._stagesReachedSinceEnter = 0
	self._nextFireAt = tick() * 1000 + self.DelayMs
	self.Status = string.format("Waiting first tick... (%d%%)", progress)

	self:_trackProgress(gen)
end

function AutoGenerator:_signalLeave()
	if not self._repairing then
		self._insideGenerator = false
		return
	end
	if self:_hasAnyFixSignal() then return end
	self:_detachGenerator(false)
	if self.Enabled then
		self.Status = "Left generator"
	else
		self.Status = "Idle"
	end
end

function AutoGenerator:_trackProgress(gen)
	for _, c in ipairs(self._generatorConnections) do
		pcall(c.Disconnect, c)
	end
	table.clear(self._generatorConnections)

	local progressVal = self:_getProgressObject(gen)
	if progressVal then
		local conn = progressVal.Changed:Connect(function(newValue)
			self:_onProgressChanged(newValue)
		end)
		table.insert(self._generatorConnections, conn)
		if progressVal:IsA("NumberValue") then
		else
			local data = progressVal:FindFirstChild("Data")
			if data then
				local inner = data:FindFirstChild("Value")
				if inner and inner:IsA("NumberValue") then
					local conn2 = inner.Changed:Connect(function(v)
						self:_onProgressChanged(v)
					end)
					table.insert(self._generatorConnections, conn2)
					self:_onProgressChanged(inner.Value)
				end
			end
		end
	end
end

function AutoGenerator:_onProgressChanged(newValue)
	if not self._repairing then return end
	if type(newValue) ~= "number" then return end

	local stagesNow = self:_countStagesAt(newValue)
	local reached = math.max(0, stagesNow - self._stagesAtEnter - self._stagesReachedSinceEnter)
	if reached > 0 then
		self.StagesCompleted = self.StagesCompleted + reached
		self._stagesReachedSinceEnter = self._stagesReachedSinceEnter + reached
	end

	if newValue >= STAGE_COMPLETE then
		self.Status = "Repairing - 100%"
		self:_onGeneratorComplete()
		return
	end
	self.Status = string.format("Repairing - %d%%", newValue)
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
	end

	character.Destroying:Connect(function()
		self:_signalLeave()
	end)
end

function AutoGenerator:_bindSpeedMultipliers(folder)
	local fixing = folder:FindFirstChild("FixingGenerator")
	if fixing then
		self:_signalEnter()
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
				if self._insideGenerator and not self:_hasAnyFixSignal() then
					self:_signalLeave()
				end
			end
		end
		check()
		local addConn = tempUi.ChildAdded:Connect(check)
		local remConn = tempUi.ChildRemoved:Connect(function()
			task.wait(0.15)
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

function AutoGenerator:_hasAnyFixSignal()
	local player = Players.LocalPlayer
	if not player then return false end
	local char = player.Character
	if char then
		local sm = char:FindFirstChild("SpeedMultipliers")
		if sm and sm:FindFirstChild("FixingGenerator") then
			return true
		end
	end
	local pg = player:FindFirstChild("PlayerGui")
	if pg then
		local tui = pg:FindFirstChild("TemporaryUI")
		if tui then
			for _, child in ipairs(tui:GetChildren()) do
				if child:FindFirstChild("BarHolder", true) then
					return true
				end
			end
		end
	end
	return false
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
	if not folder then return self._currentGenerator end
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
	return best or self._currentGenerator
end

function AutoGenerator:_getProgressValue(generator)
	local obj = self:_getProgressObject(generator)
	if not obj then return nil end
	if obj:IsA("NumberValue") then return obj.Value end
	local val = obj:FindFirstChild("Value")
	if val and val:IsA("NumberValue") then return val.Value end
	for _, d in ipairs(obj:GetDescendants()) do
		if d:IsA("NumberValue") then return d.Value end
	end
	return nil
end

function AutoGenerator:_getProgressObject(generator)
	if not generator then return nil end
	local progress = generator:FindFirstChild("Progress")
	if progress then return progress end
	for _, d in ipairs(generator:GetDescendants()) do
		if d.Name == "Progress" then return d end
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
	local re = self._currentGenRE
	if not re then return false end
	local ok = pcall(re.FireServer, re)
	if not ok then
		self.Status = "Repair event failed"
		return false
	end
	return true
end

function AutoGenerator:_tick(dt)
	self._nextMapRefresh = self._nextMapRefresh - dt
	if self._nextMapRefresh <= 0 then
		self._nextMapRefresh = MAP_REFRESH_INTERVAL
		self._mapFolder = self:_getMapFolder()
	end

	if not self._repairing then return end

	local gen = self._currentGenerator
	if not gen then
		self:_detachGenerator(false)
		return
	end

	local progress = self:_getProgressValue(gen)
	if progress ~= nil and progress >= STAGE_COMPLETE then
		self:_onGeneratorComplete()
		return
	end

	local now = tick() * 1000
	if now < self._nextFireAt then return end

	if self:_sendRepair() then
		self._nextFireAt = now + self.DelayMs
	end
end

return AutoGenerator
