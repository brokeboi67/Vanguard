-- Plik: workspace/Vanguard/Util.lua

local Util = {}

function Util.resolveBodyPart(char, name)
	if not char or not name then
		return nil
	end
	local child = char:FindFirstChild(name)
	if not child then
		return nil
	end
	if child:IsA("BasePart") then
		return child
	end
	if child:IsA("Model") then
		if child.PrimaryPart and child.PrimaryPart:IsA("BasePart") then
			return child.PrimaryPart
		end
		return child:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

function Util.getPartPosition(part)
	if not part then
		return nil
	end
	if part:IsA("BasePart") then
		return part.Position
	end
	if part:IsA("Model") then
		local ok, pos = pcall(function()
			return part:GetPivot().Position
		end)
		if ok then
			return pos
		end
	end
	return nil
end

function Util.isDecorNpc(model)
	if not model then
		return false
	end
	local p = model.Parent
	while p and p ~= workspace do
		local n = string.lower(p.Name)
		if n == "lobby"
			or n:find("display", 1, true)
			or n:find("eventdisplay", 1, true)
			or n:find("intermission", 1, true)
			or n:find("menu", 1, true) then
			return true
		end
		p = p.Parent
	end
	return false
end

function Util.isAimableCharacter(model)
	if not model or not model:IsA("Model") then
		return false
	end
	if Util.isDecorNpc(model) then
		return false
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	local hrp = Util.resolveBodyPart(model, "HumanoidRootPart")
	if not hum or not hrp then
		return false
	end
	if hum.Health <= 0 then
		return false
	end
	for _, name in ipairs({ "Head", "UpperTorso", "Torso", "HumanoidRootPart" }) do
		if Util.resolveBodyPart(model, name) then
			return true
		end
	end
	return false
end

return Util
