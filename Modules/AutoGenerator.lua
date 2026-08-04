local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local STAGE_COMPLETE = 100
local STAGE_THRESHOLDS = {26, 52, 78, 100}
local FIRE_COOLDOWN_MS = 120
local MAP_REFRESH_INTERVAL = 1.0
local PLAYER_UI_CHECK_INTERVAL = 0.2

local AutoGenerator = {}
AutoGenerator.__index = AutoGenerator

function AutoGenerator.new()
	local self = setmetatable({}, AutoGenerator)

	self.Enabled = false
	self.DelayMs = 100
	self.StagesCompleted = 0
	self.GeneratorsCompleted = 0
	self.Status = "Idle - enter a generator manually"

	self._mapFolder = nil
	self._currentGenerator = nil
	self._insideGenerator = false
	self._lastFire = 0
	self._connections = {}
	self._hookConnections = {}
	self._originalNamecall = nil
	self._namecallHooked = false
	self._running = false
	self._nextUiCheck = 0
	self._nextMapRefresh = 0
	self._lastProgress = 0

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
	self:_installHooks()

	local conn = RunService.Heartbeat:Connect(function(dt)
		if not self.Enabled then return end
		self:_tick(dt)
	end)
	table.insert(self._connections, conn)
end

function AutoGenerator:Stop()
	self.Enabled = false
	self._running = false
	self:_cleanupHooks()
	for _, c in ipairs(self._connections) do
		c:Disconnect()
	end
	table.clear(self._connections)
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
		self.Status = "Idle - enter a generator manually"
	end
end

function AutoGenerator:_cleanupHooks()
	for _, c in ipairs(self._hookConnections) do
		c:Disconnect()
	end
	table.clear(self._hookConnections)
	if self._originalNamecall then
		pcall(hookmetamethod, game, "__namecall", self._originalNamecall)
		self._originalNamecall = nil
		self._namecallHooked = false
	end
end

function AutoGenerator:_installHooks()
	self:_cleanupHooks()

	if not self._namecallHooked then
		local oldNamecall = getmetatable(game).__namecall
		local newNamecall = function(...)
			local selfRef = select(1, ...)
			local method = getnamecallmethod()
			if method == "InvokeServer"
				and type(selfRef) == "userdata"
				and pcall(game.IsA, selfRef, "RemoteFunction")
			then
				local parent = selfRef.Parent
				if parent and parent.Name == "Remotes" then
					local gen = parent.Parent
					if gen and gen:IsA("Model") then
						local msg = select(2, ...)
						if msg == "Enter" then
							local results = table.pack(oldNamecall(...))
							local status = results[1]
							if status == "fixing" then
								self:_onEnteredGenerator(gen)
							elseif status == "leftAlready" then
								self:_onLeftGenerator(gen)
							end
							return table.unpack(results, 1, results.n)
						elseif msg == "Leave" then
							self:_onLeftGenerator(gen)
						end
					end
				end
			end
			return oldNamecall(...)
		end
		hookmetamethod(game, "__namecall", newNamecall)
		self._originalNamecall = oldNamecall
		self._namecallHooked = true
	end

	local player = Players.LocalPlayer
	if player then
		task.spawn(function()
			while self._running do
				task.wait(PLAYER_UI_CHECK_INTERVAL)
				if not self._running then break end
				self:_checkGeneratorUi(player)
			end
		end)
	end
end

function AutoGenerator:_checkGeneratorUi(player)
	local tempGui = player:FindFirstChild("PlayerGui")
		and player.PlayerGui:FindFirstChild("TemporaryUI")
	if not tempGui then return end
	local hasGenUi = false
	for _, child in ipairs(tempGui:GetChildren()) do
		if child.Name == "GeneratorFixUi" or child:FindFirstChild("BarHolder", true) then
			hasGenUi = true
			break
		end
	end
	if hasGenUi and not self._insideGenerator then
		self:_onEnteredGenerator(self:_guessCurrentGenerator())
	elseif not hasGenUi and self._insideGenerator then
		self:_onLeftGenerator(self._currentGenerator)
	end
end

function AutoGenerator:_guessCurrentGenerator()
	local folder = self:_getMapFolder()
	if not folder then return self._currentGenerator end
	local char = self:_getLocalCharacter()
	local root = self:_getRootPart(char)
	local best, bestDist = nil, 12
	for _, gen in ipairs(self:_findGenerators(folder)) do
		local rf, re = self:_getGeneratorRemotes(gen)
		if rf and re then
			local p = self:_getProgressValue(gen)
			if p and p < STAGE_COMPLETE then
				local part = gen.PrimaryPart
				if part and root then
					local d = (part.Position - root.Position).Magnitude
					if d < bestDist then
						best = gen
						bestDist = d
					end
				end
			end
		end
	end
	return best or self._currentGenerator
end

function AutoGenerator:_onEnteredGenerator(generator)
	if not generator then return end
	self._insideGenerator = true
	self._currentGenerator = generator
	self._lastProgress = self:_getProgressValue(generator) or 0
	self._lastFire = tick() * 1000 + 500
	self.Status = "Repairing (auto-click)"
end

function AutoGenerator:_onLeftGenerator(generator)
	if self._currentGenerator and generator and self._currentGenerator ~= generator then return end
	self._insideGenerator = false
	self._currentGenerator = nil
	self._lastProgress = 0
	self.Status = self.Enabled and "Idle - enter a generator manually" or "Idle"
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
	local rf, re = self:_getGeneratorRemotes(gen)
	if not re then
		self.Status = "RE not found in generator"
		return false
	end

	local beforeProgress = self:_getProgressValue(gen) or 0
	local stagesBefore = self:_countStages(beforeProgress)

	local ok = pcall(function()
		re:FireServer()
	end)
	if not ok then
		self.Status = "Failed to fire repair event"
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

	self.Status = string.format("Repairing (auto-click) - %d%%", afterProgress)
	return true, false
end

function AutoGenerator:_tick(dt)
	self._nextMapRefresh = self._nextMapRefresh - dt
	if self._nextMapRefresh <= 0 then
		self._nextMapRefresh = MAP_REFRESH_INTERVAL
		self._mapFolder = self:_getMapFolder()
	end

	if not self._insideGenerator then
		if self.Enabled then
			self.Status = "Idle - enter a generator manually"
		end
		return
	end

	if not self._currentGenerator then
		self._insideGenerator = false
		return
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
