-- Plik: workspace/Vanguard/Logger.lua

local Logger = {}

local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local ScriptContext = game:GetService("ScriptContext")

local ROOT = "Vanguard/logs"
local LOG_PATH = ROOT .. "/vanguard.log"
local MAX_BYTES = 512000
local enabled = true
local logServiceActive = false

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

local function writeToFile(level, text)
	if not canWrite() then
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
	return ok
end

local function emitConsole(level, text)
	local out = _G.__VG_OLD_PRINT or print
	if level == "WARN" or level == "ERROR" then
		out = _G.__VG_OLD_WARN or warn
	end
	pcall(out, text)
end

local function appendFileOnly(level, text)
	writeToFile(level, text)
end

local function appendLine(level, text)
	writeToFile(level, text)
	emitConsole(level, text)
end

local function messageTypeToLevel(messageType)
	if messageType == Enum.MessageType.MessageWarning then
		return "WARN"
	end
	if messageType == Enum.MessageType.MessageError then
		return "ERROR"
	end
	if messageType == Enum.MessageType.MessageInfo then
		return "INFO"
	end
	return "OUT"
end

function Logger.installLogServiceTap()
	if _G.__VG_LOG_SERVICE or not enabled then
		return
	end
	_G.__VG_LOG_SERVICE = true
	logServiceActive = true

	pcall(function()
		LogService.MessageOut:Connect(function(message, messageType)
			if not enabled then
				return
			end
			appendFileOnly(messageTypeToLevel(messageType), tostring(message))
		end)
	end)

	pcall(function()
		ScriptContext.Error:Connect(function(message, stack)
			if not enabled then
				return
			end
			appendFileOnly("ERROR", tostring(message) .. "\n" .. tostring(stack))
		end)
	end)
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

function Logger.writeFile(level, ...)
	appendFileOnly(level or "INFO", formatArgs(...))
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
		local text = formatArgs(...)
		if logServiceActive then
			pcall(oldPrint, ...)
		else
			appendLine("INFO", text)
		end
	end
	warn = function(...)
		local text = formatArgs(...)
		if logServiceActive then
			pcall(oldWarn, ...)
		else
			appendLine("WARN", text)
		end
	end
	_G.__VG_LOG_HOOKED = true
end

function Logger.Init(S)
	enabled = not S or S.LogToFile ~= false
	Logger.installLogServiceTap()
	Logger.installHooks()
	_G.__VG_LOG_PATH = LOG_PATH
	_G.__VG_LOG = function(level, ...)
		appendLine(level or "INFO", formatArgs(...))
	end
	_G.__VG_LOG_FILE = function(level, ...)
		appendFileOnly(level or "INFO", formatArgs(...))
	end
	_G.__VG_LOGGER = Logger
	if enabled then
		appendFileOnly("INFO", "Logger ready · v" .. tostring(S and S.Version or "?"))
		appendFileOnly(
			"INFO",
			"Session place=" .. tostring(game.PlaceId) .. " game=" .. tostring(game.GameId) .. " job=" .. tostring(game.JobId)
		)
		emitConsole("INFO", "[Vanguard] Log file: " .. LOG_PATH)
	end
end

return Logger
