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
		elseif S[k] ~= nil and typeof(v) ~= "table" then
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
