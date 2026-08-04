local NuclideESP = {}
NuclideESP.__index = NuclideESP

NuclideESP.Name = "NuclideESP"
NuclideESP.Version = "0.0.1"

function NuclideESP.new()
	local self = setmetatable({}, NuclideESP)
	self.Running = false
	return self
end

function NuclideESP:Start()
	self.Running = true
	return self
end

function NuclideESP:Stop()
	self.Running = false
	return self
end

local instance = NuclideESP.new()

if getgenv then
	getgenv().NuclideESP = instance
else
	shared.NuclideESP = instance
end
