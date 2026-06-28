-- Plik: workspace/Vanguard/Util.lua

local Util = {}

local VG_PREFIX = "VG_HBX_"

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

function Util.resolveAimPart(char, name)
	if not char or not name then
		return nil
	end
	local vg = char:FindFirstChild(VG_PREFIX .. name)
	if vg and vg:IsA("BasePart") then
		return vg
	end
	return Util.resolveBodyPart(char, name)
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

function Util.refreshBotList(list, enabled, LP)
	table.clear(list)
	if not enabled then
		return
	end
	local Players = game:GetService("Players")
	local function tryAdd(model)
		if not model:IsA("Model") then
			return
		end
		if LP.Character and model == LP.Character then
			return
		end
		if Players:GetPlayerFromCharacter(model) then
			return
		end
		if Util.isAimableCharacter(model) then
			table.insert(list, model)
		end
	end
	for _, child in ipairs(workspace:GetChildren()) do
		tryAdd(child)
	end
	for _, folderName in ipairs({ "Characters", "Entities", "NPCs", "Bots" }) do
		local folder = workspace:FindFirstChild(folderName)
		if folder then
			for _, child in ipairs(folder:GetChildren()) do
				tryAdd(child)
			end
		end
	end
end

function Util.fireAtWorld(VIM, Cam, worldPos)
	local vp, onScreen = Cam:WorldToViewportPoint(worldPos)
	local x, y = vp.X, vp.Y
	if not onScreen then
		local center = Cam.ViewportSize / 2
		x, y = center.X, center.Y
	end
	VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
	task.defer(function()
		VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
	end)
end

function Util.performSilentShot(RS, Cam, VIM, targetPos, aimFrames)
	aimFrames = aimFrames or 3
	local saved = Cam.CFrame
	Cam.CFrame = CFrame.new(saved.Position, targetPos)
	for _ = 1, aimFrames do
		RS.RenderStepped:Wait()
	end
	Util.fireAtWorld(VIM, Cam, targetPos)
	for _ = 1, 2 do
		RS.RenderStepped:Wait()
	end
	Cam.CFrame = saved
end

return Util
