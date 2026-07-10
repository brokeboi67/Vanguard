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
local aimActive = false
local shootingUntil = 0

local rayHooked = false
local origRaycast = nil
local origSpherecast = nil
local origFindPartOnRay = nil
local rapidConn = nil

local savedRates = {}
local savedGcRates = {}
local patchedTools = setmetatable({}, { __mode = "k" })

local FIRE_RATE_NAMES = {
	"FireRate", "RPM", "Rate", "ShootingCooldown", "Cooldown",
	"FireCooldown", "ShotCooldown", "Delay", "Firerate",
}
local FIRE_ATTRS = { "FireRate", "RPM", "Cooldown", "FireCooldown", "Rate" }

-- Keys to look for in GC-scanned config tables (ACS and similar frameworks)
local GC_RATE_KEYS = {
	"FireRate", "Firerate", "fireRate", "fire_rate",
	"RPM", "rpm",
	"Cooldown", "cooldown",
	"FireCooldown", "fireCooldown",
	"ShootCooldown", "shootCooldown",
	"Delay", "delay",
	"BulletDelay", "bulletDelay",
	"ShotDelay", "shotDelay",
	"FireDelay", "fireDelay",
}

local FRAMEWORKS = {
	acs = {
		label = "ACS",
		detect = function()
			local rs = game:GetService("ReplicatedStorage")
			for _, ch in ipairs(rs:GetChildren()) do
				local n = ch.Name:lower()
				if n:find("acs") then return true end
			end
			for _, ch in ipairs(workspace:GetChildren()) do
				if ch.Name:lower():find("acs") then return true end
			end
			local char = LP and LP.Character
			if char then
				for _, inst in ipairs(char:GetDescendants()) do
					if inst:IsA("ModuleScript") or inst:IsA("LocalScript") then
						local n = inst.Name:lower()
						if n:find("acs") or n:find("gunclient") or n:find("gunscript") or n:find("gunmodule") then
							return true
						end
					end
				end
			end
			-- check backpack too
			local bp = LP and LP:FindFirstChildOfClass("Backpack")
			if bp then
				for _, tool in ipairs(bp:GetChildren()) do
					if tool:IsA("Tool") then
						for _, inst in ipairs(tool:GetDescendants()) do
							if inst:IsA("ModuleScript") or inst:IsA("LocalScript") then
								local n = inst.Name:lower()
								if n:find("acs") or n:find("gunclient") or n:find("gunscript") then
									return true
								end
							end
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
			if not char then return false end
			for _, tool in ipairs(char:GetChildren()) do
				if tool:IsA("Tool") then
					for _, n in ipairs(FIRE_RATE_NAMES) do
						if tool:FindFirstChild(n, true) then return true end
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
		pcall(notifyFn, msg, { type = nType or "info", duration = 6 })
	elseif typeof(_G.__VG_LOG) == "function" then
		_G.__VG_LOG("INFO", msg)
	end
end

local function makeClosure(fn)
	if typeof(newcclosure) == "function" then
		local ok, wrapped = pcall(newcclosure, fn)
		if ok and wrapped then return wrapped end
	end
	return fn
end

local function isShooting()
	if tick() < shootingUntil then return true end
	if aimActive then return true end
	if UIS then
		local ok, pressed = pcall(function()
			return UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
		end)
		if ok and pressed then return true end
	end
	return false
end

local function shouldRedirect(origin, direction)
	if not enabled or not S.SilentCompat then return nil end
	if S.WeaponCompatMagicBullets == false then return nil end
	if not aimPos then return nil end
	if not isShooting() then return nil end
	if not origin or not direction then return nil end
	local dist = direction.Magnitude
	if dist < 0.01 then
		dist = (aimPos - origin).Magnitude
	end
	if dist < 0.5 then return nil end
	local newDir = aimPos - origin
	if newDir.Magnitude < 0.5 then return nil end
	return newDir.Unit * math.max(dist, newDir.Magnitude)
end

local function installRaycastHooks()
	if rayHooked then return true end
	if typeof(hookfunction) ~= "function" then
		return false
	end

	local oldRay
	local ok1 = pcall(function()
		oldRay = hookfunction(workspace.Raycast, makeClosure(function(self, origin, direction, params, ...)
			local newDir = shouldRedirect(origin, direction)
			if newDir then direction = newDir end
			return oldRay(self, origin, direction, params, ...)
		end))
	end)
	-- some executors use instance method style, try both
	if not ok1 or not oldRay then
		ok1 = pcall(function()
			oldRay = hookfunction(workspace.Raycast, makeClosure(function(origin, direction, params, ...)
				local newDir = shouldRedirect(origin, direction)
				if newDir then direction = newDir end
				return oldRay(origin, direction, params, ...)
			end))
		end)
	end

	local oldSphere
	local ok2 = false
	if typeof(workspace.Spherecast) == "function" then
		ok2 = pcall(function()
			oldSphere = hookfunction(workspace.Spherecast, makeClosure(function(origin, radius, direction, params, ...)
				local newDir = shouldRedirect(origin, direction)
				if newDir then direction = newDir end
				return oldSphere(origin, radius, direction, params, ...)
			end))
		end)
	end

	-- hook old API used by some ACS versions
	local ok3 = false
	if typeof(workspace.FindPartOnRay) == "function" then
		local oldFPOR
		ok3 = pcall(function()
			oldFPOR = hookfunction(workspace.FindPartOnRay, makeClosure(function(ray, ...)
				if enabled and S.SilentCompat and S.WeaponCompatMagicBullets ~= false and aimPos and isShooting() then
					local origin = ray.Origin
					local newDir = aimPos - origin
					if newDir.Magnitude > 0.5 then
						ray = Ray.new(origin, newDir.Unit * math.max(ray.Direction.Magnitude, newDir.Magnitude))
					end
				end
				return oldFPOR(ray, ...)
			end))
		end)
		if ok3 then origFindPartOnRay = oldFPOR end
	end

	origRaycast = oldRay
	origSpherecast = oldSphere
	rayHooked = ok1 and oldRay ~= nil
	return rayHooked
end

-- ── Rapid Fire ─────────────────────────────────────────────────────────────────

local function patchConfigTable(t)
	if type(t) ~= "table" then return 0 end
	local count = 0
	for _, key in ipairs(GC_RATE_KEYS) do
		local v = rawget(t, key)
		if type(v) == "number" and v > 0.025 then
			if not savedGcRates[t] then
				savedGcRates[t] = {}
			end
			if not savedGcRates[t][key] then
				savedGcRates[t][key] = v
			end
			pcall(function() rawset(t, key, 0.02) end)
			count += 1
		end
	end
	return count
end

-- Scan GC tables for fire-rate config entries (ACS stores config in module tables)
local gcScanCooldown = 0
local function scanGcForConfigs()
	if typeof(getgc) ~= "function" then return 0 end
	if tick() - gcScanCooldown < 3 then return 0 end
	gcScanCooldown = tick()
	local ok, gc = pcall(getgc)
	if not ok or type(gc) ~= "table" then return 0 end
	local patched = 0
	for _, v in ipairs(gc) do
		if type(v) == "table" then
			patched += patchConfigTable(v)
		end
	end
	return patched
end

local function restoreFireRates()
	for inst, val in pairs(savedRates) do
		pcall(function()
			if inst.Parent then inst.Value = val end
		end)
	end
	table.clear(savedRates)
	table.clear(patchedTools)

	for t, keys in pairs(savedGcRates) do
		for key, val in pairs(keys) do
			pcall(function() rawset(t, key, val) end)
		end
	end
	table.clear(savedGcRates)
end

local function patchTool(tool)
	if not tool or not tool:IsA("Tool") or patchedTools[tool] then return end
	patchedTools[tool] = true
	-- patch NumberValue / IntValue children
	for _, name in ipairs(FIRE_RATE_NAMES) do
		for _, inst in ipairs(tool:GetDescendants()) do
			if inst.Name == name and (inst:IsA("NumberValue") or inst:IsA("IntValue")) then
				if not savedRates[inst] then savedRates[inst] = inst.Value end
				pcall(function() inst.Value = 0.02 end)
			end
		end
	end
	-- patch attributes
	for _, attr in ipairs(FIRE_ATTRS) do
		local val = tool:GetAttribute(attr)
		if type(val) == "number" and val > 0.025 then
			pcall(function() tool:SetAttribute(attr, 0.02) end)
		end
	end
end

local function patchEquippedTools()
	local char = LP and LP.Character
	if not char then return end
	for _, ch in ipairs(char:GetChildren()) do
		if ch:IsA("Tool") then patchTool(ch) end
	end
end

local function startRapidFire()
	if rapidConn then return end
	local RS = game:GetService("RunService")
	local gcTick = 0
	rapidConn = RS.Heartbeat:Connect(function()
		if not enabled or not S.SilentCompat or S.WeaponCompatRapidFire ~= true then return end
		patchEquippedTools()
		-- GC scan every 3 seconds for ACS config tables
		if tick() - gcTick > 3 then
			gcTick = tick()
			scanGcForConfigs()
		end
	end)
	-- immediate GC scan
	task.defer(function()
		if enabled and S.SilentCompat and S.WeaponCompatRapidFire == true then
			scanGcForConfigs()
		end
	end)
end

local function stopRapidFire()
	if rapidConn then
		rapidConn:Disconnect()
		rapidConn = nil
	end
	restoreFireRates()
end

-- ── Public API ─────────────────────────────────────────────────────────────────

function WeaponCompat.detect()
	for id, fw in pairs(FRAMEWORKS) do
		local ok, found = pcall(fw.detect)
		if ok and found then return id, fw.label end
	end
	return nil, nil
end

function WeaponCompat.getGameSupportNote()
	if not GameSupport then return nil, nil end
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
	if S.WeaponCompatMagicBullets ~= false then
		if rayHooked then
			table.insert(feats, "Magic Bullets ✓")
		else
			table.insert(feats, "Magic Bullets ✗ (brak hookfunction)")
		end
	end
	if S.WeaponCompatRapidFire == true then
		local gcOk = typeof(getgc) == "function"
		table.insert(feats, gcOk and "Rapid Fire ✓" or "Rapid Fire ~ (brak getgc)")
	end
	if #feats > 0 then
		table.insert(parts, table.concat(feats, ", "))
	end

	return table.concat(parts, " · ")
end

function WeaponCompat.setNotify(fn)
	notifyFn = fn
end

function WeaponCompat.setAimTarget(pos, char)
	aimPos = pos
	aimChar = char
	aimActive = (pos ~= nil)
end

function WeaponCompat.clearAimTarget()
	aimPos = nil
	aimChar = nil
	aimActive = false
end

function WeaponCompat.beginShotWindow(seconds)
	shootingUntil = tick() + (seconds or 0.25)
end

function WeaponCompat.isActive()
	return enabled and S and S.SilentCompat == true
end

function WeaponCompat.enable(showMessage)
	if not S then return false, "WeaponCompat nie załadowany" end

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
	local nType
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
	aimActive = false
	stopRapidFire()
	WeaponCompat.clearAimTarget()
	shootingUntil = 0
	if showMessage then
		notify("Weapon Compat wyłączony", "info")
	end
end

function WeaponCompat.refresh()
	if not enabled then return end
	if S.WeaponCompatRapidFire == true then
		startRapidFire()
		patchEquippedTools()
		task.defer(function()
			if enabled then scanGcForConfigs() end
		end)
	else
		stopRapidFire()
	end
end

function WeaponCompat.fireSilentShot(RS, Cam, VIM, UISvc, LP_, targetPos)
	if not targetPos then return false end
	WeaponCompat.setAimTarget(targetPos, nil)
	WeaponCompat.beginShotWindow(0.35)
	Util.fireWeapon(LP_, VIM, Cam, UISvc)
	task.delay(0.4, WeaponCompat.clearAimTarget)
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
