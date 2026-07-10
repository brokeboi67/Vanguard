-- WeaponCompat.lua — ACS / generic gun framework compat (magic bullets + rapid fire).

local WeaponCompat = {}

local S
local Util
local GameSupport
local LP
local UIS

local enabled = false
local detectedId = nil
local detectedName = nil
local notifyFn = nil

local aimPos = nil
local aimChar = nil
local shootingUntil = 0

local rayHooked = false
local origRaycast = nil
local origSpherecast = nil
local rapidConn = nil

local savedRates = {}   -- [instance] = original value
local patchedTools = setmetatable({}, { __mode = "k" })

local FIRE_RATE_NAMES = {
	"FireRate", "RPM", "Rate", "ShootingCooldown", "Cooldown",
	"FireCooldown", "ShotCooldown", "Delay", "Firerate",
}
local FIRE_ATTRS = { "FireRate", "RPM", "Cooldown", "FireCooldown", "Rate" }

local FRAMEWORKS = {
	acs = {
		label = "ACS",
		detect = function()
			local rs = game:GetService("ReplicatedStorage")
			for _, ch in ipairs(rs:GetChildren()) do
				local n = ch.Name:lower()
				if n:find("acs") then
					return true
				end
			end
			local ws = workspace
			for _, ch in ipairs(ws:GetChildren()) do
				if ch.Name:lower():find("acs") then
					return true
				end
			end
			local char = LP and LP.Character
			if char then
				for _, inst in ipairs(char:GetDescendants()) do
					if inst:IsA("ModuleScript") then
						local n = inst.Name:lower()
						if n:find("acs") or n:find("gunclient") or n:find("gunscript") then
							return true
						end
					end
				end
			end
			return false
		end,
	},
	generic = {
		label = "Generic Gun",
		detect = function()
			local char = LP and LP.Character
			if not char then
				return false
			end
			for _, tool in ipairs(char:GetChildren()) do
				if tool:IsA("Tool") then
					for _, n in ipairs(FIRE_RATE_NAMES) do
						if tool:FindFirstChild(n, true) then
							return true
						end
					end
					if tool:GetAttribute("FireRate") or tool:GetAttribute("RPM") then
						return true
					end
				end
			end
			return false
		end,
	},
}

local function notify(msg, nType)
	if notifyFn then
		pcall(notifyFn, msg, { type = nType or "info", duration = 5 })
	elseif typeof(_G.__VG_LOG) == "function" then
		_G.__VG_LOG("INFO", msg)
	end
end

local function makeClosure(fn)
	if typeof(newcclosure) == "function" then
		local ok, wrapped = pcall(newcclosure, fn)
		if ok and wrapped then
			return wrapped
		end
	end
	return fn
end

local function isShooting()
	if tick() < shootingUntil then
		return true
	end
	if UIS then
		local ok, pressed = pcall(function()
			return UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
		end)
		if ok and pressed then
			return true
		end
	end
	return false
end

local function shouldRedirect(origin, direction)
	if not enabled or not S.SilentCompat then
		return nil
	end
	if S.WeaponCompatMagicBullets == false then
		return nil
	end
	if not aimPos or not isShooting() then
		return nil
	end
	if not origin or not direction then
		return nil
	end
	local dist = direction.Magnitude
	if dist < 0.01 then
		dist = (aimPos - origin).Magnitude
	end
	if dist < 0.5 then
		return nil
	end
	local newDir = aimPos - origin
	if newDir.Magnitude < 0.5 then
		return nil
	end
	return newDir.Unit * math.max(dist, newDir.Magnitude)
end

local function installRaycastHooks()
	if rayHooked or typeof(hookfunction) ~= "function" then
		return false
	end

	local oldRay
	local ok1 = pcall(function()
		oldRay = hookfunction(workspace.Raycast, makeClosure(function(origin, direction, params, ...)
			local newDir = shouldRedirect(origin, direction)
			if newDir then
				direction = newDir
			end
			return oldRay(origin, direction, params, ...)
		end))
	end)

	local oldSphere
	local ok2 = false
	if typeof(workspace.Spherecast) == "function" then
		ok2 = pcall(function()
			oldSphere = hookfunction(workspace.Spherecast, makeClosure(function(origin, radius, direction, params, ...)
				local newDir = shouldRedirect(origin, direction)
				if newDir then
					direction = newDir
				end
				return oldSphere(origin, radius, direction, params, ...)
			end))
		end)
	end

	origRaycast = oldRay
	origSpherecast = oldSphere
	rayHooked = ok1 and oldRay ~= nil
	return rayHooked
end

local function restoreFireRates()
	for inst, val in pairs(savedRates) do
		pcall(function()
			if inst.Parent then
				inst.Value = val
			end
		end)
	end
	table.clear(savedRates)
	table.clear(patchedTools)
end

local function patchTool(tool)
	if not tool or not tool:IsA("Tool") or patchedTools[tool] then
		return
	end
	patchedTools[tool] = true
	for _, name in ipairs(FIRE_RATE_NAMES) do
		for _, inst in ipairs(tool:GetDescendants()) do
			if inst.Name == name and (inst:IsA("NumberValue") or inst:IsA("IntValue")) then
				if not savedRates[inst] then
					savedRates[inst] = inst.Value
				end
				pcall(function()
					inst.Value = 0.02
				end)
			end
		end
	end
	for _, attr in ipairs(FIRE_ATTRS) do
		local val = tool:GetAttribute(attr)
		if type(val) == "number" and val > 0.05 then
			pcall(function()
				tool:SetAttribute(attr, 0.02)
			end)
		end
	end
end

local function patchEquippedTools()
	local char = LP and LP.Character
	if not char then
		return
	end
	for _, ch in ipairs(char:GetChildren()) do
		if ch:IsA("Tool") then
			patchTool(ch)
		end
	end
end

local function startRapidFire()
	if rapidConn then
		return
	end
	local RS = game:GetService("RunService")
	rapidConn = RS.Heartbeat:Connect(function()
		if not enabled or not S.SilentCompat or S.WeaponCompatRapidFire ~= true then
			return
		end
		patchEquippedTools()
	end)
end

local function stopRapidFire()
	if rapidConn then
		rapidConn:Disconnect()
		rapidConn = nil
	end
	restoreFireRates()
end

function WeaponCompat.detect()
	for id, fw in pairs(FRAMEWORKS) do
		local ok, found = pcall(fw.detect)
		if ok and found then
			return id, fw.label
		end
	end
	return nil, nil
end

function WeaponCompat.getGameSupportNote()
	if not GameSupport then
		return nil, nil
	end
	local status, note = GameSupport.getStatus(game.PlaceId, game.GameId)
	return status, note
end

function WeaponCompat.buildStatusMessage(fwId, fwLabel)
	local gsStatus, gsNote = WeaponCompat.getGameSupportNote()
	local parts = {}

	if fwLabel then
		table.insert(parts, string.format("Wykryto: %s", fwLabel))
	else
		table.insert(parts, "Nie wykryto ACS ani znanego systemu broni")
	end

	if gsStatus and gsStatus ~= "No Data" then
		table.insert(parts, string.format("Gra: %s", gsStatus))
		if gsNote and gsNote ~= "" then
			table.insert(parts, gsNote)
		end
	end

	local feats = {}
	if S.WeaponCompatMagicBullets ~= false and rayHooked then
		table.insert(feats, "Magic Bullets")
	end
	if S.WeaponCompatRapidFire == true then
		table.insert(feats, "Rapid Fire")
	end
	if #feats > 0 then
		table.insert(parts, "Aktywne: " .. table.concat(feats, ", "))
	elseif fwLabel and not rayHooked then
		table.insert(parts, "Brak hookfunction — Magic Bullets niedostępne")
	end

	return table.concat(parts, " · ")
end

function WeaponCompat.setNotify(fn)
	notifyFn = fn
end

function WeaponCompat.setAimTarget(pos, char)
	aimPos = pos
	aimChar = char
end

function WeaponCompat.clearAimTarget()
	aimPos = nil
	aimChar = nil
end

function WeaponCompat.beginShotWindow(seconds)
	shootingUntil = tick() + (seconds or 0.2)
end

function WeaponCompat.isActive()
	return enabled and S and S.SilentCompat == true
end

function WeaponCompat.enable(showMessage)
	if not S then
		return false, "WeaponCompat nie załadowany"
	end

	local fwId, fwLabel = WeaponCompat.detect()
	detectedId = fwId
	detectedName = fwLabel

	local hooksOk = installRaycastHooks()
	enabled = true

	if S.WeaponCompatRapidFire == true then
		startRapidFire()
		patchEquippedTools()
	end

	local msg = WeaponCompat.buildStatusMessage(fwId, fwLabel)
	local nType = "warn"
	if fwId and hooksOk then
		nType = "success"
	elseif fwId then
		nType = "warn"
	else
		nType = "error"
	end

	if showMessage ~= false then
		notify(msg, nType)
	end
	return fwId ~= nil, msg
end

function WeaponCompat.disable(showMessage)
	enabled = false
	detectedId = nil
	detectedName = nil
	stopRapidFire()
	WeaponCompat.clearAimTarget()
	shootingUntil = 0

	if showMessage then
		notify("Weapon Compat wyłączony", "info")
	end
end

function WeaponCompat.refresh()
	if not enabled then
		return
	end
	if S.WeaponCompatRapidFire == true then
		startRapidFire()
	else
		stopRapidFire()
	end
end

function WeaponCompat.fireSilentShot(RS, Cam, VIM, UISvc, LP_, targetPos)
	if not targetPos then
		return false
	end
	WeaponCompat.setAimTarget(targetPos, nil)
	WeaponCompat.beginShotWindow(0.3)
	Util.fireWeapon(LP_, VIM, Cam, UISvc)
	task.delay(0.35, WeaponCompat.clearAimTarget)
	return true
end

function WeaponCompat.Init(settings, utilModule, gameSupportModule)
	S = settings
	Util = utilModule
	GameSupport = gameSupportModule
	LP = game:GetService("Players").LocalPlayer
	UIS = game:GetService("UserInputService")

	if S.SilentCompat == true then
		task.defer(function()
			WeaponCompat.enable(true)
		end)
	end
end

return WeaponCompat
