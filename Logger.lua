-- Plik: workspace/Vanguard/Logger.lua

local Logger = {}

local HttpService = game:GetService("HttpService")

local ROOT = "Vanguard/logs"
local LOG_PATH = ROOT .. "/vanguard.log"
local MAX_BYTES = 512000
local enabled = true

local function canWrite()
	return enabled
		and (typeof(appendfile) == "function" or typeof(writefile) == "function")
end

local function ensureDirs()
	if typeof(makefolder) == "function" then
		pcall(makefolder, "Vanguard")
		pcall(makefolder, ROOT)
	end
end

local function ensureLogFile()
	ensureDirs()
	if typeof(isfile) ~= "function" or typeof(writefile) ~= "function" then
		return
	end
	if not isfile(LOG_PATH) then
		pcall(writefile, LOG_PATH, "")
	end
end

local function formatArgs(...)
	local n = select("#", ...)
	local parts = {}
	for i = 1, n do
		local v = select(i, ...)
		if typeof(v) == "table" then
			local ok, encoded = pcall(HttpService.JSONEncode, HttpService, v)
			parts[i] = ok and encoded or tostring(v)
		else
			parts[i] = tostring(v)
		end
	end
	return table.concat(parts, "\t")
end

local function trimIfNeeded(content)
	if #content <= MAX_BYTES then
		return content
	end
	local cut = content:sub(-math.floor(MAX_BYTES * 0.75))
	local nl = cut:find("\n", 1, true)
	if nl then
		cut = cut:sub(nl + 1)
	end
	return "--- log trimmed ---\n" .. cut
end

local function emitConsole(level, text)
	local out = _G.__VG_OLD_PRINT or print
	if level == "WARN" or level == "ERROR" then
		out = _G.__VG_OLD_WARN or warn
	end
	pcall(out, text)
end

local function appendLine(level, text)
	if not canWrite() then
		emitConsole(level, text)
		return false
	end
	ensureLogFile()
	local line = string.format("[%s] [%s] %s\n", os.date("%Y-%m-%d %H:%M:%S"), level, text)
	local ok = false
	if typeof(appendfile) == "function" then
		ok = pcall(appendfile, LOG_PATH, line)
	end
	if not ok and typeof(writefile) == "function" then
		local prev = ""
		if typeof(isfile) == "function" and isfile(LOG_PATH) and typeof(readfile) == "function" then
			pcall(function()
				prev = readfile(LOG_PATH)
			end)
		end
		ok = pcall(writefile, LOG_PATH, trimIfNeeded(prev .. line))
	end
	emitConsole(level, text)
	return ok
end

function Logger.getPath()
	return LOG_PATH
end

function Logger.isEnabled()
	return enabled
end

function Logger.setEnabled(on)
	enabled = on ~= false
end

function Logger.canWrite()
	return canWrite()
end

function Logger.write(level, ...)
	appendLine(level or "INFO", formatArgs(...))
end

function Logger.info(...)
	appendLine("INFO", formatArgs(...))
end

function Logger.warn(...)
	appendLine("WARN", formatArgs(...))
end

function Logger.error(...)
	appendLine("ERROR", formatArgs(...))
end

function Logger.clear()
	if typeof(writefile) ~= "function" then
		return false, "writefile"
	end
	ensureDirs()
	local ok = pcall(writefile, LOG_PATH, "")
	return ok
end

function Logger.installHooks()
	if not _G.__VG_OLD_PRINT then
		_G.__VG_OLD_PRINT = print
	end
	if not _G.__VG_OLD_WARN then
		_G.__VG_OLD_WARN = warn
	end
	local oldPrint = _G.__VG_OLD_PRINT
	local oldWarn = _G.__VG_OLD_WARN
	print = function(...)
		appendLine("INFO", formatArgs(...))
	end
	warn = function(...)
		appendLine("WARN", formatArgs(...))
	end
	_G.__VG_LOG_HOOKED = true
end

function Logger.Init(S)
	enabled = not S or S.LogToFile ~= false
	Logger.installHooks()
	_G.__VG_LOG_PATH = LOG_PATH
	_G.__VG_LOG = function(level, ...)
		appendLine(level or "INFO", formatArgs(...))
	end
	_G.__VG_LOGGER = Logger
	if enabled then
		appendLine("INFO", "Logger ready · v" .. tostring(S and S.Version or "?"))
		appendLine(
			"INFO",
			"Session",
			"place=" .. tostring(game.PlaceId),
			"game=" .. tostring(game.GameId),
			"job=" .. tostring(game.JobId)
		)
	end
end

return Logger
