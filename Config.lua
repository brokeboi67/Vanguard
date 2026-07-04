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
}

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
		if not RUNTIME_KEYS[k] then
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
		elseif S[k] ~= nil then
			S[k] = v
		end
	end
	Config.EnforceRules(S)
	return true
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
