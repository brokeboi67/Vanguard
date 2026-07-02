-- Plik: workspace/Vanguard/Teleport.lua
-- Ponowne ładowanie po teleportacji w tej samej sesji gry (lobby -> mecz itd.).

local Teleport = {}

local LOADER_URL = "https://raw.githubusercontent.com/ihatelgbt2-art/Test/main/Main.lua"
local SKIP_PATH = "Vanguard/skip_transfer"

local function canPersist()
	return typeof(writefile) == "function" and typeof(isfile) == "function"
end

local function loaderSnippet()
	return string.format(
		[[
if isfile and isfile(%q) then
	pcall(delfile, %q)
	return
end
loadstring(game:HttpGet(%q))()
]],
		SKIP_PATH,
		SKIP_PATH,
		LOADER_URL
	)
end

local function resolveQueue()
	if typeof(queue_on_teleport) == "function" then
		return queue_on_teleport
	end
	if typeof(syn) == "table" and typeof(syn.queue_on_teleport) == "function" then
		return syn.queue_on_teleport
	end
	if typeof(fluxus) == "table" and typeof(fluxus.queue_on_teleport) == "function" then
		return fluxus.queue_on_teleport
	end
	return nil
end

local function resolveClear()
	if typeof(clrtppqueue) == "function" then
		return clrtppqueue
	end
	if typeof(syn) == "table" and typeof(syn.clear_teleport_queue) == "function" then
		return syn.clear_teleport_queue
	end
	if typeof(fluxus) == "table" and typeof(fluxus.clear_teleport_queue) == "function" then
		return fluxus.clear_teleport_queue
	end
	return nil
end

function Teleport.isSupported()
	return resolveQueue() ~= nil
end

function Teleport.clearQueue()
	local clr = resolveClear()
	if clr then
		pcall(clr)
	end
end

function Teleport.markManualLeave()
	Teleport.clearQueue()
	if not canPersist() then
		return
	end
	pcall(function()
		if typeof(makefolder) == "function" then
			makefolder("Vanguard")
		end
		writefile(SKIP_PATH, "1")
	end)
end

function Teleport.apply(S)
	if not S then
		return false, "Brak ustawień"
	end

	local queue = resolveQueue()
	if not queue then
		return false, "Executor nie wspiera queue_on_teleport"
	end

	if S.TransferScript then
		if canPersist() and isfile(SKIP_PATH) then
			pcall(delfile, SKIP_PATH)
		end
		local ok, err = pcall(queue, loaderSnippet())
		if not ok then
			return false, tostring(err)
		end
		return true
	end

	Teleport.clearQueue()
	return true
end

function Teleport.init(S, CoreRef)
	S.ApplyTransferScript = function()
		return Teleport.apply(S)
	end

	S.MarkManualLeave = Teleport.markManualLeave

	if S.TransferScript then
		Teleport.apply(S)
	end

	game:BindToClose(function()
		if S.TransferScript then
			Teleport.markManualLeave()
		end
	end)

	if CoreRef and typeof(CoreRef.registerCleanup) == "function" then
		CoreRef.registerCleanup(function()
			Teleport.markManualLeave()
		end)
	end
end

return Teleport
