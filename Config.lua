-- Plik: workspace/Vanguard/Config.lua

local Config = {}

local HttpService = game:GetService("HttpService")

local ROOT = "Vanguard"
local INDEX_PATH = ROOT .. "/index.json"
local CONFIG_DIR = ROOT .. "/configs"

local RUNTIME_KEYS = {
	MenuOpen = true,
	Version = true,
	LastShotAt = true,
	LastShotHum = true,
	LastShotChar = true,
	LastShotPos = true,
	LastShotRayOrigin = true,
	LastShotRayDir = true,
	_configApplyHooks = true,
	OnConfigApplied = true,
}

local function coerceConfigValue(v, current)
	if typeof(v) == "boolean" or typeof(v) == "number" then
		return v
	end
	if typeof(v) == "string" then
		local lower = string.lower(v)
		if lower == "true" or lower == "on" or lower == "yes" or lower == "1" then
			return true
		end
		if lower == "false" or lower == "off" or lower == "no" or lower == "0" then
			return false
		end
		if typeof(current) == "number" then
			local n = tonumber(v)
			if n ~= nil then
				return n
			end
		end
	end
	return v
end

local function shouldSkipSerializeKey(k)
	if RUNTIME_KEYS[k] then
		return true
	end
	if typeof(k) == "string" and string.sub(k, 1, 1) == "_" then
		return true
	end
	return false
end

local function fireApplyCallbacks(S)
	if typeof(S._configApplyHooks) ~= "table" then
		return
	end
	for _, fn in ipairs(S._configApplyHooks) do
		pcall(fn, S)
	end
	if typeof(S.OnConfigApplied) == "function" then
		pcall(S.OnConfigApplied, S)
	end
end

local function canPersist()
	return typeof(writefile) == "function"
		and typeof(readfile) == "function"
		and typeof(isfile) == "function"
end

local function ensureDirs()
	if typeof(makefolder) == "function" then
		pcall(makefolder, ROOT)
		pcall(makefolder, CONFIG_DIR)
	end
end

local function sanitizeName(name)
	if typeof(name) ~= "string" then
		return nil
	end
	name = name:gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" or #name > 32 then
		return nil
	end
	if not name:match("^[%w%-_%s]+$") then
		return nil
	end
	return name:gsub("%s+", "_")
end

local function readIndex()
	ensureDirs()
	if not canPersist() or not isfile(INDEX_PATH) then
		return { autoload = "", configs = {} }
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(readfile(INDEX_PATH))
	end)
	if not ok or typeof(data) ~= "table" then
		return { autoload = "", configs = {} }
	end
	data.configs = data.configs or {}
	data.autoload = data.autoload or ""
	return data
end

local function writeIndex(index)
	if not canPersist() then
		return false
	end
	ensureDirs()
	writefile(INDEX_PATH, HttpService:JSONEncode(index))
	return true
end

function Config.CanPersist()
	return canPersist()
end

function Config.Serialize(S)
	local data = {}
	for k, v in pairs(S) do
		if not shouldSkipSerializeKey(k) then
			if typeof(v) == "Color3" then
				data[k] = { __color = true, r = v.R, g = v.G, b = v.B }
			else
				data[k] = v
			end
		end
	end
	return data
end

function Config.Apply(S, data)
	if typeof(data) ~= "table" then
		return false
	end
	for k, v in pairs(data) do
		if RUNTIME_KEYS[k] then
			-- skip runtime keys
		elseif typeof(v) == "table" and v.__color then
			S[k] = Color3.new(v.r, v.g, v.b)
		elseif typeof(v) == "table" then
			S[k] = v
		else
			S[k] = coerceConfigValue(v, S[k])
		end
	end
	Config.EnforceRules(S)
	fireApplyCallbacks(S)
	return true
end

function Config.RegisterApplyHook(S, fn)
	if typeof(S) ~= "table" or typeof(fn) ~= "function" then
		return
	end
	S._configApplyHooks = S._configApplyHooks or {}
	table.insert(S._configApplyHooks, fn)
end

function Config.EnforceRules(S)
	if S.Silent and S.Aimbot then
		S.Aimbot = false
	end
	if S.MasterRage then
		S.Aimbot = false
		S.Silent = false
		S.Trigger = false
	elseif S.Aimbot or S.Silent or S.Trigger then
		S.MasterRage = false
	end
	if S.TriggerHudMinimal == nil then
		S.TriggerHudMinimal = true
	end
	if S.TriggerCompat == nil then
		S.TriggerCompat = false
	end
	if S.ExcludeTeam == nil then
		S.ExcludeTeam = true
	end
	if S.RageHudMinimal == nil then
		S.RageHudMinimal = true
	end
	if typeof(S.FriendIds) ~= "table" then
		S.FriendIds = {}
	end
	if S.FriendsESP == nil then
		S.FriendsESP = false
	end
	if S.FriendsESPSkipVisible == nil then
		S.FriendsESPSkipVisible = false
	end
	if S.FriendBox == nil then
		S.FriendBox = false
	end
	if S.FriendHealth == nil then
		S.FriendHealth = false
	end
	if S.FriendHealthText == nil then
		S.FriendHealthText = false
	end
	if S.FriendWeapon == nil then
		S.FriendWeapon = false
	end
	if S.FriendDistView == nil then
		S.FriendDistView = false
	end
	if typeof(S.F) ~= "Color3" then
		S.F = Color3.fromRGB(170, 90, 255)
	end
	if S.HitSound == nil then
		S.HitSound = true
	end
	if S.HitSoundVolume == nil then
		S.HitSoundVolume = 0.45
	end
	if S.RageAimMode == nil then
		if S.RageSilent == false then
			S.RageAimMode = "Snap"
		else
			S.RageAimMode = "Silent"
		end
	end
	if S.RageTrackSmooth == nil then
		S.RageTrackSmooth = 0.35
	end
	if S.RageCompat == nil then
		S.RageCompat = false
	end
	if S.FullBright == nil then
		S.FullBright = false
	end
	if S.Spider == nil then
		S.Spider = false
	end
	if S.SpiderSpeed == nil then
		S.SpiderSpeed = 14
	end
	if S.SpiderStealth == nil then
		S.SpiderStealth = true
	end
	if S.SpiderBurstHeight == nil then
		S.SpiderBurstHeight = 7
	end
	if S.SpiderCooldown == nil then
		S.SpiderCooldown = 1.4
	end
	if S.Invisibility == nil then
		S.Invisibility = false
	end
	if S.InvisShowWarning == nil then
		S.InvisShowWarning = true
	end
	if S.InvisWalkSpeed == nil then
		S.InvisWalkSpeed = 12
	end
	if S.InvisKey == nil then
		S.InvisKey = "X"
	end
	if S.NoFog == nil then
		S.NoFog = false
	end
	if S.WorldTimeLock == nil then
		S.WorldTimeLock = false
	end
	if S.WorldTime == nil then
		S.WorldTime = 14
	end
	if S.WorldCustomLight == nil then
		S.WorldCustomLight = false
	end
	if S.WorldColorHue == nil then
		S.WorldColorHue = 0.55
	end
	if S.WorldColorSat == nil then
		S.WorldColorSat = 0.35
	end
	if S.MenuBlur == nil then
		S.MenuBlur = true
	end
	if S.MenuBlurSize == nil then
		S.MenuBlurSize = 18
	end
	if S.WorldLight == nil then
		S.WorldLight = false
	end
	if S.WorldBrightness == nil then
		S.WorldBrightness = 2
	end
	if S.WorldExposure == nil then
		S.WorldExposure = 0
	end
	if S.WorldShadows == nil then
		S.WorldShadows = true
	end
	if typeof(S.WorldAmbient) ~= "Color3" then
		S.WorldAmbient = Color3.fromRGB(128, 128, 128)
	end
	if typeof(S.WorldOutdoorAmbient) ~= "Color3" then
		S.WorldOutdoorAmbient = Color3.fromRGB(128, 128, 128)
	end
	if S.WorldFog == nil then
		S.WorldFog = false
	end
	if typeof(S.WorldFogColor) ~= "Color3" then
		S.WorldFogColor = Color3.fromRGB(192, 192, 192)
	end
	if S.WorldFogStart == nil then
		S.WorldFogStart = 0
	end
	if S.WorldFogEnd == nil then
		S.WorldFogEnd = 100000
	end
	if S.WorldAtmoDensity == nil then
		S.WorldAtmoDensity = 0.3
	end
	if S.WorldAtmoHaze == nil then
		S.WorldAtmoHaze = 0
	end
	if S.WorldAtmoGlare == nil then
		S.WorldAtmoGlare = 0
	end
	if S.WorldAtmoOffset == nil then
		S.WorldAtmoOffset = 0
	end
	if typeof(S.WorldAtmoColor) ~= "Color3" then
		S.WorldAtmoColor = Color3.fromRGB(199, 199, 199)
	end
	if S.WorldGrade == nil then
		S.WorldGrade = false
	end
	if S.WorldCCBrightness == nil then
		S.WorldCCBrightness = 0
	end
	if S.WorldCCContrast == nil then
		S.WorldCCContrast = 0
	end
	if S.WorldCCSaturation == nil then
		S.WorldCCSaturation = 0
	end
	if typeof(S.WorldCCTint) ~= "Color3" then
		S.WorldCCTint = Color3.fromRGB(255, 255, 255)
	end
	if typeof(S.WorldColorShiftTop) ~= "Color3" then
		S.WorldColorShiftTop = Color3.fromRGB(255, 255, 255)
	end
	if typeof(S.WorldColorShiftBottom) ~= "Color3" then
		S.WorldColorShiftBottom = Color3.fromRGB(255, 255, 255)
	end
	if S.WorldPost == nil then
		S.WorldPost = false
	end
	if S.WorldBloom == nil then
		S.WorldBloom = 0
	end
	if S.WorldSunRays == nil then
		S.WorldSunRays = 0
	end
	if S.KillEffects == nil then
		S.KillEffects = false
	end
	if S.KillEffectStyle == nil then
		S.KillEffectStyle = "Neon"
	end
	if S.HitEffects == nil then
		S.HitEffects = false
	end
	if S.HitEffectStyle == nil then
		S.HitEffectStyle = "Lightning"
	end
	if S.SelfKillFX == nil then
		S.SelfKillFX = false
	end
	if S.AutoStrafe == nil then
		S.AutoStrafe = false
	end
	if S.HeadSize == nil then
		S.HeadSize = false
	end
	if S.HeadSizeScale == nil then
		S.HeadSizeScale = 2
	end
	if S.HitboxSize == nil then
		S.HitboxSize = false
	end
	if S.HitboxSizeScale == nil then
		S.HitboxSizeScale = 1.5
	end
	if S.MiscAffectFriends == nil then
		S.MiscAffectFriends = false
	end
	if S.MiscBots == nil then
		S.MiscBots = true
	end
	if S.AntiBypass == nil then
		S.AntiBypass = true
	end
	if S.TransferScript == nil then
		S.TransferScript = false
	end
	if S.OffscreenArrows == nil then
		S.OffscreenArrows = false
	end
	if S.OffscreenArrowHighVis == nil then
		S.OffscreenArrowHighVis = true
	end
	if S.OffscreenArrowScale == nil then
		S.OffscreenArrowScale = 1.35
	end
	if S.OffscreenArrowShowName == nil then
		S.OffscreenArrowShowName = true
	end
	if S.ESPRenderLimit == nil then
		S.ESPRenderLimit = false
	end
	if S.ESPRenderDist == nil then
		S.ESPRenderDist = 500
	end
	if S.ESPRenderOnlyVisible == nil then
		S.ESPRenderOnlyVisible = false
	end
	if S.ESPLowerOpacityVisible == nil then
		S.ESPLowerOpacityVisible = false
	end
	if S.ESPLowerOpacityAmount == nil then
		S.ESPLowerOpacityAmount = 55
	end
	if S.ESPDisplayName == nil then
		S.ESPDisplayName = false
	end
	if S.ESPTargetUserId == nil then
		S.ESPTargetUserId = 0
	end
	if typeof(S.T) ~= "Color3" then
		S.T = Color3.fromRGB(255, 190, 40)
	end
	if S.CrimCrateESP == nil then
		S.CrimCrateESP = false
	end
	if S.CrimSafeShowBroken == nil then
		S.CrimSafeShowBroken = false
	end
	if S.CrimCrateBasic == nil then
		S.CrimCrateBasic = true
	end
	if S.CrimCrateRare == nil then
		S.CrimCrateRare = true
	end
	if S.CrimCrateMaxDist == nil then
		S.CrimCrateMaxDist = 400
	end
	if typeof(S.CrimCrateColor) ~= "Color3" then
		S.CrimCrateColor = Color3.fromRGB(255, 190, 60)
	end
	if typeof(S.CrimCrateRareColor) ~= "Color3" then
		S.CrimCrateRareColor = Color3.fromRGB(255, 55, 55)
	end
	if S.CrimCratePickup == nil then
		S.CrimCratePickup = false
	end
	if S.CrimCratePickupBasic == nil then
		S.CrimCratePickupBasic = true
	end
	if S.CrimCratePickupRare == nil then
		S.CrimCratePickupRare = true
	end
	if S.CrimCratePickupDist == nil or S.CrimCratePickupDist > 10 then
		S.CrimCratePickupDist = 3.5
	end
	if S.CrimCratePickupDelay == nil then
		S.CrimCratePickupDelay = 200
	end
	if S.CrimNoRecoil == nil then
		S.CrimNoRecoil = false
	end
	if S.CrimQuickEquip == nil then
		S.CrimQuickEquip = false
	end
	if S.CrimAimPrediction == nil then
		S.CrimAimPrediction = false
	end
	if S.CrimAimPredictionLead == nil then
		S.CrimAimPredictionLead = 12
	end
	if S.CrimStaffDetect == nil then
		S.CrimStaffDetect = false
	end
	if S.CrimNoFailLockpick == nil then
		S.CrimNoFailLockpick = false
	end
	if S.CrimAutoOpenDoors == nil then
		S.CrimAutoOpenDoors = false
	end
	if S.CrimAutoUnlockDoors == nil then
		S.CrimAutoUnlockDoors = false
	end
	if S.CrimRemoteElevator == nil then
		S.CrimRemoteElevator = false
	end
	if S.CrimRemoteElevatorKey == nil or S.CrimRemoteElevatorKey == "" then
		S.CrimRemoteElevatorKey = "T"
	end
	if S.CrimRemoteElevatorMaxDist == nil then
		S.CrimRemoteElevatorMaxDist = 400
	end
	if S.CrimRemoteElevatorSpoof == nil then
		S.CrimRemoteElevatorSpoof = false
	end
	if S.CrimInfStamina == nil then
		S.CrimInfStamina = false
	end
	if S.CrimFullBright == nil then
		S.CrimFullBright = false
	end
	if S.CrimCratePickupFx == nil then
		S.CrimCratePickupFx = true
	end
	if S.CrimMoneyPickup == nil then
		S.CrimMoneyPickup = false
	end
	if S.CrimMoneyPickupDist == nil then
		S.CrimMoneyPickupDist = 5
	end
	if S.CrimMoneyPickupDelay == nil then
		S.CrimMoneyPickupDelay = 1000
	end
	if S.CrimAllowanceClaim == nil then
		S.CrimAllowanceClaim = false
	end
	if S.CrimAllowanceClaimDist == nil then
		S.CrimAllowanceClaimDist = 12
	end
	if S.CrimAllowanceClaimDelay == nil then
		S.CrimAllowanceClaimDelay = 3000
	end
	if S.CrimFastPickup == nil then
		S.CrimFastPickup = false
	end
	if S.CrimFastPickupGuns == nil then
		S.CrimFastPickupGuns = true
	end
	if S.CrimFastPickupMelee == nil then
		S.CrimFastPickupMelee = true
	end
	if S.CrimFastPickupArmor == nil then
		S.CrimFastPickupArmor = true
	end
	if S.CrimFastPickupRange == nil then
		S.CrimFastPickupRange = 6
	end
	if S.CrimGunESP == nil then
		S.CrimGunESP = false
	end
	if S.CrimGunESPGuns == nil then
		S.CrimGunESPGuns = true
	end
	if S.CrimGunESPMelee == nil then
		S.CrimGunESPMelee = true
	end
	if S.CrimGunESPMaxDist == nil then
		S.CrimGunESPMaxDist = 250
	end
	if typeof(S.CrimGunESPGunColor) ~= "Color3" then
		S.CrimGunESPGunColor = Color3.fromRGB(80, 255, 140)
	end
	if typeof(S.CrimGunESPMeleeColor) ~= "Color3" then
		S.CrimGunESPMeleeColor = Color3.fromRGB(255, 170, 60)
	end
	if S.LOSIgnoreSelf == nil then
		S.LOSIgnoreSelf = true
	end
	if S.MusicAutoQueue == nil then
		S.MusicAutoQueue = true
	end
	if S.MusicWidgetPosXScale == nil then
		S.MusicWidgetPosXScale = 0
	end
	if S.MusicWidgetPosXOffset == nil then
		S.MusicWidgetPosXOffset = 18
	end
	if S.MusicWidgetPosYScale == nil then
		S.MusicWidgetPosYScale = 1
	end
	if S.MusicWidgetPosYOffset == nil then
		S.MusicWidgetPosYOffset = -90
	end
	if S.MenuLang == nil then
		S.MenuLang = "pl"
	end
	if S.NotifyStyle == nil then
		S.NotifyStyle = "pro"
	end
	if S.DamageNumbers == nil then
		S.DamageNumbers = false
	end
	if S.TargetInfo == nil then
		S.TargetInfo = false
	end
	if S.CrosshairStyle == nil then
		S.CrosshairStyle = "Dot"
	end
	if S.CrosshairColorMode == nil then
		S.CrosshairColorMode = "Accent"
	end
	if S.CrosshairColor == nil then
		S.CrosshairColor = Color3.fromRGB(255, 255, 255)
	end
	if S.AimKey == nil or S.AimKey == "" then
		S.AimKey = "MouseButton2"
	end
	if S.SilentKey == nil or S.SilentKey == "" then
		S.SilentKey = "MouseButton1"
	end
	if S.ChamsRainbow then
		S.LoS = false
		S.RealTeamColor = false
	elseif S.LoS then
		S.ChamsRainbow = false
		S.RealTeamColor = false
	elseif S.RealTeamColor then
		S.ChamsRainbow = false
		S.LoS = false
	end
end

function Config.List()
	local index = readIndex()
	table.sort(index.configs)
	return index.configs, index.autoload or ""
end

function Config.GetAutoload()
	return readIndex().autoload or ""
end

function Config.SetAutoload(name)
	if not canPersist() then
		return false, "Brak writefile — zapis niedostępny"
	end
	name = sanitizeName(name)
	if not name then
		return false, "Nieprawidłowa nazwa"
	end
	local path = CONFIG_DIR .. "/" .. name .. ".json"
	if not isfile(path) then
		return false, "Config nie istnieje"
	end
	local index = readIndex()
	index.autoload = name
	writeIndex(index)
	return true
end

function Config.ClearAutoload()
	if not canPersist() then
		return false, "Brak writefile"
	end
	local index = readIndex()
	index.autoload = ""
	writeIndex(index)
	return true
end

function Config.Save(name, S)
	if not canPersist() then
		return false, "Brak writefile — zapis niedostępny"
	end
	name = sanitizeName(name)
	if not name then
		return false, "Nieprawidłowa nazwa (max 32 znaki, litery/cyfry)"
	end
	ensureDirs()
	local path = CONFIG_DIR .. "/" .. name .. ".json"
	writefile(path, HttpService:JSONEncode(Config.Serialize(S)))
	local index = readIndex()
	local found = false
	for _, n in ipairs(index.configs) do
		if n == name then
			found = true
			break
		end
	end
	if not found then
		table.insert(index.configs, name)
		table.sort(index.configs)
	end
	writeIndex(index)
	return true, name
end

function Config.Load(name, S)
	if not canPersist() then
		return false, "Brak readfile — wczytywanie niedostępne"
	end
	name = sanitizeName(name)
	if not name then
		return false, "Nieprawidłowa nazwa"
	end
	local path = CONFIG_DIR .. "/" .. name .. ".json"
	if not isfile(path) then
		return false, "Config nie istnieje"
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(readfile(path))
	end)
	if not ok then
		return false, "Uszkodzony plik configu"
	end
	Config.Apply(S, data)
	return true, name
end

function Config.Delete(name)
	if not canPersist() then
		return false, "Brak writefile"
	end
	name = sanitizeName(name)
	if not name then
		return false, "Nieprawidłowa nazwa"
	end
	local path = CONFIG_DIR .. "/" .. name .. ".json"
	if isfile(path) then
		pcall(delfile, path)
	end
	local index = readIndex()
	for i, n in ipairs(index.configs) do
		if n == name then
			table.remove(index.configs, i)
			break
		end
	end
	if index.autoload == name then
		index.autoload = ""
	end
	writeIndex(index)
	return true, name
end

function Config.Autoload(S)
	local name = Config.GetAutoload()
	if name == "" or not name then
		return false
	end
	return Config.Load(name, S)
end

return Config
