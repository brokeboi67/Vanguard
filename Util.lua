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
	if child:IsA("Accessory") then
		local handle = child:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			return handle
		end
		return child:FindFirstChildWhichIsA("BasePart", true)
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
	local root = workspace:FindFirstChild("VG_Hitboxes")
	if root then
		local key = VG_PREFIX .. tostring(char:GetDebugId()) .. "_" .. name
		local vg = root:FindFirstChild(key)
		if vg and vg:IsA("BasePart") then
			return vg
		end
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
	if part:IsA("Accessory") then
		local handle = part:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			return handle.Position
		end
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

function Util.getFirePosition(char, part)
	if not part then
		return nil
	end
	if char and string.sub(part.Name, 1, #VG_PREFIX) == VG_PREFIX then
		if part:IsA("BasePart") then
			return part.Position
		end
		local slot = string.sub(part.Name, #VG_PREFIX + 1)
		local body = Util.resolveBodyPart(char, slot)
		if body then
			return body.Position
		end
	end
	if part:IsA("BasePart") and part.Parent == char then
		return part.Position
	end
	if char then
		return Util.getPartPosition(Util.resolveBodyPart(char, "Head"))
			or Util.getPartPosition(Util.resolveBodyPart(char, "HumanoidRootPart"))
	end
	return Util.getPartPosition(part)
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
			or n:find("menu", 1, true)
			or n:find("spectator", 1, true)
			or n:find("cutscene", 1, true)
			or n:find("preview", 1, true)
			or n:find("dummy", 1, true)
			or n:find("ragdoll", 1, true)
			or n:find("corpse", 1, true)
			or n:find("dead", 1, true) then
			return true
		end
		p = p.Parent
	end
	return false
end

function Util.isValidTarget(char, plr)
	if not char or not char:IsA("Model") or not char.Parent then
		return false
	end
	if not char:IsDescendantOf(workspace) then
		return false
	end
	if Util.isDecorNpc(char) then
		return false
	end
	local Players = game:GetService("Players")
	if plr then
		if plr.Character ~= char then
			return false
		end
	else
		if Players:GetPlayerFromCharacter(char) then
			return false
		end
	end
	return Util.isAimableCharacter(char)
end

function Util.getEspBox(char, cam)
	local head = Util.resolveBodyPart(char, "Head")
	local hrp = Util.resolveBodyPart(char, "HumanoidRootPart")
	if not head or not hrp then
		return nil
	end

	local hum = char:FindFirstChildOfClass("Humanoid")
	local hipHeight = hum and hum.HipHeight or 2
	local topWorld = head.Position + Vector3.new(0, head.Size.Y * 0.5 + 0.2, 0)
	local bottomWorld = hrp.Position - Vector3.new(0, hipHeight + 1.5, 0)
	local dist = (cam.CFrame.Position - hrp.Position).Magnitude

	local topVp, topOn = cam:WorldToViewportPoint(topWorld)
	local botVp, botOn = cam:WorldToViewportPoint(bottomWorld)
	local midVp, midOn = cam:WorldToViewportPoint(hrp.Position)
	if not topOn and not botOn and not midOn then
		return nil
	end

	local h2 = math.max(math.abs(topVp.Y - botVp.Y), 8)
	local w2 = h2 * 0.55
	local maxW = cam.ViewportSize.X * 0.6
	if w2 > maxW or h2 > cam.ViewportSize.Y * 0.95 then
		return nil
	end

	return {
		topY = topVp.Y,
		bottomY = botVp.Y,
		centerX = (topVp.X + botVp.X) / 2,
		dist = dist,
	}
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
	local ok, state = pcall(function()
		return hum:GetState()
	end)
	if ok and state == Enum.HumanoidStateType.Dead then
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
		if Util.isValidTarget(model, nil) then
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

function Util.fireTriggerClick(LP, VIM, Cam, UIS)
	local RS = game:GetService("RunService")
	local cx = Cam.ViewportSize.X / 2
	local cy = Cam.ViewportSize.Y / 2
	if UIS then
		local loc = UIS:GetMouseLocation()
		cx, cy = loc.X, loc.Y
	end

	local char = LP and LP.Character
	if char then
		for _, item in ipairs(char:GetChildren()) do
			if item:IsA("Tool") then
				pcall(function()
					item:Activate()
				end)
			end
		end
	end

	local genv = (typeof(getgenv) == "function" and getgenv()) or _G
	local press = genv.mouse1press or mouse1press
	local release = genv.mouse1release or mouse1release
	local click = genv.mouse1click or mouse1click

	if typeof(click) == "function" then
		pcall(click)
	elseif typeof(press) == "function" then
		pcall(press)
		RS.RenderStepped:Wait()
		if typeof(release) == "function" then
			pcall(release)
		end
	end

	if typeof(syn) == "table" and typeof(syn.mouse1click) == "function" then
		pcall(syn.mouse1click)
	end

	local mouse = LP and LP:GetMouse()
	if mouse and typeof(getconnections) == "function" then
		pcall(function()
			for _, conn in ipairs(getconnections(mouse.Button1Down)) do
				conn:Fire()
			end
		end)
		RS.RenderStepped:Wait()
		pcall(function()
			for _, conn in ipairs(getconnections(mouse.Button1Up)) do
				conn:Fire()
			end
		end)
	end

	if typeof(firesignal) == "function" then
		pcall(function()
			local input = {
				UserInputType = Enum.UserInputType.MouseButton1,
				KeyCode = Enum.KeyCode.Unknown,
			}
			firesignal(UIS.InputBegan, input, false)
			firesignal(UIS.InputEnded, input, false)
		end)
	end

	pcall(function()
		local VirtualUser = game:GetService("VirtualUser")
		VirtualUser:Button1Down(Vector2.new(cx, cy))
		VirtualUser:Button1Up(Vector2.new(cx, cy))
	end)

	pcall(function()
		VIM:SendMouseButtonEvent(cx, cy, 0, true, 1, false)
	end)
	RS.RenderStepped:Wait()
	pcall(function()
		VIM:SendMouseButtonEvent(cx, cy, 0, false, 1, false)
	end)
end

function Util.clickMouse(VIM, Cam, UIS, holdFrames, LP)
	local RS = game:GetService("RunService")
	holdFrames = holdFrames or 0

	local function holdRelease(pressFn, releaseFn)
		if typeof(pressFn) ~= "function" then
			return false
		end
		local ok = pcall(pressFn)
		if not ok then
			return false
		end
		if holdFrames > 0 then
			for _ = 1, holdFrames do
				RS.RenderStepped:Wait()
			end
		end
		if typeof(releaseFn) == "function" then
			pcall(releaseFn)
		end
		return true
	end

	local genv = (typeof(getgenv) == "function" and getgenv()) or _G

	if typeof(genv.mouse1click) == "function" then
		pcall(genv.mouse1click)
		return true
	end
	if typeof(mouse1click) == "function" then
		pcall(mouse1click)
		return true
	end
	if typeof(syn) == "table" and typeof(syn.mouse1click) == "function" then
		pcall(syn.mouse1click)
		return true
	end
	if holdRelease(genv.mouse1press, genv.mouse1release) then
		return true
	end
	if holdRelease(mouse1press, mouse1release) then
		return true
	end

	local mouse = LP and LP:GetMouse()
	if mouse and typeof(getconnections) == "function" then
		local fired = false
		pcall(function()
			for _, conn in ipairs(getconnections(mouse.Button1Down)) do
				conn:Fire()
				fired = true
			end
		end)
		if fired then
			if holdFrames > 0 then
				for _ = 1, holdFrames do
					RS.RenderStepped:Wait()
				end
			end
			pcall(function()
				for _, conn in ipairs(getconnections(mouse.Button1Up)) do
					conn:Fire()
				end
			end)
			return true
		end
	end

	local cx, cy = Cam.ViewportSize.X / 2, Cam.ViewportSize.Y / 2
	if UIS then
		local loc = UIS:GetMouseLocation()
		cx, cy = loc.X, loc.Y
	end

	pcall(function()
		VIM:SendMouseButtonEvent(cx, cy, 0, true, 1, false)
	end)
	if holdFrames > 0 then
		for _ = 1, holdFrames do
			RS.RenderStepped:Wait()
		end
	end
	pcall(function()
		VIM:SendMouseButtonEvent(cx, cy, 0, false, 1, false)
	end)
	return true
end

function Util.fireCrosshair(VIM, Cam, UIS, opts)
	opts = opts or {}
	local cx, cy
	if opts.center ~= false then
		cx = Cam.ViewportSize.X / 2
		cy = Cam.ViewportSize.Y / 2
	elseif UIS then
		local loc = UIS:GetMouseLocation()
		cx, cy = loc.X, loc.Y
	else
		cx = Cam.ViewportSize.X / 2
		cy = Cam.ViewportSize.Y / 2
	end
	pcall(function()
		VIM:SendMouseButtonEvent(cx, cy, 0, true, 1, false)
	end)
	pcall(function()
		VIM:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
	end)
	task.defer(function()
		pcall(function()
			VIM:SendMouseButtonEvent(cx, cy, 0, false, 1, false)
		end)
		pcall(function()
			VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
		end)
	end)
end

function Util.dispatchClick(LP, UIS, VIM, Cam)
	Util.clickMouse(VIM, Cam, UIS, 3, LP)
end

function Util.fireWeapon(LP, VIM, Cam, UIS)
	Util.clickMouse(VIM, Cam, UIS, 3, LP)
end

function Util.performSilentShot(RS, Cam, VIM, targetPos, aimFrames, UIS, LP)
	if not targetPos then
		return
	end
	aimFrames = aimFrames or 2
	local saved = Cam.CFrame
	Cam.CFrame = CFrame.new(saved.Position, targetPos)
	for _ = 1, aimFrames do
		RS.RenderStepped:Wait()
	end
	Util.fireWeapon(LP, VIM, Cam, UIS)
	RS.RenderStepped:Wait()
	RS.RenderStepped:Wait()
	Cam.CFrame = saved
end

return Util
